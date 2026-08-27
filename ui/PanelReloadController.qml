import QtQuick
import Quickshell
import "../logic/PanelReloadStateLogic.js" as PanelReloadStateLogic

QtObject {
  required property var panel

  function clearNavigationPrefix() {
    panel.session.navigationCount = ""
    panel.session.navigationFindDirection = 0
  }
  
  function schedulePanelReloadStateCapture() {
    if (panel.session.reloadStateLoaded && !panel.session.applyingReloadState)
      panel.runtime.reloadStateCaptureTimer.restart()
  }
  
  function capturePanelReloadState() {
    if (panel.reloadStatePath === "") return
    panel.runtime.reloadStateCaptureTimer.stop()
    var encoded = PanelReloadStateLogic.encode({
      workspaceKey: panel.session.activeWorkspaceKey,
      selectedRowKey: panel.listActions.rowKey(panel.viewRows[panel.selectedIndex]),
      keyboardFocusRequested: panel.session.keyboardFocusRequested,
      focusTarget: panel.sidebarView.searchField.activeFocus ? "search" : "list",
      searchText: panel.session.searchText,
      searchOpen: panel.session.searchOpen,
      expandedGroups: panel.session.expandedGroups,
      cursorReturnX: panel.session.cursorReturnX,
      cursorReturnY: panel.session.cursorReturnY
    }, Quickshell.processId, Quickshell.instanceId, Date.now())
    if (encoded !== "") panel.runtime.reloadStateFile.setText(encoded)
  }
  
  function loadPanelReloadState(raw) {
    var state = PanelReloadStateLogic.decode(
      raw, Quickshell.processId, Quickshell.instanceId, Date.now(), 5000)
    panel.session.reloadStateLoaded = true
    if (!state) return
  
    panel.session.applyingReloadState = true
    panel.session.expandedGroups = state.expandedGroups
    panel.session.searchText = state.searchText
    panel.session.searchOpen = state.searchOpen || panel.session.searchText !== ""
    panel.session.pendingReloadRowKey = state.selectedRowKey
    panel.session.reloadSelectionGuard = panel.session.pendingReloadRowKey !== ""
    if (panel.session.reloadSelectionGuard)
      panel.runtime.reloadSelectionGuardTimer.restart()
    panel.session.pendingReloadFocus = state.keyboardFocusRequested
    panel.session.pendingReloadFocusTarget = state.focusTarget
    panel.session.pendingReloadWorkspaceKey = state.workspaceKey
    panel.session.cursorReturnX = state.cursorReturnX
    panel.session.cursorReturnY = state.cursorReturnY
    panel.listActions.rebuildRows(panel.session.pendingReloadRowKey)
    panel.session.applyingReloadState = false
  
    if (panel.viewRows.length > 0) Qt.callLater(function() {
      panel.sidebarView.threadList.positionViewAtIndex(
        panel.selectedIndex, ListView.Contain)
    })
    Qt.callLater(tryRestorePanelReloadFocus)
  }
  
  function tryRestorePanelReloadFocus() {
    if (!panel.session.pendingReloadFocus || !panel.bar || panel.fullscreenSuppressed) return
    if (panel.session.activeWorkspaceKey === "") return
    if (!PanelReloadStateLogic.workspaceMatches(
          panel.session.pendingReloadWorkspaceKey, panel.session.activeWorkspaceKey)) {
      cancelPanelReloadFocus()
      return
    }
    panel.focusActions.requestOpen()
    panel.runtime.reloadFocusRestoreTimer.restart()
  }

  function cancelPanelReloadFocus() {
    panel.session.pendingReloadFocus = false
    panel.runtime.reloadFocusRestoreTimer.stop()
  }
}
