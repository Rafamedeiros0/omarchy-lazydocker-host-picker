import QtQuick
import Quickshell.Io
import "HostConfigModel.js" as HostConfigModel
import qs.Commons

Item {
    id: root

    property bool addHostCancelled: false
    property bool addHostTimedOut: false
    property bool addingHost: false
    property string checkingDraftEndpoint: ""
    property string checkingDraftId: ""
    property string checkingDraftName: ""
    property bool checkingNewHost: false
    property var configStore
    property alias drafts: hostDraftModel
    property var hostStatuses: ({})
    readonly property var hosts: configStore ? configStore.hosts : []
    property bool manageHosts: false
    property int nextDraftId: 1
    property var panel
    property bool pendingAddReturn: false
    property string pendingRemovalId: ""
    property var pickerWindow
    property var viewHosts: []

    function addHost(draftRow) {
        if (checkingNewHost) {
            setError("Another host connection check is already running.");
            return;
        }
        var name = draftRow.draftName.trim();
        var endpoint = normalizeEndpoint(draftRow.draftEndpoint);
        if (!name) {
            setError("Enter a display name.");
            draftRow.focusName();
            return;
        }
        if (!endpoint) {
            setError("Use an SSH alias or endpoint, e.g. host or ssh://user@host.");
            draftRow.focusEndpoint();
            return;
        }
        if (endpointInUse(endpoint, "") || draftEndpointInUse(endpoint, draftRow.draftId)) {
            setError("That SSH endpoint is already configured in another host or draft.");
            draftRow.focusEndpoint();
            return;
        }
        drafts.setProperty(draftRow.index, "draftEndpoint", endpoint);
        drafts.setProperty(draftRow.index, "draftError", "");
        setError("");
        checkingDraftId = String(draftRow.draftId);
        checkingDraftName = name;
        checkingDraftEndpoint = endpoint;
        addHostCancelled = false;
        addHostTimedOut = false;
        checkingNewHost = true;
        addHostTimeout.restart();
        addHostProbe.command = ["docker", "--host", endpoint, "info", "--format", "{{.ServerVersion}}"];
        addHostProbe.running = true;
    }
    function appendHostDraft() {
        drafts.append({
            "draftId": String(nextDraftId++),
            "draftName": "",
            "draftEndpoint": "",
            "draftError": ""
        });
        addingHost = true;
        pendingAddReturn = false;
        setError("");
        Qt.callLater(function () {
            var row = root.pickerWindow.draftRowsRepeater.itemAt(root.pickerWindow.draftRowsRepeater.count - 1);
            if (row)
                row.focusName();
        });
    }
    function beginManage() {
        manageHosts = true;
        addingHost = false;
        pendingAddReturn = false;
        pendingRemovalId = "";
        setError("");
        panel.successText = "";
    }
    function cancelPendingAdd() {
        if (!checkingNewHost)
            return;

        addHostCancelled = true;
        addHostTimeout.stop();
        addHostProbe.running = false;
    }
    function configurationLoaded() {
        hostStatuses = ({});
        viewHosts = hosts.slice();
    }
    function discardAllHostDrafts() {
        cancelPendingAdd();
        drafts.clear();
        addingHost = false;
        pendingAddReturn = false;
        setError("");
    }
    function draftEndpointInUse(endpoint, exceptId) {
        for (var i = 0; i < root.pickerWindow.draftRowsRepeater.count; i++) {
            var row = root.pickerWindow.draftRowsRepeater.itemAt(i);
            if (row && String(row.draftId) !== String(exceptId) && normalizeEndpoint(row.draftEndpoint).toLowerCase() === endpoint.toLowerCase())
                return true;
        }
        return false;
    }
    function endpointInUse(endpoint, exceptId) {
        return hosts.some(function (host) {
            return host.id !== "local" && String(host.id) !== String(exceptId || "") && String(host.dockerHost).toLowerCase() === endpoint.toLowerCase();
        });
    }
    function handleAddEscape(draftId) {
        if (pendingAddReturn) {
            pendingAddReturn = false;
            return;
        }
        var id = draftId === undefined && drafts.count > 0 ? drafts.get(drafts.count - 1).draftId : draftId;
        if (id !== undefined)
            removeHostDraft(id);
    }
    function handleEditEscape() {
        var hasUnsavedEdits = false;
        for (var i = 0; i < root.pickerWindow.hostRowsRepeater.count; i++) {
            var row = root.pickerWindow.hostRowsRepeater.itemAt(i);
            if (!row)
                continue;

            if (row.savingEdit) {
                setError("Wait for the connection check to finish.");
                return;
            }
            if (row.editDirty) {
                row.editName = row.modelData.name;
                row.editEndpoint = row.modelData.dockerHost;
                hasUnsavedEdits = true;
            }
        }
        if (hasUnsavedEdits) {
            setError("");
            panel.showSuccess("Unsaved changes discarded");
        } else {
            returnToView();
        }
    }
    function hostAvailable(host) {
        if (!host || host.id === "local")
            return true;

        return hostStatuses[host.id] && hostStatuses[host.id].status === "online";
    }
    function normalizeEndpoint(raw) {
        return HostConfigModel.normalizeEndpoint(raw);
    }
    function offlineHostCount() {
        var count = 0;
        hosts.forEach(function (host) {
            var state = hostStatuses[host.id];
            if (host.id !== "local" && state && state.status === "unreachable")
                count++;
        });
        return count;
    }
    function persistRemoteHosts(remoteHosts, successMessage) {
        configStore.writeHosts(remoteHosts, successMessage);
        rebuildViewHosts();
    }
    function rebuildViewHosts() {
        viewHosts = hosts.slice();
    }
    function removeHost(host) {
        if (!host || host.id === "local")
            return;

        var remoteHosts = hosts.filter(function (entry) {
            return entry.id !== "local" && String(entry.id) !== String(host.id);
        });
        pendingRemovalId = "";
        persistRemoteHosts(remoteHosts, "Removed " + host.name);
    }
    function removeHostDraft(draftId, keepReturnConfirmation) {
        if (checkingNewHost && checkingDraftId === String(draftId))
            cancelPendingAdd();

        for (var i = 0; i < drafts.count; i++) {
            if (String(drafts.get(i).draftId) === String(draftId)) {
                drafts.remove(i);
                break;
            }
        }
        addingHost = drafts.count > 0;
        if (!keepReturnConfirmation || drafts.count === 0)
            pendingAddReturn = false;

        setError("");
    }
    function requestReturnToView() {
        if (!addingHost) {
            returnToView();
        } else if (pendingAddReturn) {
            discardAllHostDrafts();
            returnToView();
        } else {
            setError("");
            pendingAddReturn = true;
        }
    }
    function resetForOpen() {
        addingHost = false;
        drafts.clear();
        manageHosts = false;
        pendingAddReturn = false;
        pendingRemovalId = "";
        setError("");
    }
    function returnToView() {
        manageHosts = false;
        addingHost = false;
        drafts.clear();
        pendingAddReturn = false;
        pendingRemovalId = "";
        setError("");
    }
    function saveRemoteHost(name, endpoint, version, draftId) {
        var remoteHosts = hosts.filter(function (host) {
            return host.id !== "local";
        });
        for (var i = 0; i < remoteHosts.length; i++) {
            if (String(remoteHosts[i].dockerHost).toLowerCase() === endpoint.toLowerCase()) {
                setError("That SSH endpoint is already configured.");
                return;
            }
        }
        var baseId = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (!baseId)
            baseId = "host";

        var hostId = baseId;
        var suffix = 2;
        while (remoteHosts.some(function (host) {
            return String(host.id) === hostId;
        }))
            hostId = baseId + "-" + suffix++;
        remoteHosts.push({
            "id": hostId,
            "name": name,
            "dockerHost": endpoint
        });
        removeHostDraft(draftId, true);
        persistRemoteHosts(remoteHosts, "Added " + name);
    }
    function setError(message) {
        if (panel)
            panel.errorText = message;
    }
    function statusColor(status) {
        if (status === "online")
            return Color.accent;

        if (status === "unreachable")
            return Color.urgent;

        return Color.muted;
    }
    function statusDescription(status, version, detail) {
        if (status === "online")
            return "Online" + (version ? " - Docker " + version : "");

        if (status === "unreachable")
            return "Unreachable" + (detail ? " - " + detail : "");

        if (status === "checking")
            return "Checking connection";

        return "Connection status unknown";
    }
    function updateHostStatus(id, status, version, detail) {
        var next = Object.assign({}, hostStatuses);
        next[id] = {
            "status": status,
            "version": version,
            "detail": detail
        };
        hostStatuses = next;
    }
    function updateRemoteHost(host, name, endpoint, version) {
        var remoteHosts = hosts.filter(function (entry) {
            return entry.id !== "local";
        }).map(function (entry) {
            return {
                "id": entry.id,
                "name": entry.name,
                "dockerHost": entry.dockerHost
            };
        });
        var found = false;
        for (var i = 0; i < remoteHosts.length; i++) {
            if (String(remoteHosts[i].id) === String(host.id)) {
                remoteHosts[i] = {
                    "id": host.id,
                    "name": name,
                    "dockerHost": endpoint
                };
                found = true;
                break;
            }
        }
        if (!found) {
            setError("That host is no longer in the list.");
            return;
        }
        persistRemoteHosts(remoteHosts, "Updated " + name);
        updateHostStatus(host.id, "online", version, "");
    }

    height: 0
    visible: false
    width: 0

    ListModel {
        id: hostDraftModel
    }
    Process {
        id: addHostProbe

        stderr: StdioCollector {
            id: addHostStderr

            waitForEnd: true
        }
        stdout: StdioCollector {
            id: addHostStdout

            waitForEnd: true
        }

        onExited: function (exitCode) {
            addHostTimeout.stop();
            root.checkingNewHost = false;
            var draftId = root.checkingDraftId;
            var name = root.checkingDraftName;
            var endpoint = root.checkingDraftEndpoint;
            root.checkingDraftId = "";
            if (root.addHostCancelled) {
                root.addHostCancelled = false;
                return;
            }
            if (root.addHostTimedOut) {
                root.addHostTimedOut = false;
                return;
            }
            if (exitCode === 0) {
                root.saveRemoteHost(name, endpoint, String(addHostStdout.text || "").trim(), draftId);
            } else {
                var detail = String(addHostStderr.text || "").trim().split("\n")[0] || "Could not connect to Docker at that SSH endpoint.";
                root.setError(detail);
                for (var i = 0; i < root.pickerWindow.draftRowsRepeater.count; i++) {
                    var row = root.pickerWindow.draftRowsRepeater.itemAt(i);
                    if (row && String(row.draftId) === draftId) {
                        hostDraftModel.setProperty(row.index, "draftError", detail);
                        break;
                    }
                }
            }
        }
    }
    Timer {
        id: addHostTimeout

        interval: 8000

        onTriggered: {
            if (!addHostProbe.running)
                return;

            root.addHostTimedOut = true;
            root.setError("Connection timed out. Check the SSH target and try again.");
            for (var i = 0; i < root.pickerWindow.draftRowsRepeater.count; i++) {
                var row = root.pickerWindow.draftRowsRepeater.itemAt(i);
                if (row && String(row.draftId) === root.checkingDraftId) {
                    hostDraftModel.setProperty(row.index, "draftError", "Connection timed out. Check the SSH target and try again.");
                    break;
                }
            }
            addHostProbe.running = false;
        }
    }
}
