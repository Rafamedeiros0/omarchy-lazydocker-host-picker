import QtQuick

Item {
    id: keyboardHandler

    property var controller

    anchors.fill: parent
    focus: keyboardHandler.controller.opened && !keyboardHandler.controller.addingHost

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            if (keyboardHandler.controller.shortcuts.settingsOpen)
                keyboardHandler.controller.shortcuts.closeSettings();
            else if (keyboardHandler.controller.addingHost)
                keyboardHandler.controller.hostManagerApi.handleAddEscape();
            else if (keyboardHandler.controller.pendingRemovalId !== "")
                keyboardHandler.controller.pendingRemovalId = "";
            else if (keyboardHandler.controller.manageHosts)
                keyboardHandler.controller.hostManagerApi.handleEditEscape();
            else
                keyboardHandler.controller.dismiss();
            event.accepted = true;
        } else if (!keyboardHandler.controller.addingHost && event.key === Qt.Key_Down) {
            keyboardHandler.controller.selectedIndex = Math.min(keyboardHandler.controller.displayedHosts.length, keyboardHandler.controller.selectedIndex + 1);
            event.accepted = true;
        } else if (!keyboardHandler.controller.addingHost && event.key === Qt.Key_Up) {
            keyboardHandler.controller.selectedIndex = Math.max(0, keyboardHandler.controller.selectedIndex - 1);
            event.accepted = true;
        } else if (!keyboardHandler.controller.addingHost && event.key === Qt.Key_E) {
            if (keyboardHandler.controller.manageHosts)
                keyboardHandler.controller.hostManagerApi.requestReturnToView();
            else
                keyboardHandler.controller.hostManagerApi.beginManage();
            event.accepted = true;
        } else if (!keyboardHandler.controller.addingHost && event.key === Qt.Key_Return) {
            if (keyboardHandler.controller.manageHosts) {
                event.accepted = true;
            } else if (keyboardHandler.controller.selectedIndex < keyboardHandler.controller.displayedHosts.length) {
                var selectedHost = keyboardHandler.controller.displayedHosts[keyboardHandler.controller.selectedIndex];
                if (keyboardHandler.controller.hostManagerApi.hostAvailable(selectedHost))
                    keyboardHandler.controller.launch(selectedHost);
                else
                    keyboardHandler.controller.errorText = "That host is not online yet.";
                event.accepted = true;
            } else {
                keyboardHandler.controller.manageHosts = true;
                keyboardHandler.controller.errorText = "";
                event.accepted = true;
            }
        }
    }
}
