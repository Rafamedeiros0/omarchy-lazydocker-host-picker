import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property string candidate: ""
    property bool captureActive: false
    property var captureWindow: null
    property bool conflictOpen: false
    property var conflicts: []
    property string current: ""
    property string error: ""
    property bool inhibitorReady: false
    readonly property string integrationPath: Quickshell.env("HOME") + "/.local/bin/lazydocker-picker-integration"
    property string last: "SUPER + SHIFT + D"
    property string operation: ""
    readonly property bool processBusy: shortcutProcess.running
    property bool settingsOpen: false

    signal captureReady
    signal success(string message)

    function applyCandidate(replaceConflict) {
        run("set", replaceConflict ? [candidate, "--replace"] : [candidate]);
    }
    function beginCapture() {
        error = "";
        conflictOpen = false;
        candidate = "";
        captureActive = true;
        inhibitorReady = false;
        shortcutInhibitor.enabled = true;
        captureTimeout.restart();
    }
    function cancelCapture() {
        captureTimeout.stop();
        shortcutInhibitor.enabled = false;
        captureActive = false;
        inhibitorReady = false;
    }
    function closeSettings() {
        cancelCapture();
        settingsOpen = false;
    }
    function openSettings() {
        settingsOpen = true;
        error = "";
        refreshStatus();
    }
    function refreshStatus() {
        run("status", []);
    }
    function resetShortcut() {
        run("reset", []);
    }
    function run(action, args) {
        if (shortcutProcess.running)
            return;

        operation = action;
        shortcutProcess.command = [integrationPath, action].concat(args || []);
        shortcutProcess.running = true;
    }
    function shortcutFromEvent(event) {
        var modifiers = [];
        if (event.modifiers & Qt.MetaModifier)
            modifiers.push("SUPER");

        if (event.modifiers & Qt.ControlModifier)
            modifiers.push("CTRL");

        if (event.modifiers & Qt.AltModifier)
            modifiers.push("ALT");

        if (event.modifiers & Qt.ShiftModifier)
            modifiers.push("SHIFT");

        var key = event.key;
        var name = "";
        if (key >= Qt.Key_A && key <= Qt.Key_Z) {
            name = String.fromCharCode(key);
        } else if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            name = String.fromCharCode(key);
        } else {
            var names = ({});
            names[Qt.Key_Space] = "SPACE";
            names[Qt.Key_Tab] = "TAB";
            names[Qt.Key_Escape] = "ESCAPE";
            names[Qt.Key_Return] = "RETURN";
            names[Qt.Key_Enter] = "RETURN";
            names[Qt.Key_Backspace] = "BACKSPACE";
            names[Qt.Key_Delete] = "DELETE";
            names[Qt.Key_Insert] = "INSERT";
            names[Qt.Key_Home] = "HOME";
            names[Qt.Key_End] = "END";
            names[Qt.Key_PageUp] = "PAGEUP";
            names[Qt.Key_PageDown] = "PAGEDOWN";
            names[Qt.Key_Up] = "UP";
            names[Qt.Key_Down] = "DOWN";
            names[Qt.Key_Left] = "LEFT";
            names[Qt.Key_Right] = "RIGHT";
            names[Qt.Key_Comma] = "COMMA";
            names[Qt.Key_Period] = "PERIOD";
            names[Qt.Key_Slash] = "SLASH";
            names[Qt.Key_Semicolon] = "SEMICOLON";
            names[Qt.Key_Apostrophe] = "APOSTROPHE";
            names[Qt.Key_BracketLeft] = "BRACKETLEFT";
            names[Qt.Key_BracketRight] = "BRACKETRIGHT";
            names[Qt.Key_Minus] = "MINUS";
            names[Qt.Key_Equal] = "EQUAL";
            names[Qt.Key_Backslash] = "BACKSLASH";
            names[Qt.Key_QuoteLeft] = "GRAVE";
            if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
                name = "F" + (key - Qt.Key_F1 + 1);
            else
                name = names[key] || "";
        }
        if (modifiers.length === 0 || name === "")
            return "";

        return modifiers.join(" + ") + " + " + name;
    }
    function submitCandidate(value) {
        candidate = value;
        run("check", [value]);
    }

    Timer {
        id: captureTimeout

        interval: 1200

        onTriggered: {
            if (root.captureActive && !shortcutInhibitor.active) {
                root.cancelCapture();
                root.error = "Hyprland could not reserve shortcuts for capture. Try again after closing other shortcut-capturing apps.";
            }
        }
    }
    ShortcutInhibitor {
        id: shortcutInhibitor

        enabled: false
        window: root.captureWindow

        onActiveChanged: {
            if (active && root.captureActive) {
                root.inhibitorReady = true;
                captureTimeout.stop();
                root.captureReady();
            }
        }
        onCancelled: {
            if (root.captureActive) {
                root.cancelCapture();
                root.error = "Shortcut capture was cancelled by the compositor.";
            }
        }
    }
    Process {
        id: shortcutProcess

        stderr: StdioCollector {
            id: shortcutStderr

            waitForEnd: true
        }
        stdout: StdioCollector {
            id: shortcutStdout

            waitForEnd: true
        }

        onExited: function (exitCode) {
            var result = {};
            try {
                result = JSON.parse(String(shortcutStdout.text || "{}"));
            } catch (e) {
                result = {
                    "ok": false,
                    "error": String(shortcutStderr.text || e.message)
                };
            }
            if (exitCode !== 0 || result.ok === false) {
                root.error = result.error || String(shortcutStderr.text || "Shortcut update failed.").trim();
                root.conflictOpen = false;
                if (root.operation === "set")
                    root.cancelCapture();

                return;
            }
            if (root.operation === "status") {
                root.current = result.shortcut || "";
                root.last = result.lastShortcut || "SUPER + SHIFT + D";
            } else if (root.operation === "check") {
                root.conflicts = result.conflicts || [];
                if (root.conflicts.length > 0)
                    root.conflictOpen = true;
                else
                    root.applyCandidate(false);
            } else if (root.operation === "set") {
                root.current = result.shortcut || "";
                root.last = result.lastShortcut || result.shortcut || "SUPER + SHIFT + D";
                root.error = "";
                root.conflictOpen = false;
                root.cancelCapture();
                root.settingsOpen = false;
                root.success("Shortcut updated.");
            } else if (root.operation === "reset") {
                root.current = "";
                root.last = result.lastShortcut || root.last;
                root.error = "";
                root.conflictOpen = false;
                root.cancelCapture();
                root.settingsOpen = false;
                root.success("Omarchy's default Docker shortcut restored.");
            }
        }
    }
}
