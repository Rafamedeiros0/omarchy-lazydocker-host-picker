import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
    id: shortcutSettingsSurface

    property real cardHeight: 0
    property real cardRadius: 0
    property real cardWidth: 0
    property var controller

    anchors.fill: parent
    color: "transparent"
    visible: shortcutSettingsSurface.controller.shortcuts.settingsOpen && shortcutSettingsSurface.controller.opened
    z: 200

    Connections {
        function onCaptureReady() {
            captureKeys.forceActiveFocus();
        }

        target: shortcutSettingsSurface.controller.shortcuts
    }
    Rectangle {
        id: shortcutSettingsCard

        anchors.centerIn: parent
        border.color: shortcutSettingsSurface.controller.panelBorder
        border.width: 1
        color: shortcutSettingsSurface.controller.panelBackground
        height: shortcutSettingsSurface.cardHeight
        radius: shortcutSettingsSurface.cardRadius
        width: shortcutSettingsSurface.cardWidth

        Column {
            id: shortcutColumn

            anchors.bottomMargin: Style.space(48)
            anchors.fill: parent
            anchors.margins: Style.space(24)
            spacing: Style.space(12)

            Row {
                height: Style.space(34)
                spacing: Style.space(6)
                width: parent.width

                Text {
                    color: Color.muted
                    elide: Text.ElideRight
                    font.family: Style.font.family
                    font.letterSpacing: 2
                    font.pixelSize: Style.font.caption
                    height: parent.height
                    text: "DOCKER / SHORTCUT"
                    verticalAlignment: Text.AlignVCenter
                    width: parent.width - settingsBackButton.width - parent.spacing
                }
                Rectangle {
                    id: settingsBackButton

                    ToolTip.delay: 450
                    ToolTip.text: "Return to hosts"
                    ToolTip.visible: settingsBackMouse.containsMouse
                    border.color: Color.accent
                    border.width: 1
                    color: settingsBackMouse.containsMouse ? shortcutSettingsSurface.controller.hoverBackground : "transparent"
                    height: parent.height
                    radius: Style.space(7)
                    width: Style.space(34)

                    Text {
                        anchors.centerIn: parent
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        text: "󰍃"
                    }
                    MouseArea {
                        id: settingsBackMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            shortcutSettingsSurface.controller.shortcuts.closeSettings();
                        }
                    }
                }
            }
            Text {
                color: shortcutSettingsSurface.controller.panelForeground
                font.bold: true
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                text: "Picker shortcut"
                width: parent.width
            }
            Text {
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: "Choose a shortcut to open Lazydocker Picker. Reset restores Omarchy's Docker action on Super+Shift+D."
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Rectangle {
                border.color: shortcutSettingsSurface.controller.panelBorder
                border.width: 1
                color: shortcutSettingsSurface.controller.hoverBackground
                height: Style.space(38)
                radius: Style.space(8)
                width: parent.width

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(8)

                    Text {
                        color: Color.muted
                        elide: Text.ElideRight
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        height: parent.height
                        text: "Current shortcut"
                        verticalAlignment: Text.AlignVCenter
                        width: parent.width - shortcutValue.implicitWidth - parent.spacing
                    }
                    Text {
                        id: shortcutValue

                        color: shortcutSettingsSurface.controller.shortcuts.current !== "" ? Color.accent : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        height: parent.height
                        text: shortcutSettingsSurface.controller.shortcuts.current !== "" ? shortcutSettingsSurface.controller.shortcuts.current : "None"
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Text {
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: shortcutSettingsSurface.controller.shortcuts.error
                visible: shortcutSettingsSurface.controller.shortcuts.error !== ""
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Item {
                height: Style.space(66)
                visible: shortcutSettingsSurface.controller.shortcuts.captureActive
                width: parent.width

                Rectangle {
                    anchors.fill: parent
                    border.color: shortcutSettingsSurface.controller.shortcuts.inhibitorReady ? Color.accent : Color.urgent
                    border.width: 1
                    color: shortcutSettingsSurface.controller.hoverBackground
                    radius: Style.space(8)
                }
                Text {
                    anchors.centerIn: parent
                    color: shortcutSettingsSurface.controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    horizontalAlignment: Text.AlignHCenter
                    text: shortcutSettingsSurface.controller.shortcuts.inhibitorReady ? "Press a combination, e.g. Super + Shift + K" : "Preparing safe shortcut capture…"
                    width: parent.width - Style.space(20)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
                Item {
                    id: captureKeys

                    anchors.fill: parent
                    focus: shortcutSettingsSurface.controller.shortcuts.captureActive && shortcutSettingsSurface.controller.shortcuts.inhibitorReady

                    Keys.onPressed: function (event) {
                        event.accepted = true;
                        if (event.key === Qt.Key_Escape) {
                            shortcutSettingsSurface.controller.shortcuts.cancelCapture();
                            return;
                        }
                        var combo = shortcutSettingsSurface.controller.shortcuts.shortcutFromEvent(event);
                        if (combo !== "") {
                            shortcutSettingsSurface.controller.shortcuts.cancelCapture();
                            shortcutSettingsSurface.controller.shortcuts.submitCandidate(combo);
                        } else if (event.key !== Qt.Key_Shift && event.key !== Qt.Key_Control && event.key !== Qt.Key_Alt && event.key !== Qt.Key_Meta) {
                            shortcutSettingsSurface.controller.shortcuts.cancelCapture();
                            shortcutSettingsSurface.controller.shortcuts.error = "Use a modifier with a supported letter, number, function, or navigation key.";
                        }
                    }
                }
            }
            Text {
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: "That combination is already used by " + shortcutSettingsSurface.controller.shortcuts.conflicts.map(function (item) {
                    return item.description;
                }).join(", ") + ". Replace it? The previous binding will return when you reset or change the picker shortcut."
                visible: shortcutSettingsSurface.controller.shortcuts.conflictOpen
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Row {
                spacing: Style.space(8)
                width: parent.width

                Rectangle {
                    border.color: Color.accent
                    border.width: 1
                    color: captureMouse.containsMouse ? shortcutSettingsSurface.controller.hoverBackground : "transparent"
                    height: Style.space(38)
                    radius: Style.space(8)
                    width: (parent.width - parent.spacing) / 2

                    Text {
                        anchors.centerIn: parent
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        text: shortcutSettingsSurface.controller.shortcuts.conflictOpen ? "Replace binding" : "Press new shortcut"
                    }
                    MouseArea {
                        id: captureMouse

                        anchors.fill: parent
                        enabled: !shortcutSettingsSurface.controller.shortcuts.processBusy
                        hoverEnabled: true

                        onClicked: {
                            if (shortcutSettingsSurface.controller.shortcuts.conflictOpen)
                                shortcutSettingsSurface.controller.shortcuts.applyCandidate(true);
                            else
                                shortcutSettingsSurface.controller.shortcuts.beginCapture();
                        }
                    }
                }
                Rectangle {
                    border.color: shortcutSettingsSurface.controller.panelBorder
                    border.width: 1
                    color: resetMouse.containsMouse ? shortcutSettingsSurface.controller.hoverBackground : "transparent"
                    height: Style.space(38)
                    radius: Style.space(8)
                    width: (parent.width - parent.spacing) / 2

                    Text {
                        anchors.centerIn: parent
                        color: shortcutSettingsSurface.controller.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        text: shortcutSettingsSurface.controller.shortcuts.conflictOpen ? "Cancel" : "Reset to Omarchy default"
                    }
                    MouseArea {
                        id: resetMouse

                        anchors.fill: parent
                        enabled: !shortcutSettingsSurface.controller.shortcuts.processBusy
                        hoverEnabled: true

                        onClicked: {
                            if (shortcutSettingsSurface.controller.shortcuts.conflictOpen) {
                                shortcutSettingsSurface.controller.shortcuts.conflictOpen = false;
                                shortcutSettingsSurface.controller.shortcuts.candidate = "";
                            } else {
                                shortcutSettingsSurface.controller.shortcuts.resetShortcut();
                            }
                        }
                    }
                }
            }
        }
        Text {
            id: shortcutFooterLabel

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(24)
            anchors.left: parent.left
            anchors.leftMargin: Style.space(24)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(24)
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            height: Style.space(18)
            horizontalAlignment: Text.AlignRight
            text: shortcutSettingsSurface.controller.shortcuts.captureActive ? "Press a shortcut · Esc cancel capture" : (shortcutSettingsSurface.controller.shortcuts.conflictOpen ? "Choose Replace or Cancel · Esc back to hosts" : "Esc back to hosts")
            verticalAlignment: Text.AlignVCenter
        }
    }
}
