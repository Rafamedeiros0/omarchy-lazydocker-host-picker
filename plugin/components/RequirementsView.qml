import QtQuick
import QtQuick.Controls
import qs.Commons

Rectangle {
    id: requirementsSurface

    property var controller
    property real requiredWindowHeight: Math.max(Style.space(320), Math.min(Style.space(640), issueColumn.implicitHeight + Style.space(96)))

    anchors.fill: parent
    color: controller.panelBackground
    visible: controller.showingRequirementIssues

    Rectangle {
        id: requirementCard

        anchors.centerIn: parent
        border.color: controller.panelBorder
        border.width: 1
        color: controller.panelBackground
        height: Math.min(parent.height - Style.space(48), Math.max(Style.space(256), issueColumn.implicitHeight + Style.space(48)))
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(18)
        width: Math.min(430, parent.width - Style.space(36))

        Column {
            id: issueColumn

            anchors.fill: parent
            anchors.margins: Style.space(24)
            spacing: Style.space(14)

            Row {
                spacing: Style.space(10)
                width: parent.width

                Text {
                    color: Color.urgent
                    font.bold: true
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    text: "!"
                }
                Text {
                    color: controller.panelForeground
                    font.bold: true
                    font.family: Style.font.family
                    font.pixelSize: Style.font.title
                    text: "Requirements missing"
                    width: parent.width - Style.space(32)
                    wrapMode: Text.Wrap
                }
            }
            Column {
                id: issueList

                spacing: Style.space(10)
                width: parent.width

                Repeater {
                    model: controller.requirementIssues

                    delegate: Item {
                        required property string modelData

                        height: Math.max(issueBullet.implicitHeight, issueText.implicitHeight)
                        width: issueList.width

                        Row {
                            spacing: Style.space(8)
                            width: parent.width

                            Text {
                                id: issueBullet

                                color: Color.urgent
                                font.family: Style.font.family
                                font.pixelSize: Style.font.body
                                text: "•"
                            }
                            Text {
                                id: issueText

                                color: controller.panelForeground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.body
                                text: modelData
                                width: parent.width - issueBullet.implicitWidth - parent.spacing
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }
                        }
                    }
                }
            }
            Item {
                height: Style.space(4)
                width: 1
            }
            Rectangle {
                border.color: controller.panelBorder
                border.width: 1
                color: closeRequirementsMouse.containsMouse ? controller.hoverBackground : "transparent"
                height: Style.space(38)
                radius: Style.space(8)
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: "Close"
                }
                MouseArea {
                    id: closeRequirementsMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: controller.dismiss()
                }
            }
        }
    }
    Item {
        anchors.fill: parent
        focus: controller.opened && controller.showingRequirementIssues

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                controller.dismiss();
                event.accepted = true;
            }
        }
    }
}
