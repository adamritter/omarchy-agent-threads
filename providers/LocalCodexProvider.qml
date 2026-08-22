import QtQuick
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  required property var controller

  property bool activeThreadRefreshQueued: false
  property var newThreadKnownIds: ({})
  property string pendingNewThreadPath: ""
  property string pendingNewThreadId: ""
  property string pendingNewWindowAddress: ""
  property int pendingNewThreadAttempts: 0

  readonly property string openHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-thread-open").toString().replace(/^file:\/\//, "")
  readonly property string activeThreadHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-active-thread").toString().replace(/^file:\/\//, "")
  readonly property string newProjectHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-project-new").toString().replace(/^file:\/\//, "")
  readonly property string mapThreadWindowHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-map-thread-window").toString().replace(/^file:\/\//, "")

  function openThread(thread, cwdOverride) {
    if (!thread || !thread.id || openProcess.running) return
    controller.launchingThreadId = String(thread.id)
    controller.launchError = ""
    openProcess.command = [
      openHelperPath,
      controller.launchingThreadId,
      String(cwdOverride || controller.projectPathForThread(thread)
        || controller.backendHomePath),
      "", "", "",
      controller.selectedModel,
      controller.selectedEffort
    ]
    openProcess.running = true
    controller.threadLaunchRequested(controller.launchingThreadId)
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
    newProjectProcess.command = [
      newProjectHelperPath, path, "", "", "",
      controller.selectedModel, controller.selectedEffort
    ]
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
          controller.activeThreadId = id
          break
        }
      }
    }
    if (pendingNewThreadId === "" || pendingNewWindowAddress === "") return
    if (!mapThreadWindowProcess.running) {
      mapThreadWindowProcess.command = [
        mapThreadWindowHelperPath, pendingNewThreadId, pendingNewWindowAddress
      ]
      mapThreadWindowProcess.running = true
    }
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
      if (exitCode !== 0)
        controller.launchError = openStderr.text.trim() || "Could not open the Codex thread"
      controller.launchingThreadId = ""
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
      onStreamFinished: controller.activeThreadId = String(text || "").trim()
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
          || "Could not start Codex in the project"
        root.clearPendingNew()
        return
      }
      root.pendingNewWindowAddress = String(newProjectStdout.text || "").trim()
      controller.scheduleEventRefresh()
      newThreadResolveTimer.restart()
      root.resolvePendingNew()
    }
    stdout: StdioCollector { id: newProjectStdout; waitForEnd: true }
    stderr: StdioCollector { id: newProjectStderr; waitForEnd: true }
  }

  Process { id: mapThreadWindowProcess; running: false }

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
      controller.refreshThreads()
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
