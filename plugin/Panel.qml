import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property var hosts: []
  property string errorText: ""

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/lazydocker-host-picker.json"

  function open(payloadJson) {
    opened = true
    errorText = ""
    configFile.reload()
  }

  function close() {
    opened = false
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function")
      shell.hide((manifest && manifest.id) || "rafamedeiros.lazydocker-host-picker")
    else
      close()
  }

  function launch(host) {
    var dockerHost = String(host.dockerHost || "unix:///var/run/docker.sock")
    if (dockerHost.indexOf("ssh://") === 0) {
      var proxy = Quickshell.env("HOME") + "/.config/omarchy/plugins/rafamedeiros.lazydocker-host-picker/docker-ssh-proxy.py"
      Quickshell.execDetached([
        "omarchy-launch-tui", "--app-id=org.omarchy.lazydocker",
        "python3", proxy, dockerHost
      ])
    } else {
      Quickshell.execDetached(["omarchy-launch-docker-tui"])
    }
    dismiss()
  }

  function parseConfig(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (!data || !Array.isArray(data.hosts)) throw new Error("Expected a hosts array")
      var parsed = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      data.hosts.forEach(function(host) {
        if (!host || !host.id || !host.name || !host.dockerHost)
          throw new Error("Each host needs id, name, and dockerHost")
        parsed.push({id: String(host.id), name: String(host.name), dockerHost: String(host.dockerHost)})
      })
      hosts = parsed
      errorText = ""
    } catch (e) {
      hosts = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      errorText = "Host config error: " + e.message
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseConfig(text())
    onFileChanged: configFile.reload()
    onLoadFailed: {
      root.hosts = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      root.errorText = "Could not read " + root.configPath
    }
  }

  FloatingWindow {
    visible: root.opened
    title: "Docker Host Picker"
    color: "#172126"
    implicitWidth: 460
    implicitHeight: 520
    minimumSize: Qt.size(400, 320)


    Rectangle {
      anchors.fill: parent
      color: "#172126"

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(430, parent.width - 36)
        height: column.implicitHeight + 48
        radius: 18
        color: "#172126"
        border.color: "#43545a"
        border.width: 1

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: column
          anchors.fill: parent
          anchors.margins: 24
          spacing: 12

          Text {
            text: "DOCKER / HOST"
            color: "#a9c0c4"
            font.family: "monospace"
            font.pixelSize: 12
            font.letterSpacing: 2
          }
          Text {
            text: "Where are we going?"
            color: "#f1f3ec"
            font.family: "sans-serif"
            font.pixelSize: 25
            font.bold: true
          }
          Text {
            visible: root.errorText !== ""
            text: root.errorText
            color: "#ffb4a9"
            wrapMode: Text.WordWrap
            width: parent.width
          }

          Repeater {
            model: root.hosts
            delegate: Rectangle {
              required property var modelData
              width: column.width
              height: 58
              radius: 10
              color: rowMouse.containsMouse ? "#304047" : "#222f34"
              border.color: rowMouse.containsMouse ? "#b7d7d7" : "#3b4a4f"
              border.width: 1
              Row {
                x: 16
                y: 0
                width: parent.width - 30
                height: parent.height
                spacing: 12
                Text {
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.id === "local" ? "󰒍" : "󰣀"
                  color: "#b7d7d7"
                  font.pixelSize: 21
                }
                Text {
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  text: modelData.name
                  color: "#f1f3ec"
                  font.pixelSize: 16
                }
                Text {
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  text: "›"
                  color: "#9bb5b8"
                  font.pixelSize: 24
                }
              }
              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.launch(modelData)
              }
            }
          }
          Text {
            text: "Esc to close"
            color: "#829397"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
            width: parent.width
          }
        }
      }

      Item {
        anchors.fill: parent
        focus: root.opened
        Keys.onEscapePressed: root.dismiss()
      }
    }
  }
}
