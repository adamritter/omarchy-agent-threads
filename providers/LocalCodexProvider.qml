import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "../logic/ActionLogic.js" as ActionLogic

Item {
  id: root

  required property var controller

  property bool activeThreadRefreshQueued: false
  property var newThreadKnownIds: ({})
  property string pendingNewThreadPath: ""
  property string pendingNewThreadId: ""
  property string pendingNewWindowAddress: ""
  property int pendingNewThreadAttempts: 0
  property int openRequestId: 0

  readonly property string terminalHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-terminal-open").toString().replace(/^file:\/\//, "")
  readonly property string activeThreadHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-active-thread").toString().replace(/^file:\/\//, "")
  readonly property string launchLogPath:
    controller.stateHome + "/omarchy/agent-threads-launch.log"

  ThreadLaunchCoordinator { id: launchCoordinator }

  function openThread(thread, cwdOverride, source) {
    if (!thread || !thread.id || openProcess.running) return false
    var threadId = String(thread.id)
    var requestId = controller.mutations.beginThreadLaunch(
      threadId, source || "local-terminal")
    if (requestId === 0) return false
    openRequestId = requestId
    openProcess.command = ActionLogic.localCodexTerminalCommand(
      terminalHelperPath,
      threadId,
      String(cwdOverride || controller.threadActions.projectPathForThread(thread)
        || controller.backendHomePath),
      controller.providers.effectiveModel(),
      controller.providers.effectiveEffort(),
      controller.codexServiceTier)
    openProcess.running = true
    return true
  }

  function newThread(projectPath) {
    var path = String(projectPath || "")
    if (path === "" || newProjectProcess.running) return
    controller.launchingProjectPath = path
    controller.launchError = ""
    newThreadKnownIds = ({})
    for (var i = 0; i < controller.threads.length; i++) {
      if (controller.threads[i] && controller.threads[i].id)
        newThreadKnownIds[String(controller.threads[i].id)] = true
    }
    pendingNewThreadPath = path
    pendingNewThreadId = ""
    pendingNewWindowAddress = ""
    pendingNewThreadAttempts = 20
    newProjectProcess.command = ActionLogic.localCodexTerminalCommand(
      terminalHelperPath, "", path,
      controller.providers.effectiveModel(), controller.providers.effectiveEffort(),
      controller.codexServiceTier)
    newProjectProcess.running = true
  }

  function clearPendingNew() {
    pendingNewThreadPath = ""
    pendingNewThreadId = ""
    pendingNewWindowAddress = ""
    pendingNewThreadAttempts = 0
    newThreadKnownIds = ({})
    controller.launchingProjectPath = ""
    newThreadResolveTimer.stop()
  }

  function resolvePendingNew() {
    if (pendingNewThreadPath === "") return
    if (pendingNewThreadId === "") {
      for (var i = 0; i < controller.threads.length; i++) {
        var thread = controller.threads[i]
        var id = String(thread && thread.id || "")
        if (id !== "" && newThreadKnownIds[id] !== true
            && String(thread.cwd || "") === pendingNewThreadPath) {
          pendingNewThreadId = id
          controller.mutations.observeActiveThread(id, "new-local-codex-thread")
          break
        }
      }
    }
    if (pendingNewThreadId === "" || pendingNewWindowAddress === "") return
    launchCoordinator.map(pendingNewThreadId, pendingNewWindowAddress, "", "")
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
      var requestId = root.openRequestId
      root.openRequestId = 0
      if (exitCode !== 0) controller.mutations.failThreadLaunch(
        requestId, openStderr.text.trim() || "Could not open the Codex thread")
      else controller.mutations.confirmThreadLaunch(requestId, "")
      root.refreshActiveThread()
    }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }

  Process {
    id: activeThreadProcess
    command: [root.activeThreadHelperPath]
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
      root.pendingNewWindowAddress = String(newProjectStdout.text || "").trim()
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
      root.pendingNewThreadAttempts--
      controller.providers.refreshThreads()
      root.resolvePendingNew()
      if (root.pendingNewThreadPath === "") stop()
      else if (root.pendingNewThreadAttempts <= 0) root.clearPendingNew()
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
