import QtQuick
import Quickshell.Io

Item {
    id: root

    property string configPath: ""
    property string configurationError: ""
    property var hosts: []
    property var hostsBeforeWrite: []
    property string pendingSuccess: ""
    property var proxyTestConfig: ({
            "enabled": false
        })
    property bool proxyTestConfigLoaded: false

    signal configurationFailed(string message)
    signal configurationLoaded
    signal saveFailed(string message)
    signal saveSucceeded(string message)

    function loadConfig(raw) {
        try {
            var data = JSON.parse(String(raw || "{}"));
            if (!data || !Array.isArray(data.hosts))
                throw new Error("Expected a hosts array");

            var parsed = [
                {
                    "id": "local",
                    "name": "This machine",
                    "dockerHost": "unix:///var/run/docker.sock"
                }
            ];
            var usedIds = ["local"];
            var usedEndpoints = [];
            data.hosts.forEach(function (host, index) {
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

                if (!/^ssh:\/\/[^/\s?#]+$/.test(dockerHost))
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
            hosts = parsed;
            configurationError = "";
            if (data.proxyTest !== undefined) {
                configurationError = parseProxyTestConfig(JSON.stringify(data.proxyTest));
            } else {
                proxyTestConfig = {
                    "enabled": false
                };
                proxyTestConfigLoaded = true;
            }
            configurationLoaded();
        } catch (e) {
            useLocalOnly();
            configurationError = "Host config error: " + e.message;
            configurationFailed(configurationError);
        }
    }
    function parseProxyTestConfig(raw) {
        try {
            var test = JSON.parse(String(raw || "{}"));
            if (test.enabled !== true) {
                proxyTestConfig = {
                    "enabled": false
                };
                proxyTestConfigLoaded = true;
                return "";
            }
            if (typeof test.architecture !== "string" || test.architecture === "")
                throw new Error("architecture must be a non-empty string");

            if (typeof test.bundledBinary !== "boolean" || typeof test.goAvailable !== "boolean")
                throw new Error("bundledBinary and goAvailable must be true or false");

            if (test.sshAvailable !== undefined && typeof test.sshAvailable !== "boolean")
                throw new Error("sshAvailable must be true or false");

            if (test.lazydockerAvailable !== undefined && typeof test.lazydockerAvailable !== "boolean")
                throw new Error("lazydockerAvailable must be true or false");

            proxyTestConfig = test;
            proxyTestConfigLoaded = true;
            return "";
        } catch (e) {
            proxyTestConfig = {
                "enabled": false
            };
            proxyTestConfigLoaded = true;
            return "Proxy test config error: " + e.message;
        }
    }
    function reload() {
        configFile.reload();
    }
    function useLocalOnly() {
        hosts = [
            {
                "id": "local",
                "name": "This machine",
                "dockerHost": "unix:///var/run/docker.sock"
            }
        ];
        proxyTestConfig = {
            "enabled": false
        };
        proxyTestConfigLoaded = true;
    }
    function writeHosts(remoteHosts, successMessage) {
        hostsBeforeWrite = hosts.slice();
        hosts = [
            {
                "id": "local",
                "name": "This machine",
                "dockerHost": "unix:///var/run/docker.sock"
            }
        ].concat(remoteHosts);
        pendingSuccess = successMessage;
        var config = {
            "hosts": remoteHosts
        };
        if (proxyTestConfig.enabled === true)
            config.proxyTest = proxyTestConfig;

        configFile.setText(JSON.stringify(config, null, 2) + "\n");
    }

    FileView {
        id: configFile

        atomicWrites: true
        path: root.configPath
        printErrors: false
        watchChanges: true

        onFileChanged: configFile.reload()
        onLoadFailed: {
            root.useLocalOnly();
            root.configurationError = "Could not read " + root.configPath;
            root.configurationFailed(root.configurationError);
        }
        onLoaded: root.loadConfig(text())
        onSaveFailed: function (error) {
            root.hosts = root.hostsBeforeWrite;
            root.pendingSuccess = "";
            root.saveFailed("Could not save host config: " + error);
        }
        onSaved: {
            configFile.reload();
            if (root.pendingSuccess !== "") {
                var message = root.pendingSuccess;
                root.pendingSuccess = "";
                root.saveSucceeded(message);
            }
        }
    }
}
