import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../logic/PanelFocusLogic.js" as PanelFocusLogic
import "../logic/PointerFocusLogic.js" as PointerFocusLogic

Item {
  id: root
  required property var panel
  visible: false

  Timer {
    id: focusWorkflowTimeout
    interval: 1000
    repeat: false
    onTriggered: {
      if (!panel.session.focusWorkflowPending) return
      panel.session.focusWorkflowPending = false
      root.focusSidebar()
    }
  }

  function applySidebarOpenState() {
    if (!panel.bar || panel.session.activeWorkspaceKey === "" || !panel.service.sidebarSettingsLoaded) return
    panel.session.applyingWorkspaceSidebarState = true
    panel.service.settings.migrateSidebarOpenState(panel.session.activeWorkspaceKey)
    if (panel.service.settings.sidebarOpenOnWorkspace(panel.session.activeWorkspaceKey)) panel.open()
    else panel.close()
    Qt.callLater(function() { panel.session.applyingWorkspaceSidebarState = false })
  }
  
  function focusSidebar() {
    if (!panel.opened) panel.open()
    if (panel.fullscreenSuppressed) return
    panel.session.keyboardFocusRequested = true
    panel.session.focusPrimed = false
    // Briefly use Exclusive so Hyprland transfers the compositor keyboard
    // focus, then settle on OnDemand so normal window clicks keep working.
    panel.session.focusAttemptsRemaining = 30
    panel.focusReleaseGuard.restart()
    // Take Qt item focus in this same event turn. The retry remains for the
    // freshly mapped surface case, but an already visible sidebar can now
    // consume the very next key after the summon shortcut.
    panel.keyCatcher.forceActiveFocus()
    Qt.callLater(function() {
      if (panel.opened && panel.session.keyboardFocusRequested)
        panel.keyCatcher.forceActiveFocus()
    })
    if (panel.keyCatcher.activeFocus) panel.focusPrimeTimer.restart()
    else panel.focusAcquireTimer.restart()
  }
  
  function summonSidebarFocus() {
    if (panel.session.keyboardFocusRequested) {
      escapeSidebarFocus()
      return
    }
    if (panel.session.focusWorkflowPending) return
    panel.session.focusWorkflowPending = true
    panel.session.pointerHoverSuppressed = true
    panel.session.cursorReturnX = -1
    panel.session.cursorReturnY = -1
    requestOpen()
    if (panel.fullscreenSuppressed) {
      panel.session.focusWorkflowPending = false
      return
    }
    focusWorkflowTimeout.restart()
    panel.cursorPositionProbe.running = true
  }
  
  function completeSidebarSummon(cursorText) {
    if (!panel.session.focusWorkflowPending) return
    focusWorkflowTimeout.stop()
    var returnPoint = PointerFocusLogic.cursorPoint(cursorText)
    if (returnPoint.valid) {
      panel.session.cursorReturnX = returnPoint.x
      panel.session.cursorReturnY = returnPoint.y
    }
    var point
    try { point = JSON.parse(panel.sidebarActions.activeThreadCursorPoint()) }
    catch (error) { point = ({ x: panel.appearance.sidebarContentWidth / 2, y: 1 }) }
    var summonPoint = PanelFocusLogic.summonPoint(
      panel.screen, panel.margins, panel.bar ? panel.bar.position : "",
      panel.bar ? panel.bar.barSize : 0, point, panel.appearance.sidebarContentWidth / 2)
    panel.pointerWarpGuard.restart()
    panel.session.focusWorkflowPending = false
    try {
      Hyprland.dispatch("hl.dsp.cursor.move({ x = " + summonPoint.x
        + ", y = " + summonPoint.y + " })")
    } catch (error) {
      root.focusSidebar()
      return
    }
    Qt.callLater(function() {
      if (panel.opened && !panel.fullscreenSuppressed) root.focusSidebar()
    })
  }
  
  function requestOpen() {
    panel.open()
    queryFullscreenState()
  }
  
  function requestClose() {
    panel.close()
  }
  
  function requestToggle() {
    if (panel.opened) requestClose()
    else requestOpen()
  }
  
  function toggleSidebarScope() {
    if (panel.session.activeWorkspaceKey === "") {
      queryFullscreenState()
      return
    }
    panel.service.settings.setSidebarScope(panel.service.sidebarScope === "global" ? "workspace" : "global",
                            panel.session.activeWorkspaceKey, panel.opened)
    applySidebarOpenState()
  }
  
  function queryFullscreenState() {
    if (panel.fullscreenProbe.running) {
      panel.session.fullscreenProbeQueued = true
      return
    }
    panel.fullscreenProbe.running = true
  }
  
  function applyFullscreenState(text) {
    var state = PanelFocusLogic.fullscreenState(
      String(text || "{}"), panel.session.activeWorkspaceKey, panel.session.pendingReloadWorkspaceKey)
    if (!state.valid) return
    var wasSuppressed = panel.fullscreenSuppressed
    panel.session.activeWorkspaceHasFullscreen = state.workspaceFullscreen
    panel.session.activeWorkspaceGeometryFullscreen = state.geometryFullscreen
    panel.session.fullscreenInternalState = state.internalState
    panel.session.fullscreenClientState = state.clientState
    if (state.workspaceChanged) {
      if (state.cancelReloadFocus) panel.reloadActions.cancelPanelReloadFocus()
      releaseSidebarFocus(true)
      panel.session.activeWorkspaceId = state.workspaceId
      panel.session.activeWorkspaceKey = state.workspaceKey
      applySidebarOpenState()
      Qt.callLater(panel.reloadActions.tryRestorePanelReloadFocus)
    } else if (state.workspaceId !== 0) {
      panel.session.activeWorkspaceId = state.workspaceId
    }
    if (!wasSuppressed && panel.fullscreenSuppressed) releaseSidebarFocus(true)
  }
  
  function focusSidebarFrom(x, y) {
    var returnX = Number(x)
    var returnY = Number(y)
    if (!isNaN(returnX) && !isNaN(returnY)) {
      panel.session.cursorReturnX = Math.round(returnX)
      panel.session.cursorReturnY = Math.round(returnY)
    }
    focusSidebar()
  }
  
  function releaseSidebarFocus(force) {
    focusWorkflowTimeout.stop()
    panel.session.focusWorkflowPending = false
    if (!panel.opened) return
    // Moving the pointer into the layer surface can emit a delayed toplevel
    // change. Ignore only that transition; explicit Esc always passes force.
    if (!force && panel.focusReleaseGuard.running) return
    panel.focusAcquireTimer.stop()
    panel.focusPrimeTimer.stop()
    panel.reloadActions.clearNavigationPrefix()
    panel.session.focusAttemptsRemaining = 0
    panel.session.focusPrimed = false
    panel.session.pointerHoverSuppressed = true
    panel.session.cursorReturnX = -1
    panel.session.cursorReturnY = -1
    panel.session.keyboardFocusRequested = false
    panel.searchField.focus = false
    if (panel.session.searchText === "") panel.session.searchOpen = false
    panel.keyCatcher.focus = false
    Qt.callLater(function() {
      if (!panel.sidebarFocused) panel.sidebarActions.followActiveThread(true)
    })
  }

  function escapeSidebarFocus() {
    var returnX = panel.session.cursorReturnX
    var returnY = panel.session.cursorReturnY
    releaseSidebarFocus(true)
    if (returnX < 0 || returnY < 0) return
    Quickshell.execDetached([
      "hyprctl", "dispatch",
      "hl.dsp.cursor.move({ x = " + returnX + ", y = " + returnY + " })"
    ])
  }
}
