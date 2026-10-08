import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool checkingProxyLaunch: false
    property var panel
    property string pendingDockerHost: ""

    signal launched
    signal requirementsChanged(var issues)

    function checkAvailability() {
        if (!panel || !panel.opened || checkingProxyLaunch)
            return;

        pendingDockerHost = "";
        checkingProxyLaunch = true;
        proxyPreflight.command = [proxyPath(), "--check"];
        proxyPreflight.running = true;
    }
    function launch(host, proxyTestEnabled) {
        var dockerHost = String(host.dockerHost || "unix:///var/run/docker.sock");
        if (dockerHost.indexOf("ssh://") === 0) {
            if (proxyTestEnabled || checkingProxyLaunch)
                return;

            panel.errorText = "";
            pendingDockerHost = dockerHost;
            checkingProxyLaunch = true;
            proxyPreflight.command = [proxyPath(), "--check"];
            proxyPreflight.running = true;
            return;
        }
        Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.lazydocker", "omarchy-launch-docker-tui"]);
        launched();
    }
    function launchRemoteDocker(dockerHost) {
        Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.lazydocker", proxyPath(), dockerHost]);
    }
    function proxyPath() {
        return Quickshell.env("HOME") + "/.config/omarchy/plugins/rafamedeiros.lazydocker-host-picker/docker-ssh-proxy-launcher";
    }
    function simulatePreflight(test) {
        var issues = [];
        if (!(test.architecture === "x86_64" && test.bundledBinary === true) && test.goAvailable !== true)
            issues.push("Go is required to build the Docker SSH proxy on " + test.architecture + ".");

        if (test.sshAvailable === false)
            issues.push("OpenSSH is not installed.");

        if (test.lazydockerAvailable === false)
            issues.push("Lazydocker is not installed.");

        requirementsChanged(issues);
    }

    height: 0
    visible: false
    width: 0

    Process {
        id: proxyPreflight

        stderr: StdioCollector {
            id: proxyPreflightStderr

            waitForEnd: true
        }
        stdout: StdioCollector {
            id: proxyPreflightStdout

            waitForEnd: true
        }

        onExited: function (exitCode) {
            root.checkingProxyLaunch = false;
            var dockerHost = root.pendingDockerHost;
            root.pendingDockerHost = "";
            if (exitCode === 0) {
                root.requirementsChanged([]);
                if (dockerHost !== "") {
                    root.launchRemoteDocker(dockerHost);
                    root.launched();
                }
            } else {
                var detail = String(proxyPreflightStderr.text || proxyPreflightStdout.text || "").trim();
                if (root.panel && root.panel.opened) {
                    var issues = detail.split(/\r?\n/).map(function (issue) {
                        return issue.trim();
                    }).filter(function (issue) {
                        return issue !== "";
                    });
                    root.requirementsChanged(issues.length > 0 ? issues : ["The SSH Docker proxy is not ready to launch."]);
                }
            }
        }
    }
}
