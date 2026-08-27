import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var provider
  required property var controller
  property string loginHostId: ""
  property bool loginRunning: false
  property string loginStderrText: ""

  readonly property string loginHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-claude-remote-login").toString().replace(/^file:\/\//, "")

  function validHost(hostId) {
    var configured = provider.configuredRemoteById(hostId)
    return configured && provider.providerTypeForEntry(configured) === "claude"
      && String(configured.type || "ssh") === "ssh"
  }

  function login(hostId) {
    var id = String(hostId || "")
    if (!validHost(id)) {
      controller.launchError = "Claude sign-in is only available for an SSH Claude remote"
      return false
    }
    if (controller.shuttingDown || loginProcess.running) return false

    controller.launchError = ""
    loginHostId = id
    loginRunning = true
    loginStderrText = ""
    loginProcess.command = [controller.streamGuardPath, "--",
      loginHelperPath, provider.configPath, id]
    loginProcess.running = true
    return true
  }

  Process {
    id: loginProcess
    running: false

    onExited: function(exitCode) {
      var hostId = root.loginHostId
      root.loginRunning = false
      root.loginHostId = ""
      if (exitCode !== 0) {
        root.controller.launchError = root.loginStderrText.trim()
          || "Could not open the remote Claude sign-in terminal"
        return
      }
      root.provider.refresh(hostId)
    }

    stderr: SplitParser {
      onRead: function(line) {
        root.loginStderrText = (root.loginStderrText
          + String(line || "") + "\n").slice(-30000)
      }
    }
  }

  Component.onDestruction: {
    loginProcess.running = false
  }
}
