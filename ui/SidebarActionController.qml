import QtQuick
import "../logic/ActionLogic.js" as ActionLogic

Item {
  id: root

  required property var controller
  required property var panel
  required property var listView
  readonly property var service: panel.service
  readonly property var environment: panel.environment || panel

  function rowIndexForThread(threadId, remoteId) {
    var scope = remoteId !== undefined
      ? String(remoteId || "local")
      : String(controller.threadScopeForId(threadId) || "local")
    return panel.listActions.rowIndexForKey("thread:" + scope + ":" + String(threadId || ""))
  }
  
  function projectHeaderIndex(path, remoteId) {
    return panel.listActions.rowIndexForKey(
      "project:" + String(remoteId || "local") + ":" + String(path || ""))
  }
  
  function remoteHeaderIndex(remoteId) {
    return panel.listActions.rowIndexForKey("remote:" + String(remoteId || ""))
  }
  
  SidebarRowPresentation {
    id: rowPresenter
    controller: root.controller
    panel: root.panel
    service: root.service
  }

  function rowPresentation(row, index, hovered) {
    return rowPresenter.rowPresentation(row, index, hovered)
  }

  function loginRemoteForRow(row) {
    var entry = row || ({})
    var remoteId = String(entry.remoteId || "")
    return remoteId !== "" && service.providers.loginRemoteClaude(remoteId)
  }
  
  function createThreadForRow(row) {
    var entry = row || ({})
    var path = String(entry.path || (entry.host ? entry.host.home : "")
      || environment.homePath)
    if (entry.remoteId)
      return service.providers.newRemoteThread(entry.remoteId, path)
    return service.threadActions.newProjectThread(path)
  }
  
  function toggleSectionPinForRow(row) {
    var entry = row || ({})
    if (entry.kind !== "remote" && entry.kind !== "project") return false
    panel.listActions.toggleSectionPin(entry.kind, entry.path, entry.remoteId)
    return true
  }
  
  function archiveRow(row) {
    var entry = row || ({})
    if (entry.kind !== "thread" || !entry.thread) return false
    if (entry.remoteId) service.providers.archiveRemoteThread(entry.remoteId, entry.thread)
    else service.threadActions.archiveThread(entry.thread)
    return true
  }
  
  function renameRow(row) {
    var entry = row || ({})
    if (entry.kind !== "thread" || !entry.thread) return false
    panel.overlayActions.startRename(entry.remoteId, entry.thread)
    return true
  }
  
  function moveRowToProject(row, target) {
    var entry = row || ({})
    var destination = target || ({})
    if (entry.kind !== "thread" || entry.remoteId || !entry.thread
        || !destination.path) return false
    return service.threadActions.moveThreadToProject(
      entry.thread, destination.path, destination.name)
  }
  
  function testRemoteForRow(row) {
    var remoteId = String(row && row.remoteId || "")
    return remoteId !== "" && service.providers.testRemote(remoteId)
  }
  
  function manageRemoteForRow(row) {
    var remoteId = String(row && row.remoteId || "")
    if (remoteId === "") return false
    panel.overlayActions.openRemoteSetup(remoteId)
    return true
  }
  
  function disableRemoteForRow(row) {
    var remoteId = String(row && row.remoteId || "")
    if (remoteId === "") return false
    panel.overlayActions.disableRemote(remoteId)
    return true
  }
  
  function openSelected(source) {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length)
      return ""
    var row = panel.viewRows[panel.selectedIndex]
    var key = panel.listActions.rowKey(row)
    if (row.kind === "more") {
      panel.listActions.showAllGroup(row.groupKind, row.path, row.remoteId)
      return key
    }
    if (row.kind === "remote") {
      panel.listActions.toggleRemote(row.remoteId)
      return key
    }
    if (row.kind === "project") {
      panel.listActions.toggleProject(row.path, row.remoteId)
      return key
    }
  
    panel.focusActions.releaseSidebarFocus(true)
    var started = row.remoteId
      ? service.providers.openRemoteThread(
          row.remoteId, row.thread, row.path, source || "keyboard")
      : service.threadActions.openThread(row.thread, row.path, source || "keyboard")
    if (started !== true) return ""
    controller.activationIntentThreadId = String(row.thread && row.thread.id || "")
    return key
  }
  
  function activateRow(index, source) {
    var key = selectThreadIndex(index)
    if (key === "") return ""
    return openSelected(source || "pointer")
  }
  
  function adjacentThreadIndex(startIndex, direction, wrap) {
    var rows = panel.viewRows || []
    if (rows.length === 0) return -1
    var step = Number(direction) < 0 ? -1 : 1
    var start = Number(startIndex)
    if (start < 0 || start >= rows.length) start = step > 0 ? -1 : 0
    for (var offset = 1; offset <= rows.length; offset++) {
      var candidate = start + step * offset
      if (wrap === false && (candidate < 0 || candidate >= rows.length)) return -1
      var index = candidate % rows.length
      if (index < 0) index += rows.length
      if (rows[index] && rows[index].kind === "thread") return index
    }
    return -1
  }
  
  function selectThreadIndex(index) {
    if (index < 0 || index >= panel.viewRows.length) return ""
    panel.selectedIndex = index
    if (panel.opened)
      listView.positionViewAtIndex(index, ListView.Contain)
    return panel.listActions.rowKey(panel.viewRows[index])
  }
  
  function selectAdjacentThread(direction) {
    return selectThreadIndex(adjacentThreadIndex(panel.selectedIndex, direction, true))
  }
  
  function activeThreadRowIndex() {
    var activeId = String(service.activeThreadId || "")
    if (activeId === "") return -1
    var rows = panel.viewRows || []
    for (var index = 0; index < rows.length; index++) {
      var row = rows[index]
      if (row && row.kind === "thread" && row.thread
          && String(row.thread.id || "") === activeId) return index
    }
    return -1
  }
  
  function followTargetThreadId() {
    var intent = String(activationIntentThreadId || "")
    var active = String(service.activeThreadId || "")
    var launching = String(service.launchingThreadId || "")
    var failed = String(service.failedLaunchThreadId || "")
    if (intent !== "") {
      if (active === intent) controller.activationIntentThreadId = ""
      else if (launching === intent || failed === intent) return intent
      else controller.activationIntentThreadId = ""
    }
    return launching || active
  }
  
  function activateAdjacentThread(direction) {
    var activeIndex = activeThreadRowIndex()
    if (activeIndex < 0) return ""
    var index = adjacentThreadIndex(activeIndex, direction, Number(direction) >= 0)
    if (index < 0) return ""
    if (selectThreadIndex(index) === "") return ""
    return openSelected("cycle")
  }
  
  function newSelectedThread() {
    var path = environment.homePath
    if (panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length) {
      var row = panel.viewRows[panel.selectedIndex]
      path = String(row.path || (row.host ? row.host.home : "") || environment.homePath)
      if (row.remoteId) {
        service.providers.newRemoteThread(row.remoteId, path)
        return
      }
    }
    if (panel.activeProvider !== "codex") {
      var host = panel.providerActions.providerHost(panel.activeProvider)
      if (!host) {
        service.launchError = panel.providerActions.providerLabel(panel.activeProvider) + " provider is not ready"
        return
      }
      service.providers.newRemoteThread(host.id, path)
      return
    }
    service.threadActions.newProjectThread(path)
  }
  
  function openSelectedTerminal() {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    var target = ActionLogic.terminalTarget(
      panel.activeProvider, environment.homePath, row, panel.activeProviderHost)
    if (target.error !== "") {
      if (target.error === "ssh-required")
        service.launchError = "Opening a terminal for this remote requires an SSH connection"
      else if (target.error === "ssh-host-missing")
        service.launchError = "The SSH host or alias is missing"
      else service.launchError = "The selected remote is not ready"
      return false
    }
    panel.focusActions.releaseSidebarFocus(true)
    return service.providers.openTerminal(target.mode, target.endpoint, target.path)
  }
  
  function archiveSelected() {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    archiveRow(panel.viewRows[panel.selectedIndex])
  }
  
  function renameSelected() {
    panel.overlayActions.startRename()
  }
  
  function togglePin(remoteId, thread) {
    if (!thread || !thread.id) return
    if (remoteId) service.providers.toggleRemoteThreadPin(remoteId, thread)
    else service.threadActions.toggleThreadPin(thread)
  }
  
}
