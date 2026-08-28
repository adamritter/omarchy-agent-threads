// Purpose: Implements the Sidebar Reload Controller user-interface component.
import QtQuick

QtObject {
  id: root

  required property var panel
  property int sidebarRevision: 0
  property int contentRevision: 0
  property var pendingState: null
  readonly property string sidebarSource: Qt.resolvedUrl("SidebarKeyRouter.qml")
    + "#reload=" + sidebarRevision
  readonly property string contentSource: Qt.resolvedUrl("SidebarMainContent.qml")
    + "#reload=" + contentRevision

  function captureState() {
    var view = panel.sidebarView
    if (!view || !view.threadList) {
      pendingState = ({})
      return
    }
    var focusTarget = ""
    if (view.searchField.activeFocus) focusTarget = "search"
    else if (view.renameField.activeFocus) focusTarget = "rename"
    else if (view.activeFocus || view.threadList.activeFocus) focusTarget = "list"
    pendingState = {
      contentY: view.threadList.contentY,
      focusTarget: focusTarget,
      providerMenuOpen: view.providerMenu.opened === true
    }
  }

  function restoreState() {
    var state = pendingState
    var view = panel.sidebarView
    if (!state || !view || !view.threadList) return
    pendingState = null
    view.threadList.contentY = Number(state.contentY || 0)
    if (state.providerMenuOpen) view.providerMenu.open()
    if (!panel.session.keyboardFocusRequested) return
    if (state.focusTarget === "search") view.searchField.forceActiveFocus()
    else if (state.focusTarget === "rename") view.renameField.forceActiveFocus()
    else view.forceActiveFocus()
  }

  function reloadEntryPoint(kind) {
    var entryKind = String(kind || "")
    if (entryKind !== "sidebar" && entryKind !== "sidebarContent") return false
    captureState()
    if (entryKind === "sidebar") sidebarRevision++
    else contentRevision++
    return true
  }
}
