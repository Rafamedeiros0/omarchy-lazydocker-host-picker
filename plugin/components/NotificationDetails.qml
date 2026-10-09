import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
    id: notificationDetails

    property var controller

    anchors.fill: parent
    color: Color.menu.scrim
    visible: notificationDetails.controller.notificationExpanded && notificationDetails.controller.notificationText !== ""
    z: 100

    MouseArea {
        anchors.fill: parent

        onClicked: notificationDetails.controller.notificationExpanded = false
    }
    Rectangle {
        id: notificationDetailCard

        anchors.centerIn: parent
        border.color: notificationDetails.controller.notificationIsError ? Color.urgent : Color.accent
        border.width: 1
        color: Color.popups.background
        height: Math.min(parent.height - Style.space(32), detailColumn.implicitHeight + Style.space(32))
        radius: Style.space(12)
        width: Math.min(parent.width - Style.space(32), Style.space(520))
        z: 1

        MouseArea {
            anchors.fill: parent

            onClicked: {}
        }
        Column {
            id: detailColumn

            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(10)

            Text {
                color: notificationDetails.controller.notificationIsError ? Color.urgent : Color.accent
                font.bold: true
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                text: notificationDetails.controller.notificationIsError ? "Error details" : "Notification details"
                width: parent.width
            }
            ScrollView {
                id: detailScroll

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                clip: true
                height: Math.min(detailText.implicitHeight, Style.space(240))
                width: parent.width

                Text {
                    id: detailText

                    color: notificationDetails.controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: notificationDetails.controller.notificationText
                    textFormat: Text.PlainText
                    width: detailScroll.availableWidth
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }
            Rectangle {
                border.color: notificationDetails.controller.panelBorder
                border.width: 1
                color: closeDetailsMouse.containsMouse ? notificationDetails.controller.hoverBackground : "transparent"
                height: Style.space(34)
                radius: Style.space(7)
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: notificationDetails.controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: "Close"
                }
                MouseArea {
                    id: closeDetailsMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: notificationDetails.controller.notificationExpanded = false
                }
            }
        }
    }
}
