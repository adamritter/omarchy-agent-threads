// Purpose: Implements the Local Open Code Server provider integration boundary.
import QtQuick
import Quickshell.Io

Item {
  id: root
  required property var provider
  readonly property alias running: serverProcess.running

  function start() { serverProcess.running = true }
  function stop() {
    restartTimer.stop()
    serverProcess.running = false
  }

  Process {
    id: serverProcess
    command: [
      root.provider.openCodeServerHelperPath,
      root.provider.openCodeAuthFile,
      43962
    ]
    onExited: {
      if (!root.provider.enabled || root.provider.controller.shuttingDown
          || root.provider.providerType !== "opencode") return
      root.provider.serverRestartAttempts++
      if (root.provider.serverRestartAttempts < 3) restartTimer.restart()
      else root.provider.host = Object.assign({}, root.provider.host, {
        loading: false,
        error: "OpenCode server could not start"
      })
    }
  }

  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: if (root.provider.enabled && !root.provider.controller.shuttingDown
        && root.provider.providerType === "opencode") root.start()
  }

  Component.onDestruction: stop()
}
