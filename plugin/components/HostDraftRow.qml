import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
    id: draftRow

    property var controller
    required property string draftEndpoint
    required property string draftError
    required property string draftId
    required property string draftName
    required property int index
    property bool isSaving: controller.checkingNewHost && controller.checkingDraftId === String(draftId)

    function focusEndpoint() {
        draftEndpointField.forceActiveFocus();
    }
    function focusName() {
        draftNameField.forceActiveFocus();
    }

    border.color: draftRow.isSaving ? Color.accent : controller.panelBorder
    border.width: 1
    color: controller.hoverBackground
    height: Style.space(68)
    radius: Style.space(10)
    width: parent.width

    Row {
        height: parent.height
        spacing: Style.space(10)
        width: parent.width - Style.space(28)
        x: Style.space(14)
        y: 0

        Rectangle {
            color: draftRow.draftError !== "" ? controller.hostManagerApi.statusColor("unreachable") : (draftRow.isSaving ? controller.hostManagerApi.statusColor("checking") : controller.hostManagerApi.statusColor("unknown"))
            height: width
            radius: width / 2
            width: Style.space(10)
            y: (parent.height - height) / 2
        }
        Column {
            height: Style.space(50)
            spacing: Style.space(2)
            width: parent.width - Style.space(10) - draftActions.width - parent.spacing * 2
            y: (parent.height - height) / 2

            Row {
                height: Style.space(26)
                width: parent.width

                TextField {
                    id: draftNameField

                    color: controller.panelForeground
                    enabled: !draftRow.isSaving
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    height: parent.height
                    placeholderText: "Name"
                    selectByMouse: true
                    text: draftRow.draftName
                    width: parent.width

                    background: Rectangle {
                        border.color: draftNameField.activeFocus ? Color.accent : controller.panelBorder
                        border.width: 1
                        color: controller.panelBackground
                        radius: Style.space(7)
                    }

                    Keys.onEscapePressed: controller.hostManagerApi.handleAddEscape(draftRow.draftId)
                    onAccepted: draftEndpointField.forceActiveFocus()
                    onTextChanged: controller.hostManagerApi.drafts.setProperty(draftRow.index, "draftName", text)
                }
            }
            Row {
                height: Style.space(22)
                width: parent.width

                TextField {
                    id: draftEndpointField

                    color: controller.panelForeground
                    enabled: !draftRow.isSaving
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    height: parent.height
                    placeholderText: "SSH alias / ssh://user@host"
                    selectByMouse: true
                    text: draftRow.draftEndpoint
                    width: parent.width

                    background: Rectangle {
                        border.color: draftEndpointField.activeFocus ? Color.accent : controller.panelBorder
                        border.width: 1
                        color: controller.panelBackground
                        radius: Style.space(7)
                    }

                    Keys.onEscapePressed: controller.hostManagerApi.handleAddEscape(draftRow.draftId)
                    onAccepted: controller.hostManagerApi.addHost(draftRow)
                    onTextChanged: controller.hostManagerApi.drafts.setProperty(draftRow.index, "draftEndpoint", text)
                }
            }
        }
        Item {
            id: draftActions

            height: parent.height
            width: Style.space(74)

            Row {
                height: Style.space(34)
                spacing: Style.space(6)
                width: parent.width
                y: (parent.height - height) / 2

                Rectangle {
                    ToolTip.delay: 450
                    ToolTip.text: "Test connection and save host"
                    ToolTip.visible: draftSaveMouse.containsMouse && !controller.showingRequirementIssues
                    border.color: Color.accent
                    border.width: 1
                    color: draftSaveMouse.containsMouse ? controller.hoverBackground : controller.panelBackground
                    height: width
                    radius: Style.space(7)
                    width: Style.space(34)

                    Text {
                        anchors.centerIn: parent
                        color: draftRow.isSaving ? Color.muted : Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        text: draftRow.isSaving ? "↻" : "󰆓"

                        NumberAnimation on rotation {
                            duration: 800
                            from: 0
                            loops: Animation.Infinite
                            running: draftRow.isSaving
                            to: 360
                        }
                    }
                    MouseArea {
                        id: draftSaveMouse

                        anchors.fill: parent
                        enabled: !controller.checkingNewHost
                        hoverEnabled: true

                        onClicked: controller.hostManagerApi.addHost(draftRow)
                    }
                }
                Rectangle {
                    ToolTip.delay: 450
                    ToolTip.text: "Discard this draft"
                    ToolTip.visible: draftRemoveMouse.containsMouse && !controller.showingRequirementIssues
                    border.color: Color.urgent
                    border.width: 1
                    color: draftRemoveMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18) : "transparent"
                    height: width
                    radius: Style.space(7)
                    width: Style.space(34)

                    Text {
                        anchors.centerIn: parent
                        color: Color.urgent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        text: "󰆴"
                    }
                    MouseArea {
                        id: draftRemoveMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: controller.hostManagerApi.removeHostDraft(draftRow.draftId)
                    }
                }
            }
        }
    }
}
