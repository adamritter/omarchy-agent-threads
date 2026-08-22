import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var provider
  required property var controller
  property string installHostId: ""
  property bool installRunning: false
  property string installMessage: ""
  property string loginHostId: ""
  property bool loginRunning: false

  readonly property string installHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-claude-remote-install").toString().replace(/^file:\/\//, "")
  readonly property string loginHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-claude-remote-login").toString().replace(/^file:\/\//, "")

  function validHost(hostId) {
    var configured = provider.configuredRemoteById(hostId)
    return configured && provider.providerTypeForEntry(configured) === "claude"
      && String(configured.type || "ssh") === "ssh"
  }

  function install(hostId) {
    var id = String(hostId || "")
    if (!validHost(id)) {
      controller.launchError = "Claude can only be installed on an SSH Claude remote"
      return false
    }
    if (controller.shuttingDown || installProcess.running) return false

    controller.launchError = ""
    installHostId = id
    installRunning = true
    installMessage = "Installing Claude…"
    provider.updateHost(id, { loading: false, error: installMessage })
    installProcess.command = [installHelperPath, provider.configPath, id]
    installProcess.running = true
    return true
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
    loginProcess.command = [loginHelperPath, provider.configPath, id]
    loginProcess.running = true
    return true
  }

  function busy(hostId) {
    var id = String(hostId || "")
    return (installProcess.running && installHostId === id)
      || (loginProcess.running && loginHostId === id)
  }

  function verificationComplete(hostId) {
    if (String(hostId || "") !== installHostId) return
    installHostId = ""
    installMessage = ""
  }

  Process {
    id: installProcess
    running: false

    onExited: function(exitCode) {
      var hostId = root.installHostId
      root.installRunning = false
      if (exitCode !== 0) {
        root.installMessage = installStderr.text.trim() || "Claude installation failed"
        root.provider.updateHost(hostId, {
          available: false,
          loading: false,
          error: root.installMessage
        })
        root.installHostId = ""
        return
      }

      var outputLines = installStdout.text.trim().split(/\r?\n/)
      var version = outputLines.length > 0 ? outputLines[outputLines.length - 1] : ""
      root.installMessage = "Claude installed, verifying…"
        + (version !== "" ? " · " + version : "")
      root.provider.updateHost(hostId, { loading: true, error: root.installMessage })
      var queue = root.provider.queryQueue.slice()
      if (queue.indexOf(hostId) < 0) queue.push(hostId)
      root.provider.queryQueue = queue
      root.provider.startNextQuery()
    }

    stdout: StdioCollector { id: installStdout; waitForEnd: true }
    stderr: StdioCollector { id: installStderr; waitForEnd: true }
  }

  Process {
    id: loginProcess
    running: false

    onExited: function(exitCode) {
      var hostId = root.loginHostId
      root.loginRunning = false
      root.loginHostId = ""
      if (exitCode !== 0) {
        root.controller.launchError = loginStderr.text.trim()
          || "Could not open the remote Claude sign-in terminal"
        return
      }
      root.provider.refresh(hostId)
    }

    stderr: StdioCollector { id: loginStderr; waitForEnd: true }
  }

  Component.onDestruction: {
    installProcess.running = false
    loginProcess.running = false
  }
}
