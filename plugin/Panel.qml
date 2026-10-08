import QtQuick
import Quickshell
import "components"
import qs.Commons

Item {
    id: root

    property alias addingHost: hostManager.addingHost
    property alias checkingDraftId: hostManager.checkingDraftId
    property alias checkingNewHost: hostManager.checkingNewHost
    property alias checkingProxyLaunch: dockerLauncher.checkingProxyLaunch
    readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/lazydocker-host-picker.json"
    readonly property var displayedHosts: manageHosts ? hosts : viewHosts
    property string errorText: ""
    property alias hostDrafts: hostManager.drafts
    property alias hostManagerApi: hostManager
    property alias hostStatuses: hostManager.hostStatuses
    property alias hosts: hostConfig.hosts
    readonly property color hoverBackground: Color.menu.selectedBackground
    property alias manageHosts: hostManager.manageHosts
    property var manifest: null
    property bool notificationExpanded: false
    readonly property bool notificationIsError: errorText !== "" || pendingAddReturn || pendingRemovalId !== ""
    readonly property string notificationText: errorText !== "" ? errorText : (pendingAddReturn ? "Unsaved host drafts. Click again to discard and return." : (pendingRemovalId !== "" ? "Click remove again to confirm. Esc cancels." : (checkingNewHost ? "Testing Docker connection…" : successText)))
    property bool opened: false
    readonly property color panelBackground: Color.popups.background
    readonly property color panelBorder: Color.popups.border
    readonly property color panelForeground: Color.popups.text
    property alias pendingAddReturn: hostManager.pendingAddReturn
    property alias pendingRemovalId: hostManager.pendingRemovalId
    property alias proxyTestConfig: hostConfig.proxyTestConfig
    property alias proxyTestConfigLoaded: hostConfig.proxyTestConfigLoaded
    property var requirementIssues: []
    property int selectedIndex: 0
    property var shell: null
    property alias shortcuts: shortcutManager
    readonly property bool showingRequirementIssues: requirementIssues.length > 0
    property string successText: ""
    property alias viewHosts: hostManager.viewHosts

    function clearNotification() {
        errorText = "";
        successText = "";
        pendingRemovalId = "";
        pendingAddReturn = false;
        successTimer.stop();
    }
    function close() {
        shortcutManager.closeSettings();
        opened = false;
        addingHost = false;
    }
    function dismiss() {
        if (shell && typeof shell.hide === "function")
            shell.hide((manifest && manifest.id) || "rafamedeiros.lazydocker-host-picker");
        else
            close();
    }
    function handlePickerOpened() {
        if (!opened || !proxyTestConfigLoaded)
            return;

        if (proxyTestConfig.enabled === true) {
            errorText = "";
            successText = "";
            successTimer.stop();
            dockerLauncher.simulatePreflight(proxyTestConfig);
        } else if (errorText.indexOf("Proxy test config error:") !== 0) {
            dockerLauncher.checkAvailability();
        }
    }
    function launch(host) {
        dockerLauncher.launch(host, proxyTestConfig.enabled === true);
    }
    function open(payloadJson) {
        hostManager.resetForOpen();
        errorText = "";
        successText = "";
        selectedIndex = 0;
        requirementIssues = [];
        notificationExpanded = false;
        successTimer.stop();
        hostConfig.reload();
        opened = true;
        shortcutManager.refreshStatus();
        handlePickerOpened();
    }
    function showSuccess(message) {
        successText = message;
        successTimer.restart();
    }

    onNotificationTextChanged: {
        if (notificationText === "")
            notificationExpanded = false;
    }
    onOpenedChanged: {
        if (opened)
            handlePickerOpened();
    }

    Timer {
        id: successTimer

        interval: 3500

        onTriggered: root.successText = ""
    }
    HostConfigStore {
        id: hostConfig

        configPath: root.configPath

        onConfigurationFailed: function (message) {
            hostManager.configurationLoaded();
            root.selectedIndex = 0;
            root.errorText = message;
        }
        onConfigurationLoaded: {
            hostManager.configurationLoaded();
            root.selectedIndex = 0;
            root.errorText = hostConfig.configurationError;
            root.handlePickerOpened();
        }
        onSaveFailed: function (message) {
            hostManager.rebuildViewHosts();
            root.errorText = message;
        }
        onSaveSucceeded: function (message) {
            root.showSuccess(message);
        }
    }
    HostManager {
        id: hostManager

        configStore: hostConfig
        panel: root
        pickerWindow: pickerUi
    }
    DockerLauncher {
        id: dockerLauncher

        panel: root

        onLaunched: root.dismiss()
        onRequirementsChanged: function (issues) {
            root.requirementIssues = issues;
            root.errorText = "";
        }
    }
    ShortcutController {
        id: shortcutManager

        captureWindow: pickerUi

        onSuccess: function (message) {
            root.showSuccess(message);
        }
    }
    PickerWindow {
        id: pickerUi

        controller: root
    }
}
