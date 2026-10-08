import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons

Rectangle {
    id: hostRow

    property bool chosen: controller.selectedIndex === index
    property var controller
    property bool editDirty: editName !== modelData.name || editEndpoint !== modelData.dockerHost
    property string editEndpoint: modelData.dockerHost
    property string editName: modelData.name
    property bool editTimedOut: false
    property bool editable: controller.manageHosts && modelData.id !== "local"
    property bool highlighted: chosen || hovered
    property bool hovered: rowHover.hovered
    required property int index
    required property var modelData
    property bool removable: controller.manageHosts && modelData.id !== "local"
    property bool savingEdit: false
    property string serverVersion: ""
    property string status: "unknown"
    property string statusDetail: ""
    property bool timedOut: false

    function saveHostEdits() {
        var nextName = editName.trim();
        var nextEndpoint = controller.hostManagerApi.normalizeEndpoint(editEndpoint);
        if (!nextName) {
            controller.errorText = "Enter a host name.";
            editNameField.forceActiveFocus();
            return;
        }
        if (!nextEndpoint) {
            controller.errorText = "Use an SSH alias or endpoint, e.g. host or ssh://user@host.";
            editEndpointField.forceActiveFocus();
            return;
        }
        if (controller.hostManagerApi.endpointInUse(nextEndpoint, modelData.id)) {
            controller.errorText = "That SSH endpoint is already assigned to another host.";
            editEndpointField.forceActiveFocus();
            return;
        }
        editEndpoint = nextEndpoint;
        controller.errorText = "";
        savingEdit = true;
        editTimeout.restart();
        editProbe.command = ["docker", "--host", nextEndpoint, "info", "--format", "{{.ServerVersion}}"];
        editProbe.running = true;
    }

    border.color: hostRow.chosen ? Style.selectedBorderFor(Color.foreground, Color.accent, Color.urgent) : (hostRow.hovered ? Style.hoverBorderFor(Color.foreground, Color.accent, Color.urgent) : Style.normalBorderFor(Color.foreground, Color.accent, Color.urgent))
    border.width: hostRow.highlighted ? Math.max(1, Style.selectedBorderWidth) : Math.max(1, Style.normalBorderWidth)
    color: hostRow.chosen ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent) : (hostRow.hovered ? Style.hoverFillFor(Color.foreground, Color.accent, Color.urgent) : Style.normalFillFor(Color.foreground, Color.accent, Color.urgent))
    height: Style.space(68)
    opacity: modelData.id !== "local" && status !== "online" && !controller.manageHosts ? 0.58 : 1
    radius: Style.space(10)
    width: parent.width

    Component.onCompleted: {
        editName = modelData.name;
        editEndpoint = modelData.dockerHost;
        status = "checking";
        controller.hostManagerApi.updateHostStatus(modelData.id, "checking", "", "");
        probe.command = modelData.id === "local" ? ["docker", "--host", "unix:///var/run/docker.sock", "info", "--format", "{{.ServerVersion}}"] : ["docker", "--host", modelData.dockerHost, "info", "--format", "{{.ServerVersion}}"];
        probe.running = true;
    }

    HoverHandler {
        id: rowHover
    }
    Process {
        id: probe

        stderr: StdioCollector {
            id: probeStderr

            waitForEnd: true
        }
        stdout: StdioCollector {
            id: probeStdout

            waitForEnd: true
        }

        onExited: function (exitCode) {
            probeTimeout.stop();
            if (hostRow.timedOut)
                return;

            hostRow.status = exitCode === 0 ? "online" : "unreachable";
            hostRow.serverVersion = String(probeStdout.text || "").trim();
            hostRow.statusDetail = exitCode === 0 ? "" : String(probeStderr.text || "").trim().split("\n")[0];
            controller.hostManagerApi.updateHostStatus(hostRow.modelData.id, hostRow.status, hostRow.serverVersion, hostRow.statusDetail);
        }
    }
    Timer {
        id: probeTimeout

        interval: 6000
        running: probe.running

        onTriggered: {
            hostRow.timedOut = true;
            hostRow.status = "unreachable";
            hostRow.statusDetail = "Check timed out";
            controller.hostManagerApi.updateHostStatus(hostRow.modelData.id, hostRow.status, "", hostRow.statusDetail);
            probe.running = false;
        }
    }
    Process {
        id: editProbe

        stderr: StdioCollector {
            id: editStderr

            waitForEnd: true
        }
        stdout: StdioCollector {
            id: editStdout

            waitForEnd: true
        }

        onExited: function (exitCode) {
            editTimeout.stop();
            hostRow.savingEdit = false;
            if (hostRow.editTimedOut) {
                hostRow.editTimedOut = false;
                return;
            }
            if (exitCode === 0) {
                controller.hostManagerApi.updateRemoteHost(hostRow.modelData, hostRow.editName.trim(), hostRow.editEndpoint, String(editStdout.text || "").trim());
            } else {
                var detail = String(editStderr.text || "").trim().split("\n")[0];
                controller.errorText = detail || "Could not connect to Docker at that SSH endpoint.";
            }
        }
    }
    Timer {
        id: editTimeout

        interval: 8000
        running: editProbe.running

        onTriggered: {
            hostRow.editTimedOut = true;
            hostRow.savingEdit = false;
            controller.errorText = "Connection timed out. Check the SSH target and try again.";
            editProbe.running = false;
        }
    }
    Row {
        id: hostContent

        height: parent.height
        spacing: Style.space(10)
        width: parent.width - Style.space(28)
        x: Style.space(14)
        y: 0
        z: 1

        Rectangle {
            id: rowStatusDot

            ToolTip.delay: 450
            ToolTip.text: controller.hostManagerApi.statusDescription(hostRow.status, hostRow.serverVersion, hostRow.statusDetail)
            ToolTip.visible: (hostRow.hovered || hostRow.chosen) && !controller.showingRequirementIssues
            color: controller.hostManagerApi.statusColor(hostRow.status)
            height: width
            radius: width / 2
            width: Style.space(10)
            y: (parent.height - height) / 2
        }
        Column {
            id: viewHostInfo

            height: Style.space(50)
            spacing: Style.space(2)
            visible: !hostRow.editable
            width: parent.width - rowStatusDot.width - actionRail.width - parent.spacing * 2
            y: (parent.height - height) / 2

            Row {
                height: Style.space(26)
                width: parent.width

                Text {
                    color: controller.panelForeground
                    elide: Text.ElideRight
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    height: parent.height
                    text: hostRow.modelData.name
                    verticalAlignment: Text.AlignVCenter
                    width: parent.width
                }
            }
            Text {
                color: Color.muted
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                height: Style.space(22)
                text: hostRow.modelData.id === "local" ? "Local Docker socket" : hostRow.modelData.dockerHost
                verticalAlignment: Text.AlignVCenter
                width: parent.width
            }
        }
        Column {
            id: editHostInfo

            height: Style.space(50)
            spacing: Style.space(2)
            visible: hostRow.editable
            width: parent.width - rowStatusDot.width - actionRail.width - parent.spacing * 2
            y: (parent.height - height) / 2

            Row {
                height: Style.space(26)
                width: parent.width

                TextField {
                    id: editNameField

                    color: controller.panelForeground
                    enabled: !hostRow.savingEdit && !controller.checkingNewHost
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    height: parent.height
                    placeholderText: "Name"
                    selectByMouse: true
                    text: hostRow.editName
                    width: parent.width

                    background: Rectangle {
                        border.color: editNameField.activeFocus ? Color.accent : controller.panelBorder
                        border.width: 1
                        color: controller.panelBackground
                        radius: Style.space(7)
                    }

                    Keys.onEscapePressed: controller.hostManagerApi.handleEditEscape()
                    onAccepted: editEndpointField.forceActiveFocus()
                    onTextChanged: hostRow.editName = text
                }
            }
            Row {
                height: Style.space(22)
                spacing: Style.space(6)
                width: parent.width

                TextField {
                    id: editEndpointField

                    color: controller.panelForeground
                    enabled: !hostRow.savingEdit && !controller.checkingNewHost
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    height: parent.height
                    placeholderText: "SSH connection"
                    selectByMouse: true
                    text: hostRow.editEndpoint
                    width: parent.width

                    background: Rectangle {
                        border.color: editEndpointField.activeFocus ? Color.accent : controller.panelBorder
                        border.width: 1
                        color: controller.panelBackground
                        radius: Style.space(7)
                    }

                    Keys.onEscapePressed: controller.hostManagerApi.handleEditEscape()
                    onAccepted: hostRow.saveHostEdits()
                    onTextChanged: hostRow.editEndpoint = text
                }
            }
        }
        Item {
            id: actionRail

            height: parent.height
            width: hostRow.editable ? Style.space(74) : 0

            Row {
                height: Style.space(34)
                spacing: Style.space(6)
                width: parent.width
                y: (parent.height - height) / 2

                Rectangle {
                    id: editSaveButton

                    ToolTip.delay: 450
                    ToolTip.text: "Test connection and save"
                    ToolTip.visible: hostRow.editDirty && editSaveMouse.containsMouse && !controller.showingRequirementIssues
                    border.color: Color.accent
                    border.width: 1
                    color: editSaveMouse.containsMouse ? controller.hoverBackground : "transparent"
                    height: width
                    opacity: hostRow.editDirty || hostRow.savingEdit ? 1 : 0
                    radius: Style.space(7)
                    visible: hostRow.editable
                    width: Style.space(34)

                    Text {
                        anchors.centerIn: parent
                        color: hostRow.savingEdit ? Color.muted : Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        text: hostRow.savingEdit ? "↻" : "󰆓"

                        NumberAnimation on rotation {
                            duration: 800
                            from: 0
                            loops: Animation.Infinite
                            running: hostRow.savingEdit
                            to: 360
                        }
                    }
                    MouseArea {
                        id: editSaveMouse

                        anchors.fill: parent
                        enabled: hostRow.editable && hostRow.editDirty && !hostRow.savingEdit && !controller.checkingNewHost
                        hoverEnabled: true

                        onClicked: hostRow.saveHostEdits()
                    }
                }
                Rectangle {
                    id: removeButton

                    ToolTip.delay: 450
                    ToolTip.text: controller.pendingRemovalId === hostRow.modelData.id ? "Click again to confirm removal" : "Remove host"
                    ToolTip.visible: removeMouse.containsMouse && !controller.showingRequirementIssues
                    border.color: Color.urgent
                    border.width: 1
                    color: controller.pendingRemovalId === hostRow.modelData.id || removeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18) : "transparent"
                    height: width
                    radius: Style.space(7)
                    visible: hostRow.removable
                    width: Style.space(34)

                    Text {
                        anchors.centerIn: parent
                        color: Color.urgent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        text: controller.pendingRemovalId === hostRow.modelData.id ? "!" : "󰆴"
                    }
                    MouseArea {
                        id: removeMouse

                        anchors.fill: parent
                        enabled: hostRow.removable
                        hoverEnabled: true

                        onClicked: {
                            if (controller.pendingRemovalId === hostRow.modelData.id)
                                controller.hostManagerApi.removeHost(hostRow.modelData);
                            else
                                controller.pendingRemovalId = hostRow.modelData.id;
                        }
                    }
                }
            }
        }
    }
    MouseArea {
        id: rowMouse

        anchors.fill: parent
        enabled: !controller.manageHosts && (hostRow.modelData.id === "local" || hostRow.status === "online")
        hoverEnabled: true
        z: controller.manageHosts ? 0 : 2

        onClicked: controller.launch(hostRow.modelData)
        onEntered: controller.selectedIndex = hostRow.index
    }
}
