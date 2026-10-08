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
  property bool addingHost: false
  property bool manageHosts: false
  property bool checkingNewHost: false
  property string checkingDraftId: ""
  property string checkingDraftName: ""
  property string checkingDraftEndpoint: ""
  property int nextDraftId: 1
  property bool pendingAddReturn: false
  property string pendingRemovalId: ""
  property bool checkingProxyLaunch: false
  property string pendingProxyDockerHost: ""
  property var proxyTestConfig: ({enabled: false})
  property bool proxyTestConfigLoaded: false
  property var requirementIssues: []
  readonly property bool showingRequirementIssues: requirementIssues.length > 0
  property int selectedIndex: 0
  property var hosts: []
  property var hostsBeforeWrite: []
  property string pendingWriteSuccess: ""
  property var hostStatuses: ({})
  property var viewHosts: []
  property string errorText: ""
  property bool notificationExpanded: false

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/lazydocker-host-picker.json"
  readonly property color panelBackground: Color.popups.background
  readonly property color panelForeground: Color.popups.text
  readonly property color panelBorder: Color.popups.border
  readonly property color hoverBackground: Color.menu.selectedBackground
  readonly property string notificationText: errorText !== "" ? errorText : (pendingAddReturn ? "Unsaved host drafts. Click again to discard and return." : (pendingRemovalId !== "" ? "Click remove again to confirm. Esc cancels." : (checkingNewHost ? "Testing Docker connection…" : successText)))
  readonly property bool notificationIsError: errorText !== "" || pendingAddReturn || pendingRemovalId !== ""
  readonly property var displayedHosts: manageHosts ? hosts : viewHosts
  onNotificationTextChanged: if (notificationText === "") notificationExpanded = false
  onOpenedChanged: if (opened) handlePickerOpened()

  function open(payloadJson) {
    addingHost = false
    hostDraftModel.clear()
    manageHosts = false
    pendingAddReturn = false
    pendingRemovalId = ""
    errorText = ""
    successText = ""
    requirementIssues = []
    notificationExpanded = false
    successTimer.stop()
    configFile.reload()
    opened = true
    handlePickerOpened()
  }

  function handlePickerOpened() {
    if (!opened || !proxyTestConfigLoaded) return
    if (proxyTestConfig.enabled === true) simulateProxyPreflight()
    else if (errorText.indexOf("Proxy test config error:") !== 0) checkProxyAvailability()
  }

  function close() {
    opened = false
    addingHost = false
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
      if (proxyTestConfig.enabled === true) {
        return
      }
      var proxy = Quickshell.env("HOME") + "/.config/omarchy/plugins/rafamedeiros.lazydocker-host-picker/docker-ssh-proxy-launcher"
      if (checkingProxyLaunch) return
      errorText = ""
      pendingProxyDockerHost = dockerHost
      checkingProxyLaunch = true
      proxyPreflight.command = [proxy, "--check"]
      proxyPreflight.running = true
    } else {
      Quickshell.execDetached([
        "omarchy-launch-tui", "--app-id=org.omarchy.lazydocker",
        "omarchy-launch-docker-tui"
      ])
    }
    if (dockerHost.indexOf("ssh://") !== 0) dismiss()
  }

  function launchRemoteDocker(dockerHost) {
    var proxy = Quickshell.env("HOME") + "/.config/omarchy/plugins/rafamedeiros.lazydocker-host-picker/docker-ssh-proxy-launcher"
    Quickshell.execDetached([
      "omarchy-launch-tui", "--app-id=org.omarchy.lazydocker",
      proxy, dockerHost
    ])
  }

  function checkProxyAvailability() {
    if (!opened || checkingProxyLaunch) return
    var proxy = Quickshell.env("HOME") + "/.config/omarchy/plugins/rafamedeiros.lazydocker-host-picker/docker-ssh-proxy-launcher"
    pendingProxyDockerHost = ""
    checkingProxyLaunch = true
    proxyPreflight.command = [proxy, "--check"]
    proxyPreflight.running = true
  }

  function simulateProxyPreflight() {
    var test = proxyTestConfig
    errorText = ""
    successText = ""
    var issues = []
    successTimer.stop()
    if (!(test.architecture === "x86_64" && test.bundledBinary === true) && test.goAvailable !== true)
      issues.push("Go is required to build the Docker SSH proxy on " + test.architecture + ".")
    if (test.sshAvailable === false)
      issues.push("OpenSSH is not installed.")
    if (test.lazydockerAvailable === false)
      issues.push("Lazydocker is not installed.")
    requirementIssues = issues
  }

  function parseProxyTestConfig(raw) {
    try {
      var test = JSON.parse(String(raw || "{}"))
      if (test.enabled !== true) {
        proxyTestConfig = {enabled: false}
        proxyTestConfigLoaded = true
        successText = ""
        return
      }
      if (typeof test.architecture !== "string" || test.architecture === "")
        throw new Error("architecture must be a non-empty string")
      if (typeof test.bundledBinary !== "boolean" || typeof test.goAvailable !== "boolean")
        throw new Error("bundledBinary and goAvailable must be true or false")
      if (test.sshAvailable !== undefined && typeof test.sshAvailable !== "boolean")
        throw new Error("sshAvailable must be true or false")
      if (test.lazydockerAvailable !== undefined && typeof test.lazydockerAvailable !== "boolean")
        throw new Error("lazydockerAvailable must be true or false")
      proxyTestConfig = test
      proxyTestConfigLoaded = true
    } catch (e) {
      proxyTestConfig = {enabled: false}
      proxyTestConfigLoaded = true
      if (opened) errorText = "Proxy test config error: " + e.message
    }
  }

  function parseConfig(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (!data || !Array.isArray(data.hosts)) throw new Error("Expected a hosts array")
      var parsed = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      data.hosts.forEach(function(host) {
        if (!host || !host.id || !host.name || !host.dockerHost)
          throw new Error("Each host needs id, name, and dockerHost")
        if (String(host.dockerHost).indexOf("ssh://") !== 0)
          throw new Error("Remote hosts must use an ssh:// Docker endpoint")
        parsed.push({id: String(host.id), name: String(host.name), dockerHost: String(host.dockerHost)})
      })
      hosts = parsed
      hostStatuses = ({})
      viewHosts = parsed.slice()
      selectedIndex = 0
      errorText = ""
      if (data.proxyTest !== undefined) {
        parseProxyTestConfig(JSON.stringify(data.proxyTest))
      } else {
        proxyTestConfig = {enabled: false}
        proxyTestConfigLoaded = true
      }
      if (opened) handlePickerOpened()
    } catch (e) {
      hosts = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      hostStatuses = ({})
      viewHosts = hosts.slice()
      errorText = "Host config error: " + e.message
    }
  }

  function statusColor(status) {
    if (status === "online") return Color.accent
    if (status === "unreachable") return Color.urgent
    return Color.muted
  }

  function statusDescription(status, version, detail) {
    if (status === "online")
      return "Online" + (version ? " - Docker " + version : "")
    if (status === "unreachable")
      return "Unreachable" + (detail ? " - " + detail : "")
    if (status === "checking") return "Checking connection"
    return "Connection status unknown"
  }

  function updateHostStatus(id, status, version, detail) {
    var next = Object.assign({}, hostStatuses)
    next[id] = {status: status, version: version, detail: detail}
    hostStatuses = next

    var visible = viewHosts.some(function(host) { return String(host.id) === String(id) })
    if (status === "unreachable" && visible) {
      viewHosts = viewHosts.filter(function(host) { return String(host.id) !== String(id) })
    } else if (status === "online" && !visible) {
      var host = hosts.find(function(entry) { return String(entry.id) === String(id) })
      if (host) viewHosts = viewHosts.concat([host])
    }
  }

  function rebuildViewHosts() {
    viewHosts = hosts.filter(function(host) {
      var state = hostStatuses[host.id]
      return host.id === "local" || !state || state.status !== "unreachable"
    })
  }

  function offlineHostCount() {
    var count = 0
    hosts.forEach(function(host) {
      var state = hostStatuses[host.id]
      if (host.id !== "local" && state && state.status === "unreachable") count++
    })
    return count
  }

  function hostAvailable(host) {
    if (!host || host.id === "local") return true
    return hostStatuses[host.id] && hostStatuses[host.id].status === "online"
  }

  function handleEditEscape() {
    var hasUnsavedEdits = false
    for (var i = 0; i < hostRepeater.count; i++) {
      var row = hostRepeater.itemAt(i)
      if (!row) continue
      if (row.savingEdit) {
        errorText = "Wait for the connection check to finish."
        return
      }
      if (row.editDirty) {
        row.editName = row.modelData.name
        row.editEndpoint = row.modelData.dockerHost
        hasUnsavedEdits = true
      }
    }
    if (hasUnsavedEdits) {
      errorText = ""
      successText = "Unsaved changes discarded"
      successTimer.restart()
    } else {
      returnToView()
    }
  }

  function normalizeEndpoint(raw) {
    var endpoint = String(raw || "").trim()
    if (/^[A-Za-z0-9_.-]+$/.test(endpoint)) endpoint = "ssh://" + endpoint
    return /^ssh:\/\/[^/\s?#]+$/.test(endpoint) ? endpoint : ""
  }

  function endpointInUse(endpoint, exceptId) {
    return hosts.some(function(host) {
      return host.id !== "local" && String(host.id) !== String(exceptId || "")
        && String(host.dockerHost).toLowerCase() === endpoint.toLowerCase()
    })
  }

  function updateRemoteHost(host, name, endpoint, version) {
    var remoteHosts = hosts.filter(function(entry) { return entry.id !== "local" })
      .map(function(entry) { return {id: entry.id, name: entry.name, dockerHost: entry.dockerHost} })
    var found = false
    for (var i = 0; i < remoteHosts.length; i++) {
      if (String(remoteHosts[i].id) === String(host.id)) {
        remoteHosts[i] = {id: host.id, name: name, dockerHost: endpoint}
        found = true
        break
      }
    }
    if (!found) {
      errorText = "That host is no longer in the list."
      return
    }
    persistRemoteHosts(remoteHosts, "Updated " + name)
    updateHostStatus(host.id, "online", version, "")
  }

  function beginManage() {
    manageHosts = true
    addingHost = false
    pendingAddReturn = false
    pendingRemovalId = ""
    errorText = ""
    successText = ""
  }

  function returnToView() {
    manageHosts = false
    addingHost = false
    hostDraftModel.clear()
    pendingAddReturn = false
    pendingRemovalId = ""
    errorText = ""
  }

  function requestReturnToView() {
    if (!addingHost) {
      returnToView()
    } else if (pendingAddReturn) {
      discardAllHostDrafts()
      returnToView()
    } else {
      errorText = ""
      pendingAddReturn = true
    }
  }

  function persistRemoteHosts(remoteHosts, successMessage) {
    hostsBeforeWrite = hosts.slice()
    hosts = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}].concat(remoteHosts)
    rebuildViewHosts()
    pendingWriteSuccess = successMessage
    var config = {hosts: remoteHosts}
    if (proxyTestConfig.enabled === true) config.proxyTest = proxyTestConfig
    configFile.setText(JSON.stringify(config, null, 2) + "\n")
  }

  function removeHost(host) {
    if (!host || host.id === "local") return
    var remoteHosts = hosts.filter(function(entry) { return entry.id !== "local" && String(entry.id) !== String(host.id) })
    pendingRemovalId = ""
    persistRemoteHosts(remoteHosts, "Removed " + host.name)
  }

  function appendHostDraft() {
    hostDraftModel.append({draftId: String(nextDraftId++), draftName: "", draftEndpoint: "", draftError: ""})
    addingHost = true
    pendingAddReturn = false
    errorText = ""
    Qt.callLater(function() {
      var row = draftRepeater.itemAt(draftRepeater.count - 1)
      if (row) row.focusName()
    })
  }

  function removeHostDraft(draftId, keepReturnConfirmation) {
    if (checkingNewHost && checkingDraftId === String(draftId)) {
      addHostCancelled = true
      addHostTimeout.stop()
      addHostProbe.running = false
    }
    for (var i = 0; i < hostDraftModel.count; i++) {
      if (String(hostDraftModel.get(i).draftId) === String(draftId)) {
        hostDraftModel.remove(i)
        break
      }
    }
    addingHost = hostDraftModel.count > 0
    if (!keepReturnConfirmation || hostDraftModel.count === 0) pendingAddReturn = false
    errorText = ""
  }

  function discardAllHostDrafts() {
    if (checkingNewHost) {
      addHostCancelled = true
      addHostTimeout.stop()
      addHostProbe.running = false
    }
    hostDraftModel.clear()
    addingHost = false
    pendingAddReturn = false
    errorText = ""
  }

  function handleAddEscape(draftId) {
    if (pendingAddReturn) {
      pendingAddReturn = false
      return
    }
    var id = draftId === undefined && hostDraftModel.count > 0
      ? hostDraftModel.get(hostDraftModel.count - 1).draftId : draftId
    if (id !== undefined) removeHostDraft(id)
  }

  function draftEndpointInUse(endpoint, exceptId) {
    for (var i = 0; i < draftRepeater.count; i++) {
      var row = draftRepeater.itemAt(i)
      if (row && String(row.draftId) !== String(exceptId)
          && normalizeEndpoint(row.draftEndpoint).toLowerCase() === endpoint.toLowerCase()) return true
    }
    return false
  }

  function addHost(draftRow) {
    if (checkingNewHost) {
      errorText = "Another host connection check is already running."
      return
    }
    var name = draftRow.draftName.trim()
    var endpoint = normalizeEndpoint(draftRow.draftEndpoint)
    if (!name) {
      errorText = "Enter a display name."
      draftRow.focusName()
      return
    }
    if (!endpoint) {
      errorText = "Use an SSH alias or endpoint, e.g. host or ssh://user@host."
      draftRow.focusEndpoint()
      return
    }
    if (endpointInUse(endpoint, "") || draftEndpointInUse(endpoint, draftRow.draftId)) {
      errorText = "That SSH endpoint is already configured in another host or draft."
      draftRow.focusEndpoint()
      return
    }
    hostDraftModel.setProperty(draftRow.index, "draftEndpoint", endpoint)
    hostDraftModel.setProperty(draftRow.index, "draftError", "")
    errorText = ""
    checkingDraftId = String(draftRow.draftId)
    checkingDraftName = name
    checkingDraftEndpoint = endpoint
    addHostCancelled = false
    addHostTimedOut = false
    checkingNewHost = true
    addHostTimeout.restart()
    addHostProbe.command = ["docker", "--host", endpoint, "info", "--format", "{{.ServerVersion}}"]
    addHostProbe.running = true
  }

  function saveRemoteHost(name, endpoint, version, draftId) {
    var remoteHosts = hosts.filter(function(host) { return host.id !== "local" })
    for (var i = 0; i < remoteHosts.length; i++) {
      if (String(remoteHosts[i].dockerHost).toLowerCase() === endpoint.toLowerCase()) {
        errorText = "That SSH endpoint is already configured."
        return
      }
    }
    var baseId = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    if (!baseId) baseId = "host"
    var hostId = baseId
    var suffix = 2
    while (remoteHosts.some(function(host) { return String(host.id) === hostId }))
      hostId = baseId + "-" + suffix++
    remoteHosts.push({id: hostId, name: name, dockerHost: endpoint})
    removeHostDraft(draftId, true)
    persistRemoteHosts(remoteHosts, "Added " + name)
  }

  ListModel { id: hostDraftModel }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.parseConfig(text())
    onFileChanged: configFile.reload()
    onLoadFailed: {
      root.hosts = [{id: "local", name: "This machine", dockerHost: "unix:///var/run/docker.sock"}]
      root.hostStatuses = ({})
      root.viewHosts = root.hosts.slice()
      root.proxyTestConfigLoaded = true
      root.errorText = "Could not read " + root.configPath
    }
    onSaved: {
      configFile.reload()
      if (root.pendingWriteSuccess !== "") {
        root.successText = root.pendingWriteSuccess
        root.pendingWriteSuccess = ""
        successTimer.restart()
      }
    }
    onSaveFailed: function(error) {
      root.hosts = root.hostsBeforeWrite
      root.rebuildViewHosts()
      root.pendingWriteSuccess = ""
      root.errorText = "Could not save host config: " + error
    }
  }

  property bool addHostTimedOut: false
  property bool addHostCancelled: false
  Process {
    id: proxyPreflight
    stdout: StdioCollector { id: proxyPreflightStdout; waitForEnd: true }
    stderr: StdioCollector { id: proxyPreflightStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.checkingProxyLaunch = false
      var dockerHost = root.pendingProxyDockerHost
      root.pendingProxyDockerHost = ""
      if (exitCode === 0) {
        root.requirementIssues = []
        if (dockerHost !== "") {
          root.launchRemoteDocker(dockerHost)
          root.dismiss()
        }
      } else {
        var detail = String(proxyPreflightStderr.text || proxyPreflightStdout.text || "").trim()
        if (root.opened) {
          var issues = detail.split(/\r?\n/).map(function(issue) { return issue.trim() }).filter(function(issue) { return issue !== "" })
          root.requirementIssues = issues.length > 0 ? issues : ["The SSH Docker proxy is not ready to launch."]
          root.errorText = ""
        }
      }
    }
  }
  Process {
    id: addHostProbe
    stdout: StdioCollector { id: addHostStdout; waitForEnd: true }
    stderr: StdioCollector { id: addHostStderr; waitForEnd: true }
    onExited: function(exitCode) {
      addHostTimeout.stop()
      root.checkingNewHost = false
      var draftId = root.checkingDraftId
      var name = root.checkingDraftName
      var endpoint = root.checkingDraftEndpoint
      root.checkingDraftId = ""
      if (root.addHostCancelled) {
        root.addHostCancelled = false
        return
      }
      if (root.addHostTimedOut) {
        root.addHostTimedOut = false
        return
      }
      if (exitCode === 0) {
        root.saveRemoteHost(name, endpoint, String(addHostStdout.text || "").trim(), draftId)
      } else {
        var detail = String(addHostStderr.text || "").trim().split("\n")[0] || "Could not connect to Docker at that SSH endpoint."
        root.errorText = detail
        for (var i = 0; i < draftRepeater.count; i++) {
          var row = draftRepeater.itemAt(i)
          if (row && String(row.draftId) === draftId) {
            hostDraftModel.setProperty(row.index, "draftError", detail)
            break
          }
        }
      }
    }
  }
  Timer {
    id: addHostTimeout
    interval: 8000
    onTriggered: {
      if (!addHostProbe.running) return
      root.addHostTimedOut = true
      root.errorText = "Connection timed out. Check the SSH target and try again."
      for (var i = 0; i < draftRepeater.count; i++) {
        var row = draftRepeater.itemAt(i)
        if (row && String(row.draftId) === root.checkingDraftId) {
          hostDraftModel.setProperty(row.index, "draftError", root.errorText)
          break
        }
      }
      addHostProbe.running = false
    }
  }
  property string successText: ""
  Timer { id: successTimer; interval: 3500; onTriggered: root.successText = "" }

  FloatingWindow {
    visible: root.opened
    title: "Docker Host Picker"
    color: root.panelBackground
    implicitWidth: 460
    implicitHeight: root.showingRequirementIssues ? requirementsSurface.requiredWindowHeight : 520
    minimumSize: Qt.size(400, 320)

    Rectangle {
      id: pickerSurface
      anchors.fill: parent
      color: root.panelBackground
      visible: !root.showingRequirementIssues

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(430, parent.width - Style.space(36))
        height: Math.min(column.implicitHeight + Style.space(48), parent.height - Style.space(48))
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(18)
        color: root.panelBackground
        border.color: root.panelBorder
        border.width: 1

        Column {
          id: column
          anchors.fill: parent
          anchors.margins: Style.space(24)
          spacing: Style.space(12)

          Row {
            id: headerRow
            width: parent.width
            height: Style.space(34)
            spacing: Style.space(6)
            Text {
              id: headerLabel
              width: parent.width - actionGroup.width - parent.spacing
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: root.manageHosts ? "MANAGE / HOSTS" : "DOCKER / HOST"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.letterSpacing: 2
              elide: Text.ElideRight
            }
            Row {
              id: actionGroup
              width: Style.space(74)
              height: parent.height
              spacing: Style.space(6)

              Rectangle {
                width: Style.space(34)
                height: parent.height
                radius: Style.space(7)
                opacity: root.manageHosts ? 1 : 0
                color: addMouse.containsMouse ? root.hoverBackground : "transparent"
                border.color: root.panelBorder
                border.width: 1
                Text {
                  anchors.centerIn: parent
                  text: "+"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                }
                MouseArea {
                  id: addMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: root.manageHosts
                  onClicked: root.appendHostDraft()
                }
              }
              Rectangle {
                id: modeButton
                width: Style.space(34)
                height: parent.height
                radius: Style.space(7)
                color: root.pendingAddReturn ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18) : (modeMouse.containsMouse ? root.hoverBackground : "transparent")
                border.color: root.pendingAddReturn ? Color.urgent : (root.manageHosts ? Color.accent : root.panelBorder)
                border.width: 1
                ToolTip.visible: modeMouse.containsMouse && !root.showingRequirementIssues
                ToolTip.text: root.pendingAddReturn ? "Click again to discard draft and return" : (root.manageHosts ? "Return to view" : "Edit hosts")
                ToolTip.delay: 450
                Text {
                  anchors.centerIn: parent
                  text: root.pendingAddReturn ? "!" : (root.manageHosts ? "󰍃" : "󰏫")
                  color: root.pendingAddReturn ? Color.urgent : (root.manageHosts ? Color.accent : root.panelForeground)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                }
                Rectangle {
                  visible: !root.manageHosts && root.offlineHostCount() > 0
                  width: Style.space(15)
                  height: width
                  radius: width / 2
                  anchors.right: parent.right
                  anchors.top: parent.top
                  color: Color.urgent
                  border.color: root.panelBackground
                  border.width: 1
                  Text {
                    anchors.centerIn: parent
                    text: root.offlineHostCount() > 9 ? "9+" : String(root.offlineHostCount())
                    color: root.panelBackground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
                MouseArea {
                  id: modeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: root.manageHosts || !root.checkingNewHost
                  onClicked: {
                    if (root.manageHosts) root.requestReturnToView()
                    else root.beginManage()
                  }
                }
              }
            }
          }
          Text {
            id: panelTitle
            width: parent.width
            text: root.manageHosts ? "Manage hosts" : "Where are we going?"
            color: root.panelForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Column {
            id: hostSection
            visible: !root.addingHost || root.manageHosts
            width: parent.width
            spacing: Style.space(8)

            Flickable {
              id: hostFlickable
              width: parent.width
              implicitHeight: hostRows.naturalHeight
              height: Math.min(implicitHeight, Math.max(0, card.parent.height - Style.space(96) - headerRow.height - panelTitle.implicitHeight - notificationToast.height - (footerLabel.visible ? footerLabel.implicitHeight : 0) - column.spacing * (footerLabel.visible ? 4 : 3) - hostSection.spacing))
              contentWidth: width
              contentHeight: hostRows.naturalHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              function ensureSelectionVisible() {
                var row = hostRepeater.itemAt(root.selectedIndex)
                if (!row) return
                if (row.y < contentY) contentY = row.y
                else if (row.y + row.height > contentY + height) contentY = row.y + row.height - height
              }
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              Connections {
                target: root
                function onSelectedIndexChanged() { hostFlickable.ensureSelectionVisible() }
              }
              Column {
                id: hostRows
                property int rowCount: root.displayedHosts.length + (root.manageHosts ? hostDraftModel.count : 0)
                property real naturalHeight: rowCount > 0 ? rowCount * Style.space(68) + (rowCount - 1) * spacing : 0
                width: parent.width
                height: naturalHeight
                spacing: Style.space(8)
              Repeater {
              id: hostRepeater
              model: root.displayedHosts
              delegate: Rectangle {
                id: hostRow
                required property var modelData
                required property int index
                property string status: "unknown"
                property string serverVersion: ""
                property string statusDetail: ""
                property bool timedOut: false
                property bool chosen: root.selectedIndex === index
                property bool hovered: rowHover.hovered
                property bool highlighted: chosen || hovered
                property bool editable: root.manageHosts && modelData.id !== "local"
                property bool editDirty: editName !== modelData.name || editEndpoint !== modelData.dockerHost
                property bool savingEdit: false
                property bool editTimedOut: false
                property string editName: modelData.name
                property string editEndpoint: modelData.dockerHost
                property bool removable: root.manageHosts && modelData.id !== "local"

                width: parent.width
                height: Style.space(68)
                radius: Style.space(10)
                opacity: modelData.id !== "local" && status !== "online" && !root.manageHosts ? 0.58 : 1
                color: hostRow.chosen
                  ? Style.selectedFillFor(Color.foreground, Color.accent, Color.urgent)
                  : (hostRow.hovered
                    ? Style.hoverFillFor(Color.foreground, Color.accent, Color.urgent)
                    : Style.normalFillFor(Color.foreground, Color.accent, Color.urgent))
                border.color: hostRow.chosen
                  ? Style.selectedBorderFor(Color.foreground, Color.accent, Color.urgent)
                  : (hostRow.hovered
                    ? Style.hoverBorderFor(Color.foreground, Color.accent, Color.urgent)
                    : Style.normalBorderFor(Color.foreground, Color.accent, Color.urgent))
                border.width: hostRow.highlighted
                  ? Math.max(1, Style.selectedBorderWidth)
                  : Math.max(1, Style.normalBorderWidth)

                HoverHandler { id: rowHover }

                function saveHostEdits() {
                  var nextName = editName.trim()
                  var nextEndpoint = root.normalizeEndpoint(editEndpoint)
                  if (!nextName) {
                    root.errorText = "Enter a host name."
                    editNameField.forceActiveFocus()
                    return
                  }
                  if (!nextEndpoint) {
                    root.errorText = "Use an SSH alias or endpoint, e.g. host or ssh://user@host."
                    editEndpointField.forceActiveFocus()
                    return
                  }
                  if (root.endpointInUse(nextEndpoint, modelData.id)) {
                    root.errorText = "That SSH endpoint is already assigned to another host."
                    editEndpointField.forceActiveFocus()
                    return
                  }
                  editEndpoint = nextEndpoint
                  root.errorText = ""
                  savingEdit = true
                  editTimeout.restart()
                  editProbe.command = ["docker", "--host", nextEndpoint, "info", "--format", "{{.ServerVersion}}"]
                  editProbe.running = true
                }

                Component.onCompleted: {
                  editName = modelData.name
                  editEndpoint = modelData.dockerHost
                  status = "checking"
                  root.updateHostStatus(modelData.id, "checking", "", "")
                  probe.command = modelData.id === "local"
                    ? ["docker", "--host", "unix:///var/run/docker.sock", "info", "--format", "{{.ServerVersion}}"]
                    : ["docker", "--host", modelData.dockerHost, "info", "--format", "{{.ServerVersion}}"]
                  probe.running = true
                }

                Process {
                  id: probe
                  stdout: StdioCollector { id: probeStdout; waitForEnd: true }
                  stderr: StdioCollector { id: probeStderr; waitForEnd: true }
                  onExited: function(exitCode) {
                    probeTimeout.stop()
                    if (hostRow.timedOut) return
                    hostRow.status = exitCode === 0 ? "online" : "unreachable"
                    hostRow.serverVersion = String(probeStdout.text || "").trim()
                    hostRow.statusDetail = exitCode === 0 ? "" : String(probeStderr.text || "").trim().split("\n")[0]
                    root.updateHostStatus(hostRow.modelData.id, hostRow.status, hostRow.serverVersion, hostRow.statusDetail)
                  }
                }
                Timer {
                  id: probeTimeout
                  interval: 6000
                  running: probe.running
                  onTriggered: {
                    hostRow.timedOut = true
                    hostRow.status = "unreachable"
                    hostRow.statusDetail = "Check timed out"
                    root.updateHostStatus(hostRow.modelData.id, hostRow.status, "", hostRow.statusDetail)
                    probe.running = false
                  }
                }

                Process {
                  id: editProbe
                  stdout: StdioCollector { id: editStdout; waitForEnd: true }
                  stderr: StdioCollector { id: editStderr; waitForEnd: true }
                  onExited: function(exitCode) {
                    editTimeout.stop()
                    hostRow.savingEdit = false
                    if (hostRow.editTimedOut) {
                      hostRow.editTimedOut = false
                      return
                    }
                    if (exitCode === 0) {
                      root.updateRemoteHost(hostRow.modelData, hostRow.editName.trim(), hostRow.editEndpoint, String(editStdout.text || "").trim())
                    } else {
                      var detail = String(editStderr.text || "").trim().split("\n")[0]
                      root.errorText = detail || "Could not connect to Docker at that SSH endpoint."
                    }
                  }
                }
                Timer {
                  id: editTimeout
                  interval: 8000
                  running: editProbe.running
                  onTriggered: {
                    hostRow.editTimedOut = true
                    hostRow.savingEdit = false
                    root.errorText = "Connection timed out. Check the SSH target and try again."
                    editProbe.running = false
                  }
                }

                Row {
                  id: hostContent
                  z: 1
                  x: Style.space(14)
                  y: 0
                  width: parent.width - Style.space(28)
                  height: parent.height
                  spacing: Style.space(10)

                  Rectangle {
                    id: rowStatusDot
                    width: Style.space(10)
                    height: width
                    radius: width / 2
                    y: (parent.height - height) / 2
                    color: root.statusColor(hostRow.status)
                    ToolTip.visible: (hostRow.hovered || hostRow.chosen) && !root.showingRequirementIssues
                    ToolTip.text: root.statusDescription(hostRow.status, hostRow.serverVersion, hostRow.statusDetail)
                    ToolTip.delay: 450
                  }
                  Column {
                    id: viewHostInfo
                    visible: !hostRow.editable
                    width: parent.width - rowStatusDot.width - actionRail.width - parent.spacing * 2
                    height: Style.space(50)
                    y: (parent.height - height) / 2
                    spacing: Style.space(2)
                    Row {
                      width: parent.width
                      height: Style.space(26)
                      Text {
                        width: parent.width
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: hostRow.modelData.name
                        color: root.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        elide: Text.ElideRight
                      }
                    }
                    Text {
                      width: parent.width
                      height: Style.space(22)
                      verticalAlignment: Text.AlignVCenter
                      text: hostRow.modelData.id === "local" ? "Local Docker socket" : hostRow.modelData.dockerHost
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                  Column {
                    id: editHostInfo
                    visible: hostRow.editable
                    width: parent.width - rowStatusDot.width - actionRail.width - parent.spacing * 2
                    height: Style.space(50)
                    y: (parent.height - height) / 2
                    spacing: Style.space(2)
                    Row {
                      width: parent.width
                      height: Style.space(26)
                      TextField {
                        id: editNameField
                        width: parent.width
                        height: parent.height
                        text: hostRow.editName
                        placeholderText: "Name"
                        color: root.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        selectByMouse: true
                        enabled: !hostRow.savingEdit && !root.checkingNewHost
                        onTextChanged: hostRow.editName = text
                        onAccepted: editEndpointField.forceActiveFocus()
                        Keys.onEscapePressed: root.handleEditEscape()
                        background: Rectangle {
                          color: root.panelBackground
                          radius: Style.space(7)
                          border.color: editNameField.activeFocus ? Color.accent : root.panelBorder
                          border.width: 1
                        }
                      }
                    }
                    Row {
                      width: parent.width
                      height: Style.space(22)
                      spacing: Style.space(6)
                      TextField {
                        id: editEndpointField
                        width: parent.width
                        height: parent.height
                        text: hostRow.editEndpoint
                        placeholderText: "SSH connection"
                        color: root.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        selectByMouse: true
                        enabled: !hostRow.savingEdit && !root.checkingNewHost
                        onTextChanged: hostRow.editEndpoint = text
                        onAccepted: hostRow.saveHostEdits()
                        Keys.onEscapePressed: root.handleEditEscape()
                        background: Rectangle {
                          color: root.panelBackground
                          radius: Style.space(7)
                          border.color: editEndpointField.activeFocus ? Color.accent : root.panelBorder
                          border.width: 1
                        }
                      }
                    }
                  }
                  Item {
                    id: actionRail
                    width: hostRow.editable ? Style.space(74) : 0
                    height: parent.height
                    Row {
                      y: (parent.height - height) / 2
                      width: parent.width
                      height: Style.space(34)
                      spacing: Style.space(6)
                      Rectangle {
                        id: editSaveButton
                        width: Style.space(34)
                        height: width
                        visible: hostRow.editable
                        opacity: hostRow.editDirty || hostRow.savingEdit ? 1 : 0
                        radius: Style.space(7)
                        color: editSaveMouse.containsMouse ? root.hoverBackground : "transparent"
                        border.color: Color.accent
                        border.width: 1
                        ToolTip.visible: hostRow.editDirty && editSaveMouse.containsMouse && !root.showingRequirementIssues
                        ToolTip.text: "Test connection and save"
                        ToolTip.delay: 450
                        Text {
                          anchors.centerIn: parent
                          text: hostRow.savingEdit ? "↻" : "󰆓"
                          color: hostRow.savingEdit ? Color.muted : Color.accent
                          font.family: Style.font.family
                          font.pixelSize: Style.font.subtitle
                          NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                            running: hostRow.savingEdit
                          }
                        }
                        MouseArea {
                          id: editSaveMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          enabled: hostRow.editable && hostRow.editDirty && !hostRow.savingEdit && !root.checkingNewHost
                          onClicked: hostRow.saveHostEdits()
                        }
                      }
                      Rectangle {
                        id: removeButton
                        visible: hostRow.removable
                        width: Style.space(34)
                        height: width
                        radius: Style.space(7)
                        color: root.pendingRemovalId === hostRow.modelData.id || removeMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18) : "transparent"
                        border.color: Color.urgent
                        border.width: 1
                        ToolTip.visible: removeMouse.containsMouse && !root.showingRequirementIssues
                        ToolTip.text: root.pendingRemovalId === hostRow.modelData.id ? "Click again to confirm removal" : "Remove host"
                        ToolTip.delay: 450
                        Text {
                          anchors.centerIn: parent
                          text: root.pendingRemovalId === hostRow.modelData.id ? "!" : "󰆴"
                          color: Color.urgent
                          font.family: Style.font.family
                          font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                          id: removeMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          enabled: hostRow.removable
                          onClicked: {
                            if (root.pendingRemovalId === hostRow.modelData.id)
                              root.removeHost(hostRow.modelData)
                            else
                              root.pendingRemovalId = hostRow.modelData.id
                          }
                        }
                      }
                    }
                  }
                }
                MouseArea {
                  id: rowMouse
                  z: root.manageHosts ? 0 : 2
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: !root.manageHosts && (hostRow.modelData.id === "local" || hostRow.status === "online")
                  onEntered: root.selectedIndex = hostRow.index
                  onClicked: root.launch(hostRow.modelData)
                }
              }
            }

            Repeater {
              id: draftRepeater
              model: hostDraftModel
              delegate: Rectangle {
                id: draftRow
                required property int index
                required property string draftId
                required property string draftName
                required property string draftEndpoint
                required property string draftError
                property bool isSaving: root.checkingNewHost && root.checkingDraftId === String(draftId)
                width: parent.width
                height: Style.space(68)
                radius: Style.space(10)
                color: root.hoverBackground
                border.color: draftRow.isSaving ? Color.accent : root.panelBorder
                border.width: 1

                function focusName() { draftNameField.forceActiveFocus() }
                function focusEndpoint() { draftEndpointField.forceActiveFocus() }

                Row {
                  x: Style.space(14)
                  y: 0
                  width: parent.width - Style.space(28)
                  height: parent.height
                  spacing: Style.space(10)
                  Rectangle {
                    width: Style.space(10)
                    height: width
                    radius: width / 2
                    y: (parent.height - height) / 2
                    color: draftRow.draftError !== "" ? root.statusColor("unreachable") : (draftRow.isSaving ? root.statusColor("checking") : root.statusColor("unknown"))
                  }
                  Column {
                    width: parent.width - Style.space(10) - draftActions.width - parent.spacing * 2
                    height: Style.space(50)
                    y: (parent.height - height) / 2
                    spacing: Style.space(2)
                    Row {
                      width: parent.width
                      height: Style.space(26)
                      TextField {
                        id: draftNameField
                        width: parent.width
                        height: parent.height
                        text: draftRow.draftName
                        placeholderText: "Name"
                        color: root.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        selectByMouse: true
                        enabled: !draftRow.isSaving
                        onTextChanged: hostDraftModel.setProperty(draftRow.index, "draftName", text)
                        onAccepted: draftEndpointField.forceActiveFocus()
                        Keys.onEscapePressed: root.handleAddEscape(draftRow.draftId)
                        background: Rectangle {
                          color: root.panelBackground
                          radius: Style.space(7)
                          border.color: draftNameField.activeFocus ? Color.accent : root.panelBorder
                          border.width: 1
                        }
                      }
                    }
                    Row {
                      width: parent.width
                      height: Style.space(22)
                      TextField {
                        id: draftEndpointField
                        width: parent.width
                        height: parent.height
                        text: draftRow.draftEndpoint
                        placeholderText: "SSH alias / ssh://user@host"
                        color: root.panelForeground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        selectByMouse: true
                        enabled: !draftRow.isSaving
                        onTextChanged: hostDraftModel.setProperty(draftRow.index, "draftEndpoint", text)
                        onAccepted: root.addHost(draftRow)
                        Keys.onEscapePressed: root.handleAddEscape(draftRow.draftId)
                        background: Rectangle {
                          color: root.panelBackground
                          radius: Style.space(7)
                          border.color: draftEndpointField.activeFocus ? Color.accent : root.panelBorder
                          border.width: 1
                        }
                      }
                    }
                  }
                  Item {
                    id: draftActions
                    width: Style.space(74)
                    height: parent.height
                    Row {
                      y: (parent.height - height) / 2
                      width: parent.width
                      height: Style.space(34)
                      spacing: Style.space(6)
                      Rectangle {
                        width: Style.space(34)
                        height: width
                        radius: Style.space(7)
                        color: draftSaveMouse.containsMouse ? root.hoverBackground : root.panelBackground
                        border.color: Color.accent
                        border.width: 1
                        ToolTip.visible: draftSaveMouse.containsMouse && !root.showingRequirementIssues
                        ToolTip.text: "Test connection and save host"
                        ToolTip.delay: 450
                        Text {
                          anchors.centerIn: parent
                          text: draftRow.isSaving ? "↻" : "󰆓"
                          color: draftRow.isSaving ? Color.muted : Color.accent
                          font.family: Style.font.family
                          font.pixelSize: Style.font.subtitle
                          NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                            running: draftRow.isSaving
                          }
                        }
                        MouseArea {
                          id: draftSaveMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          enabled: !root.checkingNewHost
                          onClicked: root.addHost(draftRow)
                        }
                      }
                      Rectangle {
                        width: Style.space(34)
                        height: width
                        radius: Style.space(7)
                        color: draftRemoveMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.18) : "transparent"
                        border.color: Color.urgent
                        border.width: 1
                        ToolTip.visible: draftRemoveMouse.containsMouse && !root.showingRequirementIssues
                        ToolTip.text: "Discard this draft"
                        ToolTip.delay: 450
                        Text {
                          anchors.centerIn: parent
                          text: "󰆴"
                          color: Color.urgent
                          font.family: Style.font.family
                          font.pixelSize: Style.font.subtitle
                        }
                        MouseArea {
                          id: draftRemoveMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: root.removeHostDraft(draftRow.draftId)
                        }
                      }
                    }
                  }
                }
              }
            }
              }
            }

            Rectangle {
              id: notificationToast
              width: parent.width
              height: Style.space(42)
              radius: Style.space(8)
              color: root.notificationText !== "" ? Color.popups.background : "transparent"
              border.color: root.notificationText !== "" ? (root.notificationIsError ? Color.urgent : Color.accent) : "transparent"
              border.width: root.notificationText !== "" ? 1 : 0

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)
                Text {
                  id: notificationIcon
                  width: Style.space(16)
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: root.notificationIsError ? "!" : (root.checkingNewHost ? "↻" : (root.successText !== "" ? "✓" : ""))
                  color: root.notificationIsError ? Color.urgent : Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: root.checkingNewHost
                  }
                }
                Text {
                  width: parent.width - notificationIcon.width - detailsNotification.width - closeNotification.width - parent.spacing * 3
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  text: root.notificationText
                  color: root.notificationIsError ? Color.urgent : root.panelForeground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
                Text {
                  id: detailsNotification
                  visible: root.notificationText.length > 45
                  width: visible ? Style.space(44) : 0
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: "Details"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  MouseArea { anchors.fill: parent; onClicked: root.notificationExpanded = true }
                }
                Text {
                  id: closeNotification
                  visible: root.notificationText !== "" && !root.checkingNewHost
                  width: Style.space(34)
                  height: Style.space(34)
                  y: (parent.height - height) / 2
                  verticalAlignment: Text.AlignVCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: "×"
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      root.errorText = ""
                      root.successText = ""
                      root.pendingRemovalId = ""
                      root.pendingAddReturn = false
                      successTimer.stop()
                    }
                  }
                }
              }
            }
          }

          Text {
            id: footerLabel
            text: root.pendingAddReturn ? "Esc keep drafts · Click ! to discard all & return" : (root.addingHost ? "Enter test & save · Esc discard draft" : (root.manageHosts ? "Enter test & save · Esc discard edits / return" : "↑ / ↓ select · Enter open · E edit · Esc close"))
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            width: parent.width
          }
        }
      }

      Item {
        anchors.fill: parent
        focus: root.opened && !root.addingHost
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.addingHost) {
              root.handleAddEscape()
            } else if (root.pendingRemovalId !== "") {
              root.pendingRemovalId = ""
            } else if (root.manageHosts) {
              root.handleEditEscape()
            } else {
              root.dismiss()
            }
            event.accepted = true
          } else if (!root.addingHost && event.key === Qt.Key_Down) {
            root.selectedIndex = Math.min(root.displayedHosts.length, root.selectedIndex + 1)
            event.accepted = true
          } else if (!root.addingHost && event.key === Qt.Key_Up) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
            event.accepted = true
          } else if (!root.addingHost && event.key === Qt.Key_E) {
            if (root.manageHosts) root.requestReturnToView()
            else root.beginManage()
            event.accepted = true
          } else if (!root.addingHost && event.key === Qt.Key_Return) {
            if (root.manageHosts) {
              event.accepted = true
            } else if (root.selectedIndex < root.displayedHosts.length) {
              var selectedHost = root.displayedHosts[root.selectedIndex]
              if (root.hostAvailable(selectedHost)) root.launch(selectedHost)
              else root.errorText = "That host is not online yet."
              event.accepted = true
            } else {
              root.manageHosts = true
              root.errorText = ""
              event.accepted = true
            }
          }
        }
      }

      Rectangle {
        visible: root.notificationExpanded && root.notificationText !== ""
        z: 100
        anchors.fill: parent
        color: Color.menu.scrim
        MouseArea {
          anchors.fill: parent
          onClicked: root.notificationExpanded = false
        }
        Rectangle {
          id: notificationDetailCard
          z: 1
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(32), Style.space(520))
          height: Math.min(parent.height - Style.space(32), detailColumn.implicitHeight + Style.space(32))
          radius: Style.space(12)
          color: Color.popups.background
          border.color: root.notificationIsError ? Color.urgent : Color.accent
          border.width: 1
          MouseArea { anchors.fill: parent; onClicked: {} }
          Column {
            id: detailColumn
            anchors.fill: parent
            anchors.margins: Style.space(16)
            spacing: Style.space(10)
            Text {
              width: parent.width
              text: root.notificationIsError ? "Error details" : "Notification details"
              color: root.notificationIsError ? Color.urgent : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            ScrollView {
              id: detailScroll
              width: parent.width
              height: Math.min(detailText.implicitHeight, Style.space(240))
              clip: true
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
              Text {
                id: detailText
                width: detailScroll.availableWidth
                text: root.notificationText
                color: root.panelForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                textFormat: Text.PlainText
              }
            }
            Rectangle {
              width: parent.width
              height: Style.space(34)
              radius: Style.space(7)
              color: closeDetailsMouse.containsMouse ? root.hoverBackground : "transparent"
              border.color: root.panelBorder
              border.width: 1
              Text { anchors.centerIn: parent; text: "Close"; color: root.panelForeground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
              MouseArea {
                id: closeDetailsMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.notificationExpanded = false
              }
            }
          }
        }
      }

    }

    Rectangle {
      id: requirementsSurface
      property real requiredWindowHeight: Math.max(Style.space(320), Math.min(Style.space(640), issueColumn.implicitHeight + Style.space(96)))
      anchors.fill: parent
      color: root.panelBackground
      visible: root.showingRequirementIssues

      Rectangle {
        id: requirementCard
        anchors.centerIn: parent
        width: Math.min(430, parent.width - Style.space(36))
        height: Math.min(parent.height - Style.space(48), Math.max(Style.space(256), issueColumn.implicitHeight + Style.space(48)))
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(18)
        color: root.panelBackground
        border.color: root.panelBorder
        border.width: 1

        Column {
          id: issueColumn
          anchors.fill: parent
          anchors.margins: Style.space(24)
          spacing: Style.space(14)

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              text: "!"
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              width: parent.width - Style.space(32)
              text: "Requirements missing"
              color: root.panelForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              wrapMode: Text.Wrap
            }
          }

          Column {
            id: issueList
            width: parent.width
            spacing: Style.space(10)
            Repeater {
              model: root.requirementIssues
              delegate: Item {
                required property string modelData
                width: issueList.width
                height: Math.max(issueBullet.implicitHeight, issueText.implicitHeight)
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text {
                    id: issueBullet
                    text: "•"
                    color: Color.urgent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    id: issueText
                    width: parent.width - issueBullet.implicitWidth - parent.spacing
                    text: modelData
                    color: root.panelForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  }
                }
              }
            }
          }

          Item { width: 1; height: Style.space(4) }

          Rectangle {
            width: parent.width
            height: Style.space(38)
            radius: Style.space(8)
            color: closeRequirementsMouse.containsMouse ? root.hoverBackground : "transparent"
            border.color: root.panelBorder
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "Close"
              color: root.panelForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            MouseArea {
              id: closeRequirementsMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.dismiss()
            }
          }
        }
      }

      Item {
        anchors.fill: parent
        focus: root.opened && root.showingRequirementIssues
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
          }
        }
      }
    }
  }
}
