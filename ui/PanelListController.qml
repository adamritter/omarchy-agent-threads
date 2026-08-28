// Purpose: Implements the Panel List Controller user-interface component.
import QtQuick
import Quickshell
import "../logic/PresentationLogic.js" as PresentationLogic
import "../logic/ThreadListLogic.js" as ThreadListLogic

QtObject {
  required property var panel

  function isProjectPath(path) {
    return ThreadListLogic.isProjectPath(
      path, panel.environment.homePath, panel.environment.workPath, panel.environment.codexScratchRoot)
  }
  
  function rowKey(row) {
    return ThreadListLogic.rowKey(row)
  }
  
  function renderSnapshot() {
    return {
      opened: panel.opened,
      sidebarPresented: panel.sidebarPresented,
      panelVisible: panel.visible,
      layerNamespace: panel.layerNamespace,
      headerText: panel.providerActions.providerLabel(),
      statusText: panel.providerActions.statusText(),
      searchVisible: panel.sidebarView.searchField.visible,
      renameVisible: panel.sidebarView.renameField.visible,
      remoteSetupVisible: panel.remoteSetup.visible,
      helpVisible: panel.helpOverlay.visible,
      listVisible: panel.sidebarView.threadList.visible,
      fastMode: panel.service.settings.fastMode,
      notificationsEnabled: panel.service.settings.notificationsEnabled,
      selectedIndex: panel.selectedIndex,
      selectedRowKey: rowKey(panel.viewRows[panel.selectedIndex]),
      modelRowCount: panel.viewRows.length,
      renderedRows: panel.sidebarView.threadList.renderSnapshot()
    }
  }
  
  function dispatchTestInput(kind, first, second) {
    if (Quickshell.env("AGENT_THREADS_PANEL_TEST") !== "1") return false
    if (kind === "move") panel.sidebarView.moveRequested(Number(first), Number(second))
    else if (kind === "text") panel.sidebarView.textKey(String(first || ""))
    else if (kind === "activate") panel.sidebarView.activateRequested()
    else if (kind === "frontend") panel.sidebarView.frontendToggleRequested()
    else if (kind === "close") panel.sidebarView.closeRequested()
    else return false
    return true
  }
  
  function rowIndexForKey(key) {
    return ThreadListLogic.rowIndexForKey(panel.viewRows, key)
  }
  
  function groupPreviewKey(kind, path, remoteId) {
    return ThreadListLogic.groupPreviewKey(kind, path, remoteId)
  }
  
  function groupShowsAll(kind, path, remoteId) {
    return panel.session.expandedGroups[groupPreviewKey(kind, path, remoteId)] === true
  }
  
  function showAllGroup(kind, path, remoteId) {
    var next = Object.assign({}, panel.session.expandedGroups)
    next[groupPreviewKey(kind, path, remoteId)] = true
    panel.session.expandedGroups = next
    rebuildRows("")
    panel.sidebarView.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
  }
  
  function resetGroupPreview(kind, path, remoteId) {
    var key = groupPreviewKey(kind, path, remoteId)
    if (panel.session.expandedGroups[key] !== true) return
    var next = Object.assign({}, panel.session.expandedGroups)
    delete next[key]
    panel.session.expandedGroups = next
  }
  
  function rebuildRows(preferredKey) {
    var wantedKey = preferredKey
    if (wantedKey === undefined && panel.session.pendingReloadRowKey !== "")
      wantedKey = panel.session.pendingReloadRowKey
    panel.listModel.rebuildRows(wantedKey)
    if (panel.session.pendingReloadRowKey !== ""
        && rowKey(panel.viewRows[panel.selectedIndex]) === panel.session.pendingReloadRowKey)
      panel.session.pendingReloadRowKey = ""
  }
  function projectCollapseKey(path, remoteId) {
    return ThreadListLogic.projectCollapseKey(path, remoteId)
  }
  
  function sectionPinKey(kind, path, remoteId) {
    return ThreadListLogic.sectionPinKey(kind, path, remoteId)
  }
  
  function sectionPinned(kind, path, remoteId) {
    return panel.service.settings.pinnedSections[sectionPinKey(kind, path, remoteId)] === true
  }
  
  function toggleSectionPin(kind, path, remoteId) {
    var key = sectionPinKey(kind, path, remoteId)
    var next = Object.assign({}, panel.service.settings.pinnedSections)
    if (next[key] === true) delete next[key]
    else next[key] = true
    panel.service.settings.setPinnedSections(next)
    rebuildRows(kind + ":" + (kind === "remote"
      ? String(remoteId || "")
      : String(remoteId || "local") + ":" + String(path || "")))
  }
  
  function setProjectCollapsed(path, collapsed, selectHeader, remoteId) {
    var project = String(path || "")
    if (collapsed) resetGroupPreview("project", project, remoteId)
    var next = Object.assign({}, panel.service.settings.collapsedProjects)
    next[projectCollapseKey(project, remoteId)] = !!collapsed
    panel.service.settings.setCollapsedProjects(next)
    rebuildRows(selectHeader
      ? "project:" + String(remoteId || "local") + ":" + project
      : undefined)
    panel.sidebarView.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
  }
  
  function projectCollapsed(path, remoteId) {
    return panel.service.settings.collapsedProjects[projectCollapseKey(path, remoteId)] !== false
  }
  
  function toggleProject(path, remoteId) {
    setProjectCollapsed(path, !projectCollapsed(path, remoteId), true, remoteId)
  }
  
  function remoteCollapsed(remoteId) {
    return panel.service.settings.collapsedRemotes[String(remoteId || "")] !== false
  }
  
  function toggleRemote(remoteId) {
    var id = String(remoteId || "")
    var next = Object.assign({}, panel.service.settings.collapsedRemotes)
    next[id] = !remoteCollapsed(id)
    if (next[id]) resetGroupPreview("remote", "", id)
    panel.service.settings.setCollapsedRemotes(next)
    rebuildRows("remote:" + id)
    if (next[id] === false) panel.service.providers.refreshRemotes(id)
    panel.sidebarView.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
  }
  
  function age(timestamp) {
    return PresentationLogic.relativeAge(timestamp, panel.session.nowMs)
  }

  function totalThreadCount() {
    return PresentationLogic.totalThreadCount(
      panel.activeProvider, panel.service.threads, panel.service.providers.remoteHosts)
  }
}
