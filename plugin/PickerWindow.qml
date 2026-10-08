import QtQuick
import Quickshell
import "components"
import qs.Commons

FloatingWindow {
    id: pickerWindow

    property var controller
    property alias draftRowsRepeater: hostSection.draftRowsRepeater
    property alias hostRowsRepeater: hostSection.hostRowsRepeater

    function availableHostSectionHeight() {
        var footerHeight = footerLabel.visible ? footerLabel.implicitHeight : 0;
        var fixedHeight = Style.space(96) + pickerHeader.headerRowHeight + pickerHeader.titleHeight + footerHeight + column.spacing * 3 + hostSection.spacing;
        return Math.max(0, pickerWindow.height - fixedHeight);
    }
    function footerHintText() {
        if (pickerWindow.controller.pendingAddReturn)
            return "Esc keep drafts · Click ! to discard all & return";
        if (pickerWindow.controller.addingHost)
            return "Enter test & save · Esc discard draft";
        if (pickerWindow.controller.manageHosts)
            return "Enter test & save · Esc discard edits / return";
        return "↑ / ↓ select · Enter open · E edit · Esc close";
    }
    function preferredCardHeight() {
        var contentHeight = column.implicitHeight + footerLabel.implicitHeight + column.spacing + Style.space(48);
        var availableHeight = pickerWindow.height - Style.space(48);
        return Math.min(contentHeight, availableHeight);
    }

    color: pickerWindow.controller.panelBackground
    implicitHeight: pickerWindow.controller.showingRequirementIssues ? requirementsSurface.requiredWindowHeight : 520
    implicitWidth: 460
    minimumSize: Qt.size(400, 320)
    title: "Docker Host Picker"
    visible: pickerWindow.controller.opened

    Rectangle {
        id: pickerSurface

        anchors.fill: parent
        color: pickerWindow.controller.panelBackground
        visible: !pickerWindow.controller.showingRequirementIssues && !pickerWindow.controller.shortcuts.settingsOpen

        Rectangle {
            id: card

            anchors.centerIn: parent
            border.color: pickerWindow.controller.panelBorder
            border.width: 1
            color: pickerWindow.controller.panelBackground
            height: pickerWindow.preferredCardHeight()
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(18)
            width: Math.min(430, parent.width - Style.space(36))

            Column {
                id: column

                anchors.bottomMargin: Style.space(48)
                anchors.fill: parent
                anchors.margins: Style.space(24)
                spacing: Style.space(12)

                PickerHeader {
                    id: pickerHeader

                    controller: pickerWindow.controller
                    width: parent.width
                }
                PickerHostSection {
                    id: hostSection

                    availableHeight: pickerWindow.availableHostSectionHeight()
                    controller: pickerWindow.controller
                    width: parent.width
                }
            }
            Text {
                id: footerLabel

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
                text: pickerWindow.footerHintText()
                verticalAlignment: Text.AlignVCenter
            }
        }
        PickerKeyboardHandler {
            controller: pickerWindow.controller
        }
        NotificationDetails {
            controller: pickerWindow.controller
        }
    }
    RequirementsView {
        id: requirementsSurface

        controller: pickerWindow.controller
    }
    ShortcutSettings {
        id: shortcutSettingsSurface

        cardHeight: card.height
        cardRadius: card.radius
        cardWidth: card.width
        controller: pickerWindow.controller
    }
}
