import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/PanelReloadStateLogic.js" as PanelReloadStateLogic

Item {
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

  Process {
    id: fullscreenProbeObject
    command: [panel.environment.workspaceStateHelperPath]
    running: false
    onRunningChanged: {
      if (!running && panel.session.fullscreenProbeQueued) {
        panel.session.fullscreenProbeQueued = false
        fullscreenProbeDebounceObject.restart()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: panel.focusActions.applyFullscreenState(text)
    }
  }
}
