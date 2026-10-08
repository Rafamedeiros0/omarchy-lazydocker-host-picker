import QtQuick
import Quickshell.Io
import "HostConfigModel.js" as HostConfigModel

Item {
    id: root

    property string configPath: ""
    property string configurationError: ""
    property var hosts: []
    property string pendingSuccess: ""
    property var pendingWrite: null
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
            var data = HostConfigModel.parseHostConfig(raw);
            hosts = data.hosts;
            configurationError = "";
            if (data.proxyTest !== undefined)
                configurationError = parseProxyTestConfig(JSON.stringify(data.proxyTest));
            else {
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
        hosts = [HostConfigModel.localHost()];
        proxyTestConfig = {
            "enabled": false
        };
        proxyTestConfigLoaded = true;
    }
    function writeHosts(remoteHosts, successMessage) {
        var transaction;
        try {
            transaction = HostConfigModel.prepareWrite(hosts, remoteHosts, proxyTestConfig, successMessage);
        } catch (e) {
            saveFailed("Could not save host config: " + e.message);
            return false;
        }
        pendingWrite = transaction;
        hosts = transaction.hosts;
        pendingSuccess = transaction.pendingSuccess;
        configFile.setText(transaction.text);
        return true;
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
            if (root.pendingWrite !== null) {
                var rollback = HostConfigModel.rollbackWrite(root.pendingWrite);
                root.hosts = rollback.hosts;
                root.pendingSuccess = rollback.pendingSuccess;
                root.pendingWrite = null;
            }
            root.saveFailed("Could not save host config: " + error);
        }
        onSaved: {
            configFile.reload();
            root.pendingWrite = null;
            if (root.pendingSuccess !== "") {
                var message = root.pendingSuccess;
                root.pendingSuccess = "";
                root.saveSucceeded(message);
            }
        }
    }
}
