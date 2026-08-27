import QtQuick

Item {
  required property var controller
  required property var panel
  required property var listView
  readonly property var service: panel.service

  function togglePinSelected() {
    if (panel.selectedIndex < 0 || panel.selectedIndex >= panel.viewRows.length) return
    var row = panel.viewRows[panel.selectedIndex]
    if (row.kind === "thread") controller.togglePin(row.remoteId, row.thread)
    else if (row.kind === "remote")
      panel.listActions.toggleSectionPin("remote", "", row.remoteId)
    else if (row.kind === "project")
      panel.listActions.toggleSectionPin("project", row.path, row.remoteId)
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
          ? controller.projectHeaderIndex(row.path, row.remoteId)
          : controller.remoteHeaderIndex(row.remoteId)
        listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      } else if (row.kind === "remote") {
        if (!panel.listActions.remoteCollapsed(row.remoteId)) panel.listActions.toggleRemote(row.remoteId)
      } else if (!panel.listActions.projectCollapsed(row.path, row.remoteId)) {
        panel.listActions.setProjectCollapsed(row.path, true, true, row.remoteId)
      } else if (row.remoteId) {
        panel.selectedIndex = controller.remoteHeaderIndex(row.remoteId)
        listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      }
      return
    }
  
    if (row.kind === "remote") {
      if (panel.listActions.remoteCollapsed(row.remoteId)) panel.listActions.toggleRemote(row.remoteId)
      else if (panel.selectedIndex + 1 < panel.viewRows.length) panel.selectedIndex++
      listView.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
      return
    }
    if (row.kind !== "project") return
    if (panel.listActions.projectCollapsed(row.path, row.remoteId)) {
      panel.listActions.setProjectCollapsed(row.path, false, true, row.remoteId)
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
      controller.followedActiveThreadId = ""
      return
    }
    if (!force && (panel.sidebarFocused || panel.reloadSelectionPending)) return
  
    var activeThread = threadForId(activeId)
    if (!activeThread) return
    var path = panel.providerActions.projectPath(activeThread)
    var activeRemoteId = threadScopeForId(activeId)
    var activeHost = activeRemoteId !== "" ? service.providers.remoteHostById(activeRemoteId) : null
    var activeThreadProvider = activeHost
      ? String(activeHost.providerType || "codex") : "codex"
    if (activeThreadProvider !== panel.activeProvider) return
  
    // The common focus path already has the active row in view. Select it
    // directly instead of rebuilding the complete grouped model again.
    var visibleIndex = controller.rowIndexForThread(activeId)
    if (visibleIndex >= 0) {
      controller.followedActiveThreadId = activeId
      panel.selectedIndex = visibleIndex
      if (panel.opened) Qt.callLater(function() {
        listView.positionViewAtIndex(visibleIndex, ListView.Contain)
      })
      return
    }
    if (activeRemoteId !== "") {
      path = service.providers.remotePathForThread(activeHost, activeThread)
      if (force && panel.listActions.remoteCollapsed(activeRemoteId)) {
        var expandedRemotes = Object.assign({}, panel.collapsedRemotes)
        expandedRemotes[activeRemoteId] = false
        service.settings.setCollapsedRemotes(expandedRemotes)
      }
    }
    if (path !== "" && (activeRemoteId !== "" || panel.listActions.isProjectPath(path))
        && panel.listActions.projectCollapsed(path, activeRemoteId) && force) {
      var expanded = Object.assign({}, panel.collapsedProjects)
      expanded[panel.listActions.projectCollapseKey(path, activeRemoteId)] = false
      service.settings.setCollapsedProjects(expanded)
    }
    panel.listActions.rebuildRows("thread:" + String(activeRemoteId || "local") + ":" + activeId)
  
    var index = controller.rowIndexForThread(activeId)
    if (index < 0) return
    if (!force && controller.followedActiveThreadId === activeId && panel.selectedIndex === index) return
    controller.followedActiveThreadId = activeId
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
  
    var index = controller.rowIndexForThread(targetThreadId)
    if (index < 0) return visibleListCursorPoint()
  
    controller.followedActiveThreadId = targetThreadId
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
