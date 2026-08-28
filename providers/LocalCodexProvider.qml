import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "../logic/ActionLogic.js" as ActionLogic

Item {
  id: root

  required property var controller

  property bool activeThreadRefreshQueued: false

  readonly property string terminalHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-terminal-open").toString().replace(/^file:\/\//, "")
  readonly property string activeThreadHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-active-thread").toString().replace(/^file:\/\//, "")
  readonly property string launchLogPath:
    controller.stateHome + "/omarchy/agent-threads-launch.log"

  ThreadLaunchCoordinator { id: launchCoordinator }

  function guarded(command) {
    return [controller.streamGuardPath, "--"].concat(command)
  }

  function openThread(thread, cwdOverride, source) {
    if (!thread || !thread.id || openProcess.running) return false
    var threadId = String(thread.id)
    var requestId = controller.mutations.beginThreadLaunch(
      threadId, source || "local-terminal")
    if (requestId === 0) return false
    if (launchCoordinator.focusCachedThread(threadId, "")) {
      controller.mutations.observeActiveThread(
        threadId, "cached-local-codex-window")
      return true
    }
    launchCoordinator.state.trackOpen(requestId, threadId, "")
    openProcess.command = guarded(ActionLogic.localCodexTerminalCommand(
      terminalHelperPath,
      threadId,
      String(cwdOverride || controller.threadActions.projectPathForThread(thread)
        || controller.backendHomePath),
      controller.settings.effectiveModel(),
      controller.settings.effectiveEffort(),
      controller.codexServiceTier))
    openProcess.running = true
    return true
  }

  function newThread(projectPath) {
    var path = String(projectPath || "")
    if (path === "" || newProjectProcess.running) return
    controller.launchingProjectPath = path
    controller.launchError = ""
    launchCoordinator.state.beginPending(controller.threads, path, "", 20)
    newProjectProcess.command = guarded(ActionLogic.localCodexTerminalCommand(
      terminalHelperPath, "", path,
      controller.settings.effectiveModel(), controller.settings.effectiveEffort(),
      controller.codexServiceTier))
    newProjectProcess.running = true
  }

  function clearPendingNew() {
    launchCoordinator.state.clearPending()
    controller.launchingProjectPath = ""
    newThreadResolveTimer.stop()
  }

  function resolvePendingNew() {
    if (!launchCoordinator.state.pending) return
    var previousId = launchCoordinator.state.pendingThreadId
    var threadId = launchCoordinator.state.discoverPendingThread(controller.threads)
    if (threadId !== "" && previousId === "") {
      controller.mutations.observeActiveThread(threadId, "new-local-codex-thread")
    }
    if (threadId === "" || launchCoordinator.state.pendingWindowAddress === "") return
    launchCoordinator.map(
      threadId, launchCoordinator.state.pendingWindowAddress, "",
      launchCoordinator.state.pendingServerUrl)
    clearPendingNew()
  }

  function refreshActiveThread() {
    if (activeThreadProcess.running) {
      activeThreadRefreshQueued = true
      return
    }
    activeThreadRefreshQueued = false
    activeThreadProcess.running = true
  }

  Process {
    id: openProcess
    running: false
    onExited: function(exitCode) {
      var requestId = launchCoordinator.state.openRequestId
      var threadId = launchCoordinator.state.openThreadId
      launchCoordinator.state.clearOpen()
      if (exitCode !== 0) controller.mutations.failThreadLaunch(
        requestId, openStderr.text.trim() || "Could not open the Codex thread")
      else {
        var result = launchCoordinator.parseOutput(openStdout.text)
        launchCoordinator.map(threadId, result.address, "", "")
        controller.mutations.confirmThreadLaunch(requestId, "")
      }
      root.refreshActiveThread()
    }
    stdout: StdioCollector { id: openStdout; waitForEnd: true }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }

  Process {
    id: activeThreadProcess
    command: root.guarded([root.activeThreadHelperPath])
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: controller.mutations.observeActiveThread(
        String(text || "").trim(), "focused-terminal")
    }
    onExited: if (root.activeThreadRefreshQueued)
      Qt.callLater(root.refreshActiveThread)
  }

  Process {
    id: newProjectProcess
    running: false
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        controller.launchError = newProjectStderr.text.trim()
          || ("Could not start Codex in the project; check " + root.launchLogPath)
        root.clearPendingNew()
        return
      }
      launchCoordinator.state.recordPendingOutput(
        String(newProjectStdout.text || "").trim(), "", "")
      controller.threadActions.scheduleEventRefresh()
      newThreadResolveTimer.restart()
      root.resolvePendingNew()
    }
    stdout: StdioCollector { id: newProjectStdout; waitForEnd: true }
    stderr: StdioCollector { id: newProjectStderr; waitForEnd: true }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { activeThreadDebounce.restart() }
  }

  Timer {
    id: newThreadResolveTimer
    interval: 500
    repeat: true
    onTriggered: {
      launchCoordinator.state.tickPending()
      controller.providers.refreshThreads()
      root.resolvePendingNew()
      if (!launchCoordinator.state.pending) stop()
      else if (launchCoordinator.state.pendingAttempts <= 0) root.clearPendingNew()
    }
  }

  Timer {
    id: activeThreadDebounce
    interval: 100
    repeat: false
    onTriggered: root.refreshActiveThread()
  }

  Component.onCompleted: refreshActiveThread()
}
