pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "components"
import qs.Commons

Column {
    id: hostSection

    property real availableHeight: 0
    property var controller
    property alias draftRowsRepeater: draftRepeater
    readonly property bool hasNotification: hostSection.controller.notificationText !== ""
    property alias hostRowsRepeater: hostRepeater
    readonly property color notificationBorderColor: {
        if (!hostSection.hasNotification)
            return "transparent";
        return hostSection.controller.notificationIsError ? Color.urgent : Color.accent;
    }
    readonly property bool notificationHasDetails: hostSection.controller.notificationText.length > 45
    readonly property color notificationIconColor: hostSection.controller.notificationIsError ? Color.urgent : Color.accent
    readonly property string notificationIconText: {
        if (hostSection.controller.notificationIsError)
            return "!";
        if (hostSection.controller.checkingNewHost)
            return "↻";
        return hostSection.controller.successText !== "" ? "✓" : "";
    }
    readonly property color notificationTextColor: hostSection.controller.notificationIsError ? Color.urgent : hostSection.controller.panelForeground

    function listViewportHeight() {
        var maximumRowsHeight = Style.space(68) * 3 + Style.space(16);
        var spaceAboveToast = Math.max(0, hostSection.availableHeight - notificationToast.height);
        return Math.min(maximumRowsHeight, spaceAboveToast);
    }

    spacing: Style.space(8)
    visible: !hostSection.controller.addingHost || hostSection.controller.manageHosts
    width: parent.width

    Flickable {
        id: hostFlickable

        function ensureSelectionVisible() {
            var row = hostRepeater.itemAt(hostSection.controller.selectedIndex);
            if (!row)
                return;

            if (row.y < contentY)
                contentY = row.y;
            else if (row.y + row.height > contentY + height)
                contentY = row.y + row.height - height;
        }

        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: hostRows.naturalHeight
        contentWidth: width
        height: implicitHeight
        // Keep the panel height stable while asynchronous host probes update row status.
        implicitHeight: hostSection.listViewportHeight()
        width: parent.width

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Connections {
            function onSelectedIndexChanged() {
                hostFlickable.ensureSelectionVisible();
            }

            target: hostSection.controller
        }
        Column {
            id: hostRows

            property int draftRowCount: hostSection.controller.manageHosts ? hostSection.controller.hostDrafts.count : 0
            property real naturalHeight: rowCount * Style.space(68) + Math.max(0, rowCount - 1) * spacing
            property int rowCount: savedRowCount + draftRowCount
            property int savedRowCount: hostSection.controller.displayedHosts.length

            height: naturalHeight
            spacing: Style.space(8)
            width: parent.width

            Repeater {
                id: hostRepeater

                model: hostSection.controller.displayedHosts

                delegate: HostRow {
                    controller: hostSection.controller
                }
            }
            Repeater {
                id: draftRepeater

                model: hostSection.controller.hostDrafts

                delegate: HostDraftRow {
                    controller: hostSection.controller
                }
            }
        }
    }
    Rectangle {
        id: notificationToast

        border.color: hostSection.notificationBorderColor
        border.width: hostSection.hasNotification ? 1 : 0
        color: hostSection.hasNotification ? Color.popups.background : "transparent"
        height: Style.space(42)
        radius: Style.space(8)
        width: parent.width

        Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
                id: notificationIcon

                color: hostSection.notificationIconColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                text: hostSection.notificationIconText
                verticalAlignment: Text.AlignVCenter
                width: Style.space(16)

                NumberAnimation on rotation {
                    duration: 800
                    from: 0
                    loops: Animation.Infinite
                    running: hostSection.controller.checkingNewHost
                    to: 360
                }
            }
            Text {
                color: hostSection.notificationTextColor
                elide: Text.ElideRight
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                height: parent.height
                text: hostSection.controller.notificationText
                verticalAlignment: Text.AlignVCenter
                width: parent.width - notificationIcon.width - detailsNotification.width - closeNotification.width - parent.spacing * 3
            }
            Text {
                id: detailsNotification

                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                text: "Details"
                verticalAlignment: Text.AlignVCenter
                visible: hostSection.notificationHasDetails
                width: visible ? Style.space(44) : 0

                MouseArea {
                    anchors.fill: parent

                    onClicked: hostSection.controller.notificationExpanded = true
                }
            }
            Text {
                id: closeNotification

                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                height: Style.space(34)
                horizontalAlignment: Text.AlignHCenter
                text: "×"
                verticalAlignment: Text.AlignVCenter
                visible: hostSection.hasNotification && !hostSection.controller.checkingNewHost
                width: Style.space(34)
                y: (parent.height - height) / 2

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        hostSection.controller.clearNotification();
                    }
                }
            }
        }
    }
}
