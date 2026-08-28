import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../logic/PanelReloadStateLogic.js" as PanelReloadStateLogic
import "../logic/WorkspaceStateLogic.js" as WorkspaceStateLogic

Item {
  id: root
  required property var panel
  visible: false

  readonly property alias reloadStateCaptureTimer: reloadStateCaptureTimerObject
  readonly property alias reloadStateFile: reloadStateFileObject
  readonly property alias reloadFocusRestoreTimer: reloadFocusRestoreTimerObject
  readonly property alias reloadSelectionGuardTimer: reloadSelectionGuardTimerObject
  readonly property alias focusAcquireTimer: focusAcquireTimerObject
  readonly property alias focusPrimeTimer: focusPrimeTimerObject
  readonly property alias focusReleaseGuard: focusReleaseGuardObject
  readonly property alias pointerWarpGuard: pointerWarpGuardObject
  readonly property alias fullscreenProbeDebounce: fullscreenProbeDebounceObject
  readonly property alias cursorPositionProbe: cursorPositionProbeObject
  readonly property alias fullscreenProbe: fullscreenProbeObject

  Timer {
    id: reloadStateCaptureTimerObject
    interval: 40
    repeat: false
    onTriggered: panel.reloadActions.capturePanelReloadState()
  }

  Timer {
    id: reloadFocusRestoreTimerObject
    interval: 350
    repeat: false
    onTriggered: {
      if (!panel.session.pendingReloadFocus || !panel.sidebarPresented) return
      if (!PanelReloadStateLogic.workspaceMatches(
            panel.session.pendingReloadWorkspaceKey, panel.session.activeWorkspaceKey)) {
        panel.reloadActions.cancelPanelReloadFocus()
        return
      }
      panel.session.pendingReloadFocus = false
      panel.focusActions.focusSidebar()
      if (panel.session.pendingReloadFocusTarget === "search" && panel.session.searchOpen)
        Qt.callLater(function() { panel.sidebarView.searchField.forceActiveFocus() })
    }
  }

  Timer {
    id: reloadSelectionGuardTimerObject
    interval: 1000
    repeat: false
    onTriggered: panel.session.reloadSelectionGuard = false
  }

  Timer {
    interval: 1000
    running: panel.sidebarPresented || panel.session.keyboardFocusRequested
    repeat: true
    triggeredOnStart: true
    onTriggered: panel.reloadActions.capturePanelReloadState()
  }

  FileView {
    id: reloadStateFileObject
    path: panel.reloadStatePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: panel.reloadActions.loadPanelReloadState(text())
    onLoadFailed: panel.reloadActions.loadPanelReloadState("")
  }

  Timer {
    id: focusPrimeTimerObject
    interval: 75
    repeat: false
    onTriggered: if (panel.opened && panel.session.keyboardFocusRequested)
      panel.session.focusPrimed = true
  }

  Timer {
    id: focusAcquireTimerObject
    interval: 10
    repeat: true
    onTriggered: {
      panel.sidebarView.forceActiveFocus()
      panel.session.focusAttemptsRemaining--
      if (panel.sidebarView.activeFocus) {
        stop()
        focusPrimeTimerObject.restart()
      } else if (panel.session.focusAttemptsRemaining <= 0) {
        stop()
        panel.focusActions.releaseSidebarFocus(true)
      }
    }
  }

  Timer { id: focusReleaseGuardObject; interval: 350; repeat: false }
  Timer { id: pointerWarpGuardObject; interval: 350; repeat: false }

  Timer {
    id: fullscreenProbeDebounceObject
    interval: 40
    repeat: false
    onTriggered: panel.focusActions.queryFullscreenState()
  }

  Process {
    id: cursorPositionProbeObject
    command: ["hyprctl", "cursorpos", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: panel.focusActions.completeSidebarSummon(text)
    }
  }

  function ipcObject(object) {
    if (!object) return ({})
    try { return object.lastIpcObject || ({}) }
    catch (error) { return ({}) }
  }

  function workspaceSnapshot(workspace) {
    if (!workspace) return ({})
    var source = ipcObject(workspace)
    return {
      id: Number(workspace.id || source.id || 0),
      name: String(workspace.name || source.name || ""),
      monitorID: workspace.monitor ? Number(workspace.monitor.id) : Number(source.monitorID || -1),
      hasfullscreen: workspace.hasFullscreen === true || source.hasfullscreen === true
    }
  }

  function monitorSnapshot(monitor) {
    if (!monitor) return ({})
    var source = ipcObject(monitor)
    return {
      id: Number(monitor.id),
      x: Number(monitor.x),
      y: Number(monitor.y),
      width: Number(monitor.width),
      height: Number(monitor.height),
      scale: Number(monitor.scale),
      specialWorkspace: source.specialWorkspace || ({})
    }
  }

  function workspaceState() {
    var monitor = Hyprland.focusedMonitor
    var active = monitor && monitor.activeWorkspace
      ? monitor.activeWorkspace : Hyprland.focusedWorkspace
    var workspaces = []
    var workspaceValues = Hyprland.workspaces.values
    for (var workspaceIndex = 0; workspaceIndex < workspaceValues.length; workspaceIndex++)
      workspaces.push(workspaceSnapshot(workspaceValues[workspaceIndex]))
    var clients = []
    var toplevelValues = Hyprland.toplevels.values
    for (var clientIndex = 0; clientIndex < toplevelValues.length; clientIndex++)
      clients.push(ipcObject(toplevelValues[clientIndex]))
    return WorkspaceStateLogic.derive(
      workspaceSnapshot(active), monitorSnapshot(monitor), workspaces, clients)
  }

  QtObject {
    id: fullscreenProbeObject
    property bool running: false
    onRunningChanged: {
      if (running) {
        Qt.callLater(function() {
          if (!fullscreenProbeObject.running) return
          panel.focusActions.applyFullscreenState(
            JSON.stringify(root.workspaceState()))
          fullscreenProbeObject.running = false
        })
        return
      }
      if (!running && panel.session.fullscreenProbeQueued) {
        panel.session.fullscreenProbeQueued = false
        fullscreenProbeDebounceObject.restart()
      }
    }
  }
}
