const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { runInNewContext } = require("node:vm");
const { test } = require("node:test");

const modelPath = path.join(__dirname, "../plugin/components/HostConfigModel.js");
const modelSource = readFileSync(modelPath, "utf8");
const context = {};
runInNewContext(
  `${modelSource}\nthis.hostConfigModel = { localHost, normalizeEndpoint, validateRemoteHosts, parseHostConfig, prepareWrite, rollbackWrite };`,
  context,
  { filename: modelPath },
);
const model = context.hostConfigModel;

function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

function expectError(fn, message) {
  assert.throws(fn, (error) => error && error.message === message);
}

const localHost = {
  id: "local",
  name: "This machine",
  dockerHost: "unix:///var/run/docker.sock",
};

test("parses trimmed SSH hosts and adds the built-in local host", () => {
  const proxyTest = { enabled: false };
  const parsed = model.parseHostConfig(JSON.stringify({
    hosts: [{
      id: "build.vm",
      name: " Build VM ",
      dockerHost: " ssh://docker@build.example ",
    }],
    proxyTest,
  }));

  assert.deepEqual(plain(parsed.hosts), [
    localHost,
    { id: "build.vm", name: "Build VM", dockerHost: "ssh://docker@build.example" },
  ]);
  assert.deepEqual(plain(parsed.proxyTest), proxyTest);
});

test("rejects malformed JSON and configs without a hosts array", () => {
  assert.throws(() => model.parseHostConfig("{"), /JSON/);
  expectError(() => model.parseHostConfig("{}"), "Expected a hosts array");
  expectError(() => model.validateRemoteHosts(null), "Expected a hosts array");
});

test("normalizes SSH aliases and rejects unsafe endpoint forms", () => {
  assert.equal(model.normalizeEndpoint(" build-vm "), "ssh://build-vm");
  assert.equal(model.normalizeEndpoint(" ssh://docker@build.example "), "ssh://docker@build.example");
  assert.equal(model.normalizeEndpoint("tcp://build.example:2375"), "");
  assert.equal(model.normalizeEndpoint("ssh://docker@build.example/socket"), "");
  assert.equal(model.normalizeEndpoint("ssh://docker@build.example?forward=true"), "");
});

test("requires string host fields and non-empty trimmed values", () => {
  expectError(
    () => model.validateRemoteHosts([null]),
    "Each host needs string id, name, and dockerHost values",
  );
  expectError(
    () => model.validateRemoteHosts([{ id: "", name: "Build VM", dockerHost: "ssh://build-vm" }]),
    "Host 1 needs a non-empty id, name, and dockerHost",
  );
});

test("enforces valid, unique, non-local host IDs", () => {
  const invalidIds = ["-build", "has space", "has/slash"];
  for (const id of invalidIds) {
    expectError(
      () => model.validateRemoteHosts([{ id, name: "Build VM", dockerHost: "ssh://build-vm" }]),
      "Host IDs must start with a letter or number and contain only letters, numbers, '.', '_' or '-'",
    );
  }

  expectError(
    () => model.validateRemoteHosts([{ id: "local", name: "Build VM", dockerHost: "ssh://build-vm" }]),
    "Host id 'local' is duplicated or reserved for the local host",
  );
  expectError(
    () => model.validateRemoteHosts([
      { id: "build-vm", name: "One", dockerHost: "ssh://one" },
      { id: "build-vm", name: "Two", dockerHost: "ssh://two" },
    ]),
    "Host id 'build-vm' is duplicated or reserved for the local host",
  );
});

test("allows only SSH Docker endpoints and rejects duplicate endpoints", () => {
  const invalidEndpoints = [
    "tcp://build-vm:2375",
    "ssh://build-vm/socket",
    "ssh://build-vm?forward=true",
    "ssh://build vm",
  ];
  for (const dockerHost of invalidEndpoints) {
    expectError(
      () => model.validateRemoteHosts([{ id: "build-vm", name: "Build VM", dockerHost }]),
      "Remote hosts must use an SSH Docker endpoint such as ssh://user@host",
    );
  }

  expectError(
    () => model.validateRemoteHosts([
      { id: "one", name: "One", dockerHost: "ssh://docker@build-vm" },
      { id: "two", name: "Two", dockerHost: "ssh://docker@BUILD-VM" },
    ]),
    "SSH endpoint 'ssh://docker@BUILD-VM' is configured more than once",
  );
});

test("prepares normalized config writes with the local host and optional proxy test", () => {
  const existingHosts = [localHost, { id: "old", name: "Old", dockerHost: "ssh://old" }];
  const proxyTest = { enabled: true, architecture: "x86_64", bundledBinary: true, goAvailable: true };
  const transaction = model.prepareWrite(
    existingHosts,
    [{ id: "new", name: " New ", dockerHost: " ssh://new " }],
    proxyTest,
    "Added New",
  );
  const config = JSON.parse(transaction.text);

  assert.deepEqual(plain(transaction.previousHosts), existingHosts);
  assert.deepEqual(plain(transaction.hosts), [
    localHost,
    { id: "new", name: "New", dockerHost: "ssh://new" },
  ]);
  assert.deepEqual(config.hosts, [
    { id: "new", name: "New", dockerHost: "ssh://new" },
  ]);
  assert.deepEqual(config.proxyTest, proxyTest);
  assert.equal(transaction.pendingSuccess, "Added New");
  assert.equal(transaction.text.endsWith("\n"), true);
});

test("failed writes restore the prior host list and clear pending success", () => {
  const existingHosts = [localHost, { id: "old", name: "Old", dockerHost: "ssh://old" }];
  const transaction = model.prepareWrite(existingHosts, [], { enabled: false }, "Removed Old");
  const rollback = model.rollbackWrite(transaction);

  assert.deepEqual(plain(rollback.hosts), existingHosts);
  assert.equal(rollback.pendingSuccess, "");
  assert.deepEqual(existingHosts, [localHost, { id: "old", name: "Old", dockerHost: "ssh://old" }]);
});

test("failed validation does not mutate existing hosts or produce a write", () => {
  const existingHosts = [localHost, { id: "old", name: "Old", dockerHost: "ssh://old" }];
  expectError(
    () => model.prepareWrite(existingHosts, [{ id: "bad/id", name: "Bad", dockerHost: "ssh://bad" }], {}, "Added Bad"),
    "Host IDs must start with a letter or number and contain only letters, numbers, '.', '_' or '-'",
  );
  assert.deepEqual(existingHosts, [localHost, { id: "old", name: "Old", dockerHost: "ssh://old" }]);
});
