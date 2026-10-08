import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id: pickerHeader

    property var controller
    readonly property real headerRowHeight: headerRow.height
    readonly property color modeButtonBorder: {
        if (pickerHeader.controller.pendingAddReturn)
            return Color.urgent;
        return pickerHeader.controller.manageHosts ? Color.accent : pickerHeader.controller.panelBorder;
    }
    readonly property color modeButtonFill: {
        if (pickerHeader.controller.pendingAddReturn)
            return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18);
        return modeMouse.containsMouse ? pickerHeader.controller.hoverBackground : "transparent";
    }
    readonly property color modeButtonForeground: {
        if (pickerHeader.controller.pendingAddReturn)
            return Color.urgent;
        return pickerHeader.controller.manageHosts ? Color.accent : pickerHeader.controller.panelForeground;
    }
    readonly property string modeButtonGlyph: {
        if (pickerHeader.controller.pendingAddReturn)
            return "!";
        return pickerHeader.controller.manageHosts ? "󰍃" : "󰏫";
    }
    readonly property string modeButtonHelp: {
        if (pickerHeader.controller.pendingAddReturn)
            return "Click again to discard draft and return";
        return pickerHeader.controller.manageHosts ? "Return to view" : "Edit hosts";
    }
    readonly property int offlineHostCount: pickerHeader.controller.hostManagerApi.offlineHostCount()
    readonly property color shortcutButtonBorder: {
        if (pickerHeader.controller.shortcuts.settingsOpen)
            return Color.accent;
        return pickerHeader.controller.panelBorder;
    }
    readonly property string shortcutButtonHelp: {
        if (pickerHeader.controller.shortcuts.current !== "")
            return "Shortcut: " + pickerHeader.controller.shortcuts.current;
        return "Shortcut settings";
    }
    readonly property real titleHeight: panelTitle.implicitHeight

    spacing: Style.space(12)
    width: parent.width

    Row {
        id: headerRow

        height: Style.space(34)
        spacing: Style.space(6)
        width: parent.width

        Text {
            id: headerLabel

            color: Color.muted
            elide: Text.ElideRight
            font.family: Style.font.family
            font.letterSpacing: 2
            font.pixelSize: Style.font.caption
            height: parent.height
            text: pickerHeader.controller.manageHosts ? "MANAGE / HOSTS" : "DOCKER / HOST"
            verticalAlignment: Text.AlignVCenter
            width: parent.width - actionGroup.width - parent.spacing
        }
        Row {
            id: actionGroup

            height: parent.height
            spacing: Style.space(6)
            width: Style.space(pickerHeader.controller.manageHosts ? 74 : 114)

            Rectangle {
                border.color: pickerHeader.controller.panelBorder
                border.width: 1
                color: addMouse.containsMouse ? pickerHeader.controller.hoverBackground : "transparent"
                height: parent.height
                opacity: pickerHeader.controller.manageHosts ? 1 : 0
                radius: Style.space(7)
                width: Style.space(34)

                Text {
                    anchors.centerIn: parent
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    text: "+"
                }
                MouseArea {
                    id: addMouse

                    anchors.fill: parent
                    enabled: pickerHeader.controller.manageHosts
                    hoverEnabled: true

                    onClicked: pickerHeader.controller.hostManagerApi.appendHostDraft()
                }
            }
            Rectangle {
                id: modeButton

                ToolTip.delay: 450
                ToolTip.text: pickerHeader.modeButtonHelp
                ToolTip.visible: modeMouse.containsMouse && !pickerHeader.controller.showingRequirementIssues
                border.color: pickerHeader.modeButtonBorder
                border.width: 1
                color: pickerHeader.modeButtonFill
                height: parent.height
                radius: Style.space(7)
                width: Style.space(34)

                Text {
                    anchors.centerIn: parent
                    color: pickerHeader.modeButtonForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    text: pickerHeader.modeButtonGlyph
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    border.color: pickerHeader.controller.panelBackground
                    border.width: 1
                    color: Color.urgent
                    height: width
                    radius: width / 2
                    visible: !pickerHeader.controller.manageHosts && pickerHeader.offlineHostCount > 0
                    width: Style.space(15)

                    Text {
                        anchors.centerIn: parent
                        color: pickerHeader.controller.panelBackground
                        font.bold: true
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        text: pickerHeader.offlineHostCount > 9 ? "9+" : String(pickerHeader.offlineHostCount)
                    }
                }
                MouseArea {
                    id: modeMouse

                    anchors.fill: parent
                    enabled: pickerHeader.controller.manageHosts || !pickerHeader.controller.checkingNewHost
                    hoverEnabled: true

                    onClicked: {
                        if (pickerHeader.controller.manageHosts)
                            pickerHeader.controller.hostManagerApi.requestReturnToView();
                        else
                            pickerHeader.controller.hostManagerApi.beginManage();
                    }
                }
            }
            Rectangle {
                ToolTip.delay: 450
                ToolTip.text: pickerHeader.shortcutButtonHelp
                ToolTip.visible: settingsMouse.containsMouse
                border.color: pickerHeader.shortcutButtonBorder
                border.width: 1
                color: settingsMouse.containsMouse ? pickerHeader.controller.hoverBackground : "transparent"
                height: parent.height
                radius: Style.space(7)
                visible: !pickerHeader.controller.manageHosts
                width: Style.space(34)

                Text {
                    anchors.centerIn: parent
                    color: pickerHeader.controller.shortcuts.settingsOpen ? Color.accent : pickerHeader.controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    text: "󰒓"
                }
                MouseArea {
                    id: settingsMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: pickerHeader.controller.shortcuts.openSettings()
                }
            }
        }
    }
    Text {
        id: panelTitle

        color: pickerHeader.controller.panelForeground
        font.bold: true
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        text: pickerHeader.controller.manageHosts ? "Manage hosts" : "Where are we going?"
        width: parent.width
    }
}
