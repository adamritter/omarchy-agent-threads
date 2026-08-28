// Purpose: Implements the Sidebar Key Router user-interface component.
import QtQuick
import QtQuick.Controls
import qs.Commons
import "../logic/NavigationLogic.js" as NavigationLogic

SidebarKeyCatcher {
  id: root
  required property var panel
  readonly property var content: contentLoader.item
  readonly property var searchField: content ? content.searchField : null
  readonly property var renameField: content ? content.renameField : null
  readonly property var threadList: content ? content.threadList : null
  readonly property var providerMenu: content ? content.providerMenu : null
  readonly property var modelEffortSelector: content ? content.modelEffortSelector : null
  blocked: !content || content.searchField.activeFocus
    || content.renameField.activeFocus
    || panel.remoteSetup.inputFocused

onMoveRequested: function(dx, dy) {
  if (panel.session.helpOpen) {
    if (dy !== 0) panel.helpOverlay.scrollRows(dy)
    return
  }
  if (content.providerMenu.opened) {
    if (dy !== 0) content.providerMenu.moveSelection(dy)
    return
  }
  if (panel.viewRows.length === 0) return
  if (dx !== 0) {
    panel.reloadActions.clearNavigationPrefix()
    panel.sidebarActions.navigation.handleHorizontalNavigation(dx)
    return
  }
  if (dy !== 0) {
    var count = NavigationLogic.countValue(panel.session.navigationCount)
    panel.reloadActions.clearNavigationPrefix()
    panel.selectedIndex = NavigationLogic.movedIndex(
      panel.selectedIndex, dy, count, panel.viewRows.length)
    content.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
  }
}
onPageRequested: function(direction, fraction) {
  if (panel.session.helpOpen) {
    panel.helpOverlay.scrollPage(direction, fraction)
    return
  }
  if (content.providerMenu.opened || panel.viewRows.length === 0) return
  var first = panel.providerActions.visibleRowIndex(true)
  var last = panel.providerActions.visibleRowIndex(false)
  var step = NavigationLogic.pageStep(first, last, fraction)
  panel.reloadActions.clearNavigationPrefix()
  panel.selectedIndex = NavigationLogic.movedIndex(
    panel.selectedIndex, direction, step, panel.viewRows.length)
  content.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
}
onEdgeRequested: function(edge) {
  if (panel.session.helpOpen) {
    panel.helpOverlay.scrollToEdge(edge)
    return
  }
  if (content.providerMenu.opened || panel.viewRows.length === 0) return
  panel.reloadActions.clearNavigationPrefix()
  panel.selectedIndex = edge < 0 ? 0 : panel.viewRows.length - 1
  content.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
}
onActivateRequested: {
  panel.reloadActions.clearNavigationPrefix()
  if (content.providerMenu.opened) content.providerMenu.activateSelection()
  else if (panel.session.helpOpen) panel.session.helpOpen = false
  else panel.sidebarActions.actions.openSelected()
}
onTerminalRequested: {
  panel.reloadActions.clearNavigationPrefix()
  if (!panel.session.helpOpen && !content.providerMenu.opened)
    panel.sidebarActions.actions.openSelectedTerminal()
}
onFastToggleRequested: {
  panel.reloadActions.clearNavigationPrefix()
  if (panel.activeProvider === "codex") panel.service.settings.toggleFastMode()
}
onFrontendToggleRequested: {
  panel.reloadActions.clearNavigationPrefix()
  if (panel.activeProvider === "codex")
    panel.service.settings.toggleThreadFrontend("shortcut")
}
onCloseRequested: {
  if (panel.session.navigationCount !== "" || panel.session.navigationFindDirection !== 0) {
    panel.reloadActions.clearNavigationPrefix()
    return
  }
  if (content.providerMenu.opened) content.providerMenu.close()
  else if (panel.session.renameOpen) panel.overlayActions.cancelRename()
  else if (panel.session.remoteSetupOpen) panel.overlayActions.closeRemoteSetup()
  else if (panel.session.helpOpen) panel.session.helpOpen = false
  else if (panel.session.searchText !== "" || panel.session.searchOpen) panel.overlayActions.cancelSearch()
  else panel.focusActions.escapeSidebarFocus()
}
onDeleteRequested: {
  // PanelKeyCatcher reserves x for destructive actions. Archiving uses y
  // here by preference, so x intentionally does nothing.
}
onTabRequested: function(direction) {
  panel.reloadActions.clearNavigationPrefix()
  panel.switchPanel(direction)
}
onTextKey: function(text) {
  if (panel.session.navigationFindDirection !== 0) {
    var match = NavigationLogic.matchingThreadIndex(
      panel.viewRows, panel.selectedIndex, panel.session.navigationFindDirection,
      text, panel.session.navigationCount,
      function(row) { return panel.providerActions.threadTitle(row.thread) })
    panel.reloadActions.clearNavigationPrefix()
    if (match >= 0) {
      panel.selectedIndex = match
      content.threadList.positionViewAtIndex(match, ListView.Contain)
    }
    return
  }
  if (text === "q") {
    panel.reloadActions.clearNavigationPrefix()
    root.closeRequested()
    return
  }
  if (/^[0-9]$/.test(text)) {
    panel.session.navigationCount = NavigationLogic.appendCount(panel.session.navigationCount, text)
    return
  }
  if (text === "g") {
    var target = NavigationLogic.countedRowIndex(
      panel.session.navigationCount, panel.viewRows.length)
    panel.reloadActions.clearNavigationPrefix()
    if (target >= 0) {
      panel.selectedIndex = target
      content.threadList.positionViewAtIndex(target, ListView.Contain)
    }
    return
  }
  if (text === "G") {
    panel.reloadActions.clearNavigationPrefix()
    if (panel.viewRows.length > 0) {
      panel.selectedIndex = panel.viewRows.length - 1
      content.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
    }
    return
  }
  if (text === "f" || text === "F") {
    panel.session.navigationFindDirection = text === "f" ? 1 : -1
    return
  }
  panel.reloadActions.clearNavigationPrefix()
  if (text === "/") {
    panel.overlayActions.startSearch()
    return
  }
  if (text === "?") {
    panel.session.helpOpen = !panel.session.helpOpen
    return
  }
  if (text === "R"
      && (panel.activeProvider === "codex" || panel.activeProvider === "claude"
          || panel.activeProvider === "opencode")) {
    panel.overlayActions.openRemoteSetup()
    return
  }
  if (panel.session.helpOpen) return
  if (text === "P") {
    if (content.providerMenu.opened) content.providerMenu.close()
    else content.providerMenu.open()
    return
  }
  if (text === "o" || text === "O") {
    panel.sidebarActions.actions.openSelected()
    return
  }
  if (text === "t") {
    panel.sidebarActions.actions.openSelectedTerminal()
    return
  }
  if (text === "y" || text === "Y") {
    panel.sidebarActions.actions.archiveSelected()
    return
  }
  if (text === "p") {
    panel.sidebarActions.navigation.togglePinSelected()
    return
  }
  if (text === "r") {
    panel.overlayActions.startRename()
    return
  }
  if (text === "s") {
    panel.focusActions.toggleSidebarScope()
    return
  }
  if (text === "n" || text === "N")
    panel.sidebarActions.actions.newSelectedThread()
}


  Loader {
    id: contentLoader
    anchors.fill: parent
    property string requestedSource: root.panel.sidebarReload.contentSource
    property bool initialized: false

    function loadContent() {
      setSource(requestedSource, { panel: root.panel })
    }

    onRequestedSourceChanged: if (initialized) loadContent()
    onLoaded: Qt.callLater(root.panel.sidebarReload.restoreState)
    Component.onCompleted: {
      initialized = true
      loadContent()
    }
  }
}
