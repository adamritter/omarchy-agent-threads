import QtQuick
import "../logic/ActionLogic.js" as ActionLogic

Item {
  id: root

  required property var panel
  required property var listView
  readonly property var service: panel.service
  property string followedActiveThreadId: ""

  function rowIndexForThread(threadId, remoteId) {
    var scope = remoteId !== undefined
      ? String(remoteId || "local")
      : String(threadScopeForId(threadId) || "local")
    return panel.rowIndexForKey("thread:" + scope + ":" + String(threadId || ""))
  }

  function projectHeaderIndex(path, remoteId) {
    return panel.rowIndexForKey(
      "project:" + String(remoteId || "local") + ":" + String(path || ""))
  }

  function remoteHeaderIndex(remoteId) {
    return panel.rowIndexForKey("remote:" + String(remoteId || ""))
  }

  function openSelected() {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    var row = panel.viewRows[panel.selectedIndex]
    if (row.kind === "more")
      panel.showAllGroup(row.groupKind, row.path, row.remoteId)
    else if (row.kind === "remote") panel.toggleRemote(row.remoteId)
    else if (row.kind === "project") panel.toggleProject(row.path, row.remoteId)
    else if (row.remoteId) {
      panel.releaseSidebarFocus(true)
      service.openRemoteThread(row.remoteId, row.thread, row.path)
    } else {
      panel.releaseSidebarFocus(true)
      service.openThread(row.thread, row.path)
    }
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
    return panel.rowKey(panel.viewRows[index])
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
    return String(service.launchingThreadId || service.activeThreadId || "")
  }

  function activateAdjacentThread(direction) {
    var activeIndex = activeThreadRowIndex()
    if (activeIndex < 0) return ""
    var index = adjacentThreadIndex(activeIndex, direction, Number(direction) >= 0)
    if (index < 0) return ""
    var row = panel.viewRows[index]
    var key = selectThreadIndex(index)
    panel.releaseSidebarFocus(true)
    if (row.remoteId)
      service.openRemoteThread(row.remoteId, row.thread, row.path)
    else service.openThread(row.thread, row.path)
    return key
  }

  function newSelectedThread() {
    var path = panel.homePath
    if (panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length) {
      var row = panel.viewRows[panel.selectedIndex]
      path = String(row.path || (row.host ? row.host.home : "") || panel.homePath)
      if (row.remoteId) {
        service.newRemoteThread(row.remoteId, path)
        return
      }
    }
    if (panel.activeProvider !== "codex") {
      var host = panel.providerHost(panel.activeProvider)
      if (!host) {
        service.launchError = panel.providerLabel(panel.activeProvider) + " provider is not ready"
        return
      }
      service.newRemoteThread(host.id, path)
      return
    }
    service.newProjectThread(path)
  }

  function openSelectedTerminal() {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    var target = ActionLogic.terminalTarget(
      panel.activeProvider, panel.homePath, row, panel.activeProviderHost)
    if (target.error !== "") {
      if (target.error === "ssh-required")
        service.launchError = "Opening a terminal for this remote requires an SSH connection"
      else if (target.error === "ssh-host-missing")
        service.launchError = "The SSH host or alias is missing"
      else service.launchError = "The selected remote is not ready"
      return false
    }
    panel.releaseSidebarFocus(true)
    return service.openTerminal(target.mode, target.endpoint, target.path)
  }

  function archiveSelected() {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    var row = panel.viewRows[panel.selectedIndex]
    if (row.kind !== "thread") return
    if (row.remoteId) service.archiveRemoteThread(row.remoteId, row.thread)
    else service.archiveThread(row.thread)
  }

  function renameSelected() {
    panel.startRename()
  }

  function togglePin(remoteId, thread) {
    if (!thread || !thread.id) return
    if (remoteId) service.toggleRemoteThreadPin(remoteId, thread)
    else service.toggleThreadPin(thread)
  }

  function togglePinSelected() {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    var row = panel.viewRows[panel.selectedIndex]
    if (row.kind === "thread") togglePin(row.remoteId, row.thread)
    else if (row.kind === "remote")
      panel.toggleSectionPin("remote", "", row.remoteId)
    else if (row.kind === "project")
      panel.toggleSectionPin("project", row.path, row.remoteId)
  }

  function pinnedThreadCount() {
    var count = 0
    if (panel.activeProvider === "codex") {
      for (var i = 0; i < service.threads.length; i++)
        if (service.threads[i] && service.threads[i].isPinned === true) count++
    }
    var hosts = service.remoteHosts || []
    for (var hostIndex = 0; hostIndex < hosts.length; hostIndex++) {
      var hostProvider = String(hosts[hostIndex].providerType || "")
      if (panel.activeProvider === "codex" ? hostProvider !== ""
          : hostProvider !== panel.activeProvider) continue
      var remoteThreads = hosts[hostIndex].threads || []
      for (var threadIndex = 0; threadIndex < remoteThreads.length; threadIndex++)
        if (remoteThreads[threadIndex]
            && remoteThreads[threadIndex].isPinned === true) count++
    }
    return count
  }

  function threadForId(threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return null
    for (var i = 0; i < service.threads.length; i++) {
      if (String(service.threads[i].id || "") === wanted) return service.threads[i]
    }
    var configuredRemoteHosts = service.remoteHosts || []
    for (var hostIndex = 0; hostIndex < configuredRemoteHosts.length; hostIndex++) {
      var host = configuredRemoteHosts[hostIndex]
      var hostThreads = host.threads || []
      for (var threadIndex = 0; threadIndex < hostThreads.length; threadIndex++) {
        if (String(hostThreads[threadIndex].id || "") === wanted)
          return hostThreads[threadIndex]
      }
    }
    return null
  }

  function threadScopeForId(threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return ""
    for (var localIndex = 0; localIndex < service.threads.length; localIndex++) {
      if (String(service.threads[localIndex].id || "") === wanted) return ""
    }
    var configuredRemoteHosts = service.remoteHosts || []
    for (var hostIndex = 0; hostIndex < configuredRemoteHosts.length; hostIndex++) {
      var host = configuredRemoteHosts[hostIndex]
      var hostThreads = host.threads || []
      for (var threadIndex = 0; threadIndex < hostThreads.length; threadIndex++) {
        if (String(hostThreads[threadIndex].id || "") === wanted)
          return String(host.id || "")
      }
    }
    return ""
  }

  function handleHorizontalNavigation(direction) {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    var row = panel.viewRows[panel.selectedIndex]

    if (direction < 0) {
      if (row.kind === "thread") {
        if (row.grouped !== true) return
        panel.selectedIndex = row.depth > 1
          ? projectHeaderIndex(row.path, row.remoteId)
          : remoteHeaderIndex(row.remoteId)
        listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      } else if (row.kind === "remote") {
        if (!panel.remoteCollapsed(row.remoteId)) panel.toggleRemote(row.remoteId)
      } else if (!panel.projectCollapsed(row.path, row.remoteId)) {
        panel.setProjectCollapsed(row.path, true, true, row.remoteId)
      } else if (row.remoteId) {
        panel.selectedIndex = remoteHeaderIndex(row.remoteId)
        listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      }
      return
    }

    if (row.kind === "remote") {
      if (panel.remoteCollapsed(row.remoteId)) panel.toggleRemote(row.remoteId)
      else if (panel.selectedIndex + 1 < panel.viewRows.length) panel.selectedIndex++
      listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      return
    }
    if (row.kind !== "project") return
    if (panel.projectCollapsed(row.path, row.remoteId)) {
      panel.setProjectCollapsed(row.path, false, true, row.remoteId)
    } else if (panel.selectedIndex + 1 < panel.viewRows.length
               && panel.viewRows[panel.selectedIndex + 1].kind === "thread"
               && panel.viewRows[panel.selectedIndex + 1].path === row.path) {
      panel.selectedIndex++
      listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
    }
  }

  function followActiveThread(force) {
    // Refreshes must not overwrite a selection made while the sidebar is focused.
    var activeId = followTargetThreadId()
    if (activeId === "") {
      followedActiveThreadId = ""
      return
    }
    if (!force && (panel.sidebarFocused || panel.reloadSelectionPending)) return

    var activeThread = threadForId(activeId)
    if (!activeThread) return
    var path = panel.projectPath(activeThread)
    var activeRemoteId = threadScopeForId(activeId)
    var activeHost = activeRemoteId !== "" ? service.remoteHostById(activeRemoteId) : null
    var activeThreadProvider = activeHost
      ? String(activeHost.providerType || "codex") : "codex"
    if (activeThreadProvider !== panel.activeProvider) return

    // The common focus path already has the active row in view. Select it
    // directly instead of rebuilding the complete grouped model again.
    var visibleIndex = rowIndexForThread(activeId)
    if (visibleIndex >= 0) {
      followedActiveThreadId = activeId
      panel.selectedIndex = visibleIndex
      if (panel.opened) Qt.callLater(function() {
        listView.positionViewAtIndex(visibleIndex, ListView.Contain)
      })
      return
    }
    if (activeRemoteId !== "") {
      path = service.remotePathForThread(activeHost, activeThread)
      if (force && panel.remoteCollapsed(activeRemoteId)) {
        var expandedRemotes = Object.assign({}, panel.collapsedRemotes)
        expandedRemotes[activeRemoteId] = false
        service.setCollapsedRemotes(expandedRemotes)
      }
    }
    if (path !== "" && (activeRemoteId !== "" || panel.isProjectPath(path))
        && panel.projectCollapsed(path, activeRemoteId) && force) {
      var expanded = Object.assign({}, panel.collapsedProjects)
      expanded[panel.projectCollapseKey(path, activeRemoteId)] = false
      service.setCollapsedProjects(expanded)
    }
    panel.rebuildRows("thread:" + String(activeRemoteId || "local") + ":" + activeId)

    var index = rowIndexForThread(activeId)
    if (index < 0) return
    if (!force && followedActiveThreadId === activeId && panel.selectedIndex === index) return
    followedActiveThreadId = activeId
    panel.selectedIndex = index
    if (panel.opened) Qt.callLater(function() {
      listView.positionViewAtIndex(index, ListView.Contain)
    })
  }

  function activeThreadCursorPoint() {
    var targetThreadId = followTargetThreadId()
    var activeThread = threadForId(targetThreadId)
    if (!activeThread) return visibleListCursorPoint()
    followActiveThread(true)

    var index = rowIndexForThread(targetThreadId)
    if (index < 0) return visibleListCursorPoint()

    followedActiveThreadId = targetThreadId
    panel.selectedIndex = index
    listView.positionViewAtIndex(index, ListView.Contain)
    listView.forceLayout()

    var row = listView.itemAtIndex(index)
    // A distant row may not be instantiated synchronously after ListView moves.
    // The caller only needs a safe point inside the sidebar, so fall back to
    // the visible list center instead of leaving the pointer outside it.
    if (!row) return visibleListCursorPoint()

    var point = row.mapToItem(null, row.width / 2, row.height / 2)
    return JSON.stringify({ x: Math.round(point.x), y: Math.round(point.y) })
  }

  function visibleListCursorPoint() {
    var point = listView.mapToItem(null, listView.width / 2, listView.height / 2)
    return JSON.stringify({ x: Math.round(point.x), y: Math.round(point.y) })
  }
}
