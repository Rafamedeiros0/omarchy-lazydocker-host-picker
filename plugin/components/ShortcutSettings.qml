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
    visible: controller.shortcuts.settingsOpen && controller.opened
    z: 200

    Connections {
        function onCaptureReady() {
            captureKeys.forceActiveFocus();
        }

        target: controller.shortcuts
    }
    Rectangle {
        id: shortcutSettingsCard

        anchors.centerIn: parent
        border.color: controller.panelBorder
        border.width: 1
        color: controller.panelBackground
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
                    color: settingsBackMouse.containsMouse ? controller.hoverBackground : "transparent"
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
                            controller.shortcuts.closeSettings();
                        }
                    }
                }
            }
            Text {
                color: controller.panelForeground
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
                border.color: controller.panelBorder
                border.width: 1
                color: controller.hoverBackground
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

                        color: controller.shortcuts.current !== "" ? Color.accent : Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        height: parent.height
                        text: controller.shortcuts.current !== "" ? controller.shortcuts.current : "None"
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Text {
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: controller.shortcuts.error
                visible: controller.shortcuts.error !== ""
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Item {
                height: Style.space(66)
                visible: controller.shortcuts.captureActive
                width: parent.width

                Rectangle {
                    anchors.fill: parent
                    border.color: controller.shortcuts.inhibitorReady ? Color.accent : Color.urgent
                    border.width: 1
                    color: controller.hoverBackground
                    radius: Style.space(8)
                }
                Text {
                    anchors.centerIn: parent
                    color: controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    horizontalAlignment: Text.AlignHCenter
                    text: controller.shortcuts.inhibitorReady ? "Press a combination, e.g. Super + Shift + K" : "Preparing safe shortcut capture…"
                    width: parent.width - Style.space(20)
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
                Item {
                    id: captureKeys

                    anchors.fill: parent
                    focus: controller.shortcuts.captureActive && controller.shortcuts.inhibitorReady

                    Keys.onPressed: function (event) {
                        event.accepted = true;
                        if (event.key === Qt.Key_Escape) {
                            controller.shortcuts.cancelCapture();
                            return;
                        }
                        var combo = controller.shortcuts.shortcutFromEvent(event);
                        if (combo !== "") {
                            controller.shortcuts.cancelCapture();
                            controller.shortcuts.submitCandidate(combo);
                        } else if (event.key !== Qt.Key_Shift && event.key !== Qt.Key_Control && event.key !== Qt.Key_Alt && event.key !== Qt.Key_Meta) {
                            controller.shortcuts.cancelCapture();
                            controller.shortcuts.error = "Use a modifier with a supported letter, number, function, or navigation key.";
                        }
                    }
                }
            }
            Text {
                color: Color.urgent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: "That combination is already used by " + controller.shortcuts.conflicts.map(function (item) {
                    return item.description;
                }).join(", ") + ". Replace it? The previous binding will return when you reset or change the picker shortcut."
                visible: controller.shortcuts.conflictOpen
                width: parent.width
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Row {
                spacing: Style.space(8)
                width: parent.width

                Rectangle {
                    border.color: Color.accent
                    border.width: 1
                    color: captureMouse.containsMouse ? controller.hoverBackground : "transparent"
                    height: Style.space(38)
                    radius: Style.space(8)
                    width: (parent.width - parent.spacing) / 2

                    Text {
                        anchors.centerIn: parent
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        text: controller.shortcuts.conflictOpen ? "Replace binding" : "Press new shortcut"
                    }
                    MouseArea {
                        id: captureMouse

                        anchors.fill: parent
                        enabled: !controller.shortcuts.processBusy
                        hoverEnabled: true

                        onClicked: {
                            if (controller.shortcuts.conflictOpen)
                                controller.shortcuts.applyCandidate(true);
                            else
                                controller.shortcuts.beginCapture();
                        }
                    }
                }
                Rectangle {
                    border.color: controller.panelBorder
                    border.width: 1
                    color: resetMouse.containsMouse ? controller.hoverBackground : "transparent"
                    height: Style.space(38)
                    radius: Style.space(8)
                    width: (parent.width - parent.spacing) / 2

                    Text {
                        anchors.centerIn: parent
                        color: controller.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        text: controller.shortcuts.conflictOpen ? "Cancel" : "Reset to Omarchy default"
                    }
                    MouseArea {
                        id: resetMouse

                        anchors.fill: parent
                        enabled: !controller.shortcuts.processBusy
                        hoverEnabled: true

                        onClicked: {
                            if (controller.shortcuts.conflictOpen) {
                                controller.shortcuts.conflictOpen = false;
                                controller.shortcuts.candidate = "";
                            } else {
                                controller.shortcuts.resetShortcut();
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
            text: controller.shortcuts.captureActive ? "Press a shortcut · Esc cancel capture" : (controller.shortcuts.conflictOpen ? "Choose Replace or Cancel · Esc back to hosts" : "Esc back to hosts")
            verticalAlignment: Text.AlignVCenter
        }
    }
}
