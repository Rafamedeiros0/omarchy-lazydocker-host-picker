function localHost() {
    return {
        "id": "local",
        "name": "This machine",
        "dockerHost": "unix:///var/run/docker.sock"
    };
}

function isRemoteDockerEndpoint(endpoint) {
    return /^ssh:\/\/[^/\s?#]+$/.test(endpoint);
}

function normalizeEndpoint(raw) {
    var endpoint = String(raw || "").trim();
    if (/^[A-Za-z0-9_.-]+$/.test(endpoint))
        endpoint = "ssh://" + endpoint;

    return isRemoteDockerEndpoint(endpoint) ? endpoint : "";
}

function validateRemoteHosts(remoteHosts) {
    if (!Array.isArray(remoteHosts))
        throw new Error("Expected a hosts array");

    var parsed = [];
    var usedIds = ["local"];
    var usedEndpoints = [];
    remoteHosts.forEach(function (host, index) {
        if (!host || typeof host.id !== "string" || typeof host.name !== "string" || typeof host.dockerHost !== "string")
            throw new Error("Each host needs string id, name, and dockerHost values");

        var id = host.id.trim();
        var name = host.name.trim();
        var dockerHost = host.dockerHost.trim();
        if (!id || !name || !dockerHost)
            throw new Error("Host " + (index + 1) + " needs a non-empty id, name, and dockerHost");

        if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id))
            throw new Error("Host IDs must start with a letter or number and contain only letters, numbers, '.', '_' or '-'");

        if (usedIds.indexOf(id) !== -1)
            throw new Error("Host id '" + id + "' is duplicated or reserved for the local host");

        if (!isRemoteDockerEndpoint(dockerHost))
            throw new Error("Remote hosts must use an SSH Docker endpoint such as ssh://user@host");

        var endpointKey = dockerHost.toLowerCase();
        if (usedEndpoints.indexOf(endpointKey) !== -1)
            throw new Error("SSH endpoint '" + dockerHost + "' is configured more than once");

        usedIds.push(id);
        usedEndpoints.push(endpointKey);
        parsed.push({
            "id": id,
            "name": name,
            "dockerHost": dockerHost
        });
    });
    return parsed;
}

function parseHostConfig(raw) {
    var data = JSON.parse(String(raw || "{}"));
    if (!data || !Array.isArray(data.hosts))
        throw new Error("Expected a hosts array");

    return {
        "hosts": [localHost()].concat(validateRemoteHosts(data.hosts)),
        "proxyTest": data.proxyTest
    };
}

function prepareWrite(currentHosts, remoteHosts, proxyTestConfig, successMessage) {
    if (!Array.isArray(currentHosts))
        throw new Error("Expected current hosts array");

    var parsed = validateRemoteHosts(remoteHosts);
    var config = {
        "hosts": parsed
    };
    if (proxyTestConfig && proxyTestConfig.enabled === true)
        config.proxyTest = proxyTestConfig;

    return {
        "previousHosts": currentHosts.slice(),
        "hosts": [localHost()].concat(parsed),
        "pendingSuccess": String(successMessage || ""),
        "text": JSON.stringify(config, null, 2) + "\n"
    };
}

function rollbackWrite(transaction) {
    return {
        "hosts": transaction.previousHosts.slice(),
        "pendingSuccess": ""
    };
}
