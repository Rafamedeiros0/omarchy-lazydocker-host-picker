pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Rectangle {
    id: requirementsSurface

    property var controller
    property real requiredWindowHeight: Math.max(Style.space(320), Math.min(Style.space(640), issueColumn.implicitHeight + Style.space(96)))

    anchors.fill: parent
    color: requirementsSurface.controller.panelBackground
    visible: requirementsSurface.controller.showingRequirementIssues

    Rectangle {
        id: requirementCard

        anchors.centerIn: parent
        border.color: requirementsSurface.controller.panelBorder
        border.width: 1
        color: requirementsSurface.controller.panelBackground
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
                    color: requirementsSurface.controller.panelForeground
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
                    model: requirementsSurface.controller.requirementIssues

                    delegate: Item {
                        id: requirementIssue

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

                                color: requirementsSurface.controller.panelForeground
                                font.family: Style.font.family
                                font.pixelSize: Style.font.body
                                text: requirementIssue.modelData
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
                border.color: requirementsSurface.controller.panelBorder
                border.width: 1
                color: closeRequirementsMouse.containsMouse ? requirementsSurface.controller.hoverBackground : "transparent"
                height: Style.space(38)
                radius: Style.space(8)
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: requirementsSurface.controller.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: "Close"
                }
                MouseArea {
                    id: closeRequirementsMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: requirementsSurface.controller.dismiss()
                }
            }
        }
    }
    Item {
        anchors.fill: parent
        focus: requirementsSurface.controller.opened && requirementsSurface.controller.showingRequirementIssues

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                requirementsSurface.controller.dismiss();
                event.accepted = true;
            }
        }
    }
}
