import QtQuick

Item {
  id: root

  required property var controller
  readonly property var service: controller.service
  readonly property string activeProvider: controller.activeProvider
  readonly property string searchText: controller.searchText
  readonly property int groupPreviewLimit: controller.groupPreviewLimit

  property var viewRows: []
  property int projectCount: 0
  property int visibleThreadCount: 0
  property int selectedIndex: 0

  function cleanText(value) { return controller.cleanText(value) }
  function providerHost(providerId) { return controller.providerHost(providerId) }
  function projectPath(thread) { return controller.projectPath(thread) }
  function isProjectPath(path) { return controller.isProjectPath(path) }
  function directoryName(path) { return controller.directoryName(path) }
  function rowKey(row) { return controller.rowKey(row) }
  function rowIndexForKey(key) { return controller.rowIndexForKey(key) }
  function groupShowsAll(kind, path, remoteId) {
    return controller.groupShowsAll(kind, path, remoteId)
  }
  function groupPreviewKey(kind, path, remoteId) {
    return controller.groupPreviewKey(kind, path, remoteId)
  }
  function sectionPinned(kind, path, remoteId) {
    return controller.sectionPinned(kind, path, remoteId)
  }
  function projectCollapsed(path, remoteId) {
    return controller.projectCollapsed(path, remoteId)
  }
  function remoteCollapsed(remoteId) { return controller.remoteCollapsed(remoteId) }

  function threadSearchTitle(thread) {
    var name = cleanText(thread ? thread.name : "")
    if (name !== "") return name
    var preview = String(thread && thread.preview || "")
    return cleanText(preview.split(/\r?\n/)[0])
  }

  function threadVisible(thread, path) {
    var query = cleanText(searchText).toLowerCase()
    if (query === "") return true
    // Search only labels exposed by the sidebar. Full prompts and filesystem
    // paths contain hidden IDs, timestamps, and other surprising matches.
    var haystack = [
      threadSearchTitle(thread),
      directoryName(path)
    ].join(" ").toLowerCase()
    var terms = query.split(" ")
    for (var i = 0; i < terms.length; i++) {
      if (terms[i] !== "" && haystack.indexOf(terms[i]) < 0) return false
    }
    return true
  }

  function rebuildRows(preferredKey) {
    var previousKey = preferredKey !== undefined
      ? String(preferredKey || "")
      : rowKey(viewRows[selectedIndex])
    var groups = ({})
    var order = []
    var pinnedRows = []
    var blocks = []
    var nextBlockSequence = 0

    function newestThreadTimestamp(items) {
      var newest = 0
      for (var timestampIndex = 0; timestampIndex < items.length; timestampIndex++)
        newest = Math.max(newest, Number(items[timestampIndex]
          && items[timestampIndex].updatedAt || 0))
      return newest
    }

    function appendBlock(blockRows, updatedAt, pinned) {
      blocks.push({
        rows: blockRows,
        updatedAt: Number(updatedAt || 0),
        pinned: pinned === true,
        sequence: nextBlockSequence++
      })
    }

    function appendFlatThread(thread, path, remoteId, host) {
      if (!threadVisible(thread, path)) return
      var scope = String(remoteId || "")
      var item = {
        thread: thread,
        path: path,
        remoteId: scope,
        host: host || null
      }
      if (thread.isPinned === true) {
        pinnedRows.push({
          kind: "thread",
          path: path,
          remoteId: scope,
          host: host || null,
          grouped: false,
          pinnedDetached: true,
          thread: thread
        })
        return
      }
      if (!isProjectPath(path)) {
        order.push({
          kind: "thread",
          path: path,
          remoteId: scope,
          host: host || null,
          thread: thread
        })
        return
      }
      var key = String(scope || "local") + ":" + path
      if (!groups[key]) {
        groups[key] = []
        order.push({
          kind: "project",
          key: key,
          path: path,
          remoteId: scope,
          host: host || null
        })
      }
      groups[key].push(item)
    }

    if (activeProvider === "codex") {
      for (var i = 0; i < service.threads.length; i++) {
        var localThread = service.threads[i]
        appendFlatThread(localThread, projectPath(localThread), "", null)
      }
    } else {
      var selectedHost = providerHost(activeProvider)
      var providerThreads = selectedHost ? selectedHost.threads || [] : []
      for (var providerThreadIndex = 0;
           providerThreadIndex < providerThreads.length;
           providerThreadIndex++) {
        var providerThread = providerThreads[providerThreadIndex]
        appendFlatThread(
          providerThread,
          String(service.remotePathForThread(selectedHost, providerThread)
            || selectedHost.home || ""),
          String(selectedHost.id || ""),
          selectedHost)
      }
    }

    var rows = pinnedRows.slice()
    var projects = 0
    var visibleThreads = pinnedRows.length

    var configuredRemoteHosts = service.remoteHosts || []
    for (var hostIndex = 0; hostIndex < configuredRemoteHosts.length; hostIndex++) {
      var host = configuredRemoteHosts[hostIndex]
      var hostId = String(host.id || "")
      if (hostId === "provider-claude" || hostId === "provider-opencode") continue
      var hostProvider = String(host.providerType || "codex").toLowerCase()
      if (hostProvider !== activeProvider) continue
      var remoteGroups = ({})
      var remotePinnedGroups = ({})
      var remoteOrder = []
      var remotePinnedDirect = []
      var matchingThreads = []
      var hostThreads = Array.isArray(host.threads) ? host.threads.slice() : []
      hostThreads.sort(function(a, b) {
        var timestampDifference = Number(b && b.updatedAt || 0)
          - Number(a && a.updatedAt || 0)
        if (timestampDifference !== 0) return timestampDifference
        return String(a && a.id || "").localeCompare(String(b && b.id || ""))
      })
      var hostMatches = cleanText(host.label).toLowerCase().indexOf(cleanText(searchText).toLowerCase()) >= 0
      for (var remoteThreadIndex = 0; remoteThreadIndex < hostThreads.length; remoteThreadIndex++) {
        var remoteThread = hostThreads[remoteThreadIndex]
        var remotePath = String(service.remotePathForThread(host, remoteThread)
          || host.home || "")
        if (!hostMatches && !threadVisible(remoteThread, remotePath)) continue
        matchingThreads.push(remoteThread)
        if (remoteThread.isPinned === true) {
          if (remotePath === "" || remotePath === String(host.home || "")) {
            remotePinnedDirect.push({ path: remotePath, thread: remoteThread })
          } else {
            if (!remotePinnedGroups[remotePath]) {
              remotePinnedGroups[remotePath] = []
              if (!remoteGroups[remotePath])
                remoteOrder.push({ kind: "project", path: remotePath })
            }
            remotePinnedGroups[remotePath].push(remoteThread)
          }
          continue
        }
        if (remotePath === "" || remotePath === String(host.home || "")) {
          remoteOrder.push({ kind: "thread", path: remotePath, thread: remoteThread })
          continue
        }
        if (!remoteGroups[remotePath]) {
          remoteGroups[remotePath] = []
          if (!remotePinnedGroups[remotePath])
            remoteOrder.push({ kind: "project", path: remotePath })
        }
        remoteGroups[remotePath].push(remoteThread)
      }

      remoteOrder.sort(function(a, b) {
        var aPinned = a.kind === "project"
          && sectionPinned("project", a.path, host.id)
        var bPinned = b.kind === "project"
          && sectionPinned("project", b.path, host.id)
        var pinDifference = Number(bPinned) - Number(aPinned)
        if (pinDifference !== 0) return pinDifference
        var aUpdatedAt = a.kind === "thread"
          ? Number(a.thread && a.thread.updatedAt || 0)
          : newestThreadTimestamp((remoteGroups[a.path] || [])
            .concat(remotePinnedGroups[a.path] || []))
        var bUpdatedAt = b.kind === "thread"
          ? Number(b.thread && b.thread.updatedAt || 0)
          : newestThreadTimestamp((remoteGroups[b.path] || [])
            .concat(remotePinnedGroups[b.path] || []))
        var timestampDifference = bUpdatedAt - aUpdatedAt
        if (timestampDifference !== 0) return timestampDifference
        return String(a.path || "").localeCompare(String(b.path || ""))
      })

      function appendRemoteProject(rows, remoteEntry) {
        var remoteProjectThreads = remoteGroups[remoteEntry.path] || []
        var pinnedProjectThreads = remotePinnedGroups[remoteEntry.path] || []
        rows.push({
          kind: "project",
          remoteId: String(host.id || ""),
          host: host,
          path: remoteEntry.path,
          name: directoryName(remoteEntry.path),
          count: remoteProjectThreads.length + pinnedProjectThreads.length,
          depth: 1
        })
        for (var pinnedThreadIndex = 0;
             pinnedThreadIndex < pinnedProjectThreads.length;
             pinnedThreadIndex++) {
          rows.push({
            kind: "thread",
            remoteId: String(host.id || ""),
            host: host,
            path: remoteEntry.path,
            grouped: true,
            pinnedDetached: true,
            depth: 2,
            thread: pinnedProjectThreads[pinnedThreadIndex]
          })
        }
        if (projectCollapsed(remoteEntry.path, host.id)) return
        var remoteProjectShownCount = groupShowsAll(
          "project", remoteEntry.path, host.id)
          ? remoteProjectThreads.length
          : Math.min(groupPreviewLimit, remoteProjectThreads.length)
        for (var nestedIndex = 0;
             nestedIndex < remoteProjectShownCount;
             nestedIndex++) {
          rows.push({
            kind: "thread",
            remoteId: String(host.id || ""),
            host: host,
            path: remoteEntry.path,
            grouped: true,
            depth: 2,
            thread: remoteProjectThreads[nestedIndex]
          })
        }
        if (remoteProjectShownCount < remoteProjectThreads.length) {
          rows.push({
            kind: "more",
            groupKind: "project",
            groupKey: groupPreviewKey("project", remoteEntry.path, host.id),
            remoteId: String(host.id || ""),
            host: host,
            path: remoteEntry.path,
            depth: 2,
            remaining: remoteProjectThreads.length - remoteProjectShownCount
          })
        }
      }

      var pinnedRemoteProjects = []
      var unpinnedRemoteOrder = []
      for (var splitIndex = 0; splitIndex < remoteOrder.length; splitIndex++) {
        var splitEntry = remoteOrder[splitIndex]
        if (splitEntry.kind === "project"
            && (sectionPinned("project", splitEntry.path, host.id)
              || (remotePinnedGroups[splitEntry.path] || []).length > 0))
          pinnedRemoteProjects.push(splitEntry)
        else
          unpinnedRemoteOrder.push(splitEntry)
      }

      if (searchText !== "" && !hostMatches && matchingThreads.length === 0) continue
      visibleThreads += matchingThreads.length
      for (var remoteProjectCountIndex = 0;
           remoteProjectCountIndex < remoteOrder.length;
           remoteProjectCountIndex++) {
        if (remoteOrder[remoteProjectCountIndex].kind === "project") projects++
      }
      var remoteRows = [{
        kind: "remote",
        remoteId: String(host.id || ""),
        host: host,
        name: String(host.label || host.id || "Remote"),
        count: matchingThreads.length,
        path: String(host.home || "")
      }]
      for (var pinnedIndex = 0;
           pinnedIndex < remotePinnedDirect.length;
           pinnedIndex++) {
        remoteRows.push({
          kind: "thread",
          remoteId: String(host.id || ""),
          host: host,
          path: remotePinnedDirect[pinnedIndex].path,
          grouped: true,
          pinnedDetached: true,
          depth: 1,
          thread: remotePinnedDirect[pinnedIndex].thread
        })
      }
      if (remoteCollapsed(host.id)) {
        for (var pinnedProjectIndex = 0;
             pinnedProjectIndex < pinnedRemoteProjects.length;
             pinnedProjectIndex++) {
          appendRemoteProject(remoteRows, pinnedRemoteProjects[pinnedProjectIndex])
        }
        appendBlock(remoteRows, newestThreadTimestamp(matchingThreads),
          sectionPinned("remote", "", host.id))
        continue
      }

      for (var visiblePinnedProjectIndex = 0;
           visiblePinnedProjectIndex < pinnedRemoteProjects.length;
           visiblePinnedProjectIndex++)
        appendRemoteProject(remoteRows, pinnedRemoteProjects[visiblePinnedProjectIndex])

      var remoteDirectCount = unpinnedRemoteOrder.length
      var remoteShownCount = groupShowsAll("remote", "", host.id)
        ? remoteDirectCount : Math.min(groupPreviewLimit, remoteDirectCount)
      var remoteDirectIndex = 0
      for (var remoteOrderIndex = 0;
           remoteOrderIndex < unpinnedRemoteOrder.length;
           remoteOrderIndex++) {
        var remoteEntry = unpinnedRemoteOrder[remoteOrderIndex]
        if (remoteDirectIndex++ >= remoteShownCount) continue
        if (remoteEntry.kind === "thread") {
          remoteRows.push({
            kind: "thread",
            remoteId: String(host.id || ""),
            host: host,
            path: remoteEntry.path,
            grouped: true,
            depth: 1,
            thread: remoteEntry.thread
          })
          continue
        }
        appendRemoteProject(remoteRows, remoteEntry)
      }
      if (remoteShownCount < remoteDirectCount) {
        remoteRows.push({
          kind: "more",
          groupKind: "remote",
          groupKey: groupPreviewKey("remote", "", host.id),
          remoteId: String(host.id || ""),
          host: host,
          path: String(host.home || ""),
          depth: 1,
          remaining: remoteDirectCount - remoteShownCount
        })
      }
      appendBlock(remoteRows, newestThreadTimestamp(matchingThreads),
        sectionPinned("remote", "", host.id))
    }

    for (var projectIndex = 0; projectIndex < order.length; projectIndex++) {
      var entry = order[projectIndex]
      if (entry.kind === "thread") {
        visibleThreads++
        appendBlock([{
          kind: "thread",
          path: entry.path,
          remoteId: entry.remoteId,
          host: entry.host,
          grouped: false,
          thread: entry.thread
        }], Number(entry.thread && entry.thread.updatedAt || 0))
        continue
      }

      var project = entry.path
      var projectThreads = groups[entry.key]
      projects++
      visibleThreads += projectThreads.length
      var projectRows = [{
        kind: "project",
        path: project,
        remoteId: entry.remoteId,
        host: entry.host,
        name: directoryName(project),
        count: projectThreads.length
      }]
      if (!projectCollapsed(project, entry.remoteId)) {
        var projectShownCount = groupShowsAll("project", project, entry.remoteId)
          ? projectThreads.length : Math.min(groupPreviewLimit, projectThreads.length)
        for (var threadIndex = 0; threadIndex < projectShownCount; threadIndex++) {
          var projectThread = projectThreads[threadIndex]
          projectRows.push({
            kind: "thread",
            path: project,
            remoteId: projectThread.remoteId,
            host: projectThread.host,
            grouped: true,
            depth: entry.remoteId ? 2 : 1,
            thread: projectThread.thread
          })
        }
        if (projectShownCount < projectThreads.length) {
          projectRows.push({
            kind: "more",
            groupKind: "project",
            groupKey: groupPreviewKey("project", project, entry.remoteId),
            path: project,
            remoteId: entry.remoteId,
            host: entry.host,
            depth: entry.remoteId ? 2 : 1,
            remaining: projectThreads.length - projectShownCount
          })
        }
      }
      appendBlock(projectRows, newestThreadTimestamp(projectThreads.map(
        function(projectThreadItem) { return projectThreadItem.thread })),
        sectionPinned("project", project, entry.remoteId))
    }

    blocks.sort(function(a, b) {
      var pinDifference = Number(b.pinned) - Number(a.pinned)
      if (pinDifference !== 0) return pinDifference
      var timestampDifference = b.updatedAt - a.updatedAt
      return timestampDifference !== 0 ? timestampDifference : a.sequence - b.sequence
    })
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++)
      rows = rows.concat(blocks[blockIndex].rows)

    projectCount = projects
    visibleThreadCount = visibleThreads
    viewRows = rows
    var restoredIndex = rowIndexForKey(previousKey)
    selectedIndex = restoredIndex >= 0
      ? restoredIndex
      : Math.max(0, Math.min(selectedIndex, rows.length - 1))
  }

}
