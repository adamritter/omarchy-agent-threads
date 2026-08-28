.pragma library
// Purpose: Provides deterministic Thread List Remote Rows decisions shared by QML adapters.

function buildRemoteBlocks(context, api) {
  var remoteHosts = context.remoteHosts
  var activeProvider = context.activeProvider
  var searchText = context.searchText
  var groupPreviewLimit = context.groupPreviewLimit
  var text = api.text
  var cleanText = api.cleanText
  var hostPath = api.hostPath
  var threadVisible = api.threadVisible
  var sectionPinned = api.sectionPinned
  var newestThreadTimestamp = api.newestThreadTimestamp
  var projectCollapsed = api.projectCollapsed
  var showsAll = api.showsAll
  var groupPreviewKey = api.groupPreviewKey
  var remoteCollapsed = api.remoteCollapsed
  var directoryName = api.directoryName
  var blocks = []
  var projects = 0
  var visibleThreads = 0
  var nextBlockSequence = Number(context.nextBlockSequence || 0)

  function appendBlock(blockRows, updatedAt, pinned) {
    blocks.push({
      rows: blockRows,
      updatedAt: Number(updatedAt || 0),
      pinned: pinned === true,
      sequence: nextBlockSequence++
    })
  }

    for (var hostIndex = 0; hostIndex < remoteHosts.length; hostIndex++) {
      var host = remoteHosts[hostIndex]
      var hostId = text(host && host.id)
      if (hostId === "provider-claude" || hostId === "provider-opencode") continue
      var hostProvider = text(host && host.providerType || "codex").toLowerCase()
      if (hostProvider !== activeProvider) continue
      var remoteGroups = ({})
      var remotePinnedGroups = ({})
      var remoteOrder = []
      var remotePinnedDirect = []
      var matchingThreads = []
      var hostThreads = host && Array.isArray(host.threads) ? host.threads.slice() : []
      hostThreads.sort(function(a, b) {
        var timestampDifference = Number(b && b.updatedAt || 0)
          - Number(a && a.updatedAt || 0)
        if (timestampDifference !== 0) return timestampDifference
        return text(a && a.id).localeCompare(text(b && b.id))
      })
      var hostMatches = cleanText(host && host.label).toLowerCase()
        .indexOf(cleanText(searchText).toLowerCase()) >= 0
      for (var remoteThreadIndex = 0;
           remoteThreadIndex < hostThreads.length;
           remoteThreadIndex++) {
        var remoteThread = hostThreads[remoteThreadIndex]
        var remotePath = hostPath(host, remoteThread)
        if (!hostMatches && !threadVisible(remoteThread, remotePath, searchText)) continue
        matchingThreads.push(remoteThread)
        if (remoteThread.isPinned === true) {
          if (remotePath === "" || remotePath === text(host && host.home)) {
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
        if (remotePath === "" || remotePath === text(host && host.home)) {
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
        var aPinned = a.kind === "project" && sectionPinned("project", a.path, host.id)
        var bPinned = b.kind === "project" && sectionPinned("project", b.path, host.id)
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
        return text(a.path).localeCompare(text(b.path))
      })
  
      function appendRemoteProject(targetRows, remoteEntry) {
        var remoteProjectThreads = remoteGroups[remoteEntry.path] || []
        var pinnedProjectThreads = remotePinnedGroups[remoteEntry.path] || []
        targetRows.push({
          kind: "project", remoteId: text(host.id), host: host,
          path: remoteEntry.path, name: directoryName(remoteEntry.path),
          count: remoteProjectThreads.length + pinnedProjectThreads.length, depth: 1
        })
        for (var pinnedThreadIndex = 0;
             pinnedThreadIndex < pinnedProjectThreads.length;
             pinnedThreadIndex++) {
          targetRows.push({
            kind: "thread", remoteId: text(host.id), host: host,
            path: remoteEntry.path, grouped: true, pinnedDetached: true, depth: 2,
            thread: pinnedProjectThreads[pinnedThreadIndex]
          })
        }
        if (projectCollapsed(remoteEntry.path, host.id)) return
        var remoteProjectShownCount = showsAll("project", remoteEntry.path, host.id)
          ? remoteProjectThreads.length
          : Math.min(groupPreviewLimit, remoteProjectThreads.length)
        for (var nestedIndex = 0; nestedIndex < remoteProjectShownCount; nestedIndex++) {
          targetRows.push({
            kind: "thread", remoteId: text(host.id), host: host,
            path: remoteEntry.path, grouped: true, depth: 2,
            thread: remoteProjectThreads[nestedIndex]
          })
        }
        if (remoteProjectShownCount < remoteProjectThreads.length) {
          targetRows.push({
            kind: "more", groupKind: "project",
            groupKey: groupPreviewKey("project", remoteEntry.path, host.id),
            remoteId: text(host.id), host: host, path: remoteEntry.path, depth: 2,
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
        kind: "remote", remoteId: text(host.id), host: host,
        name: text(host.label || host.id || "Remote"), count: matchingThreads.length,
        path: text(host.home)
      }]
      for (var pinnedIndex = 0; pinnedIndex < remotePinnedDirect.length; pinnedIndex++) {
        remoteRows.push({
          kind: "thread", remoteId: text(host.id), host: host,
          path: remotePinnedDirect[pinnedIndex].path, grouped: true,
          pinnedDetached: true, depth: 1,
          thread: remotePinnedDirect[pinnedIndex].thread
        })
      }
      if (remoteCollapsed(host.id)) {
        for (var pinnedProjectIndex = 0;
             pinnedProjectIndex < pinnedRemoteProjects.length;
             pinnedProjectIndex++)
          appendRemoteProject(remoteRows, pinnedRemoteProjects[pinnedProjectIndex])
        appendBlock(remoteRows, newestThreadTimestamp(matchingThreads),
          sectionPinned("remote", "", host.id))
        continue
      }
  
      for (var visiblePinnedProjectIndex = 0;
           visiblePinnedProjectIndex < pinnedRemoteProjects.length;
           visiblePinnedProjectIndex++)
        appendRemoteProject(remoteRows, pinnedRemoteProjects[visiblePinnedProjectIndex])
  
      var remoteDirectCount = unpinnedRemoteOrder.length
      var remoteShownCount = showsAll("remote", "", host.id)
        ? remoteDirectCount : Math.min(groupPreviewLimit, remoteDirectCount)
      var remoteDirectIndex = 0
      for (var remoteOrderIndex = 0;
           remoteOrderIndex < unpinnedRemoteOrder.length;
           remoteOrderIndex++) {
        var remoteEntry = unpinnedRemoteOrder[remoteOrderIndex]
        if (remoteDirectIndex++ >= remoteShownCount) continue
        if (remoteEntry.kind === "thread") {
          remoteRows.push({
            kind: "thread", remoteId: text(host.id), host: host,
            path: remoteEntry.path, grouped: true, depth: 1,
            thread: remoteEntry.thread
          })
          continue
        }
        appendRemoteProject(remoteRows, remoteEntry)
      }
      if (remoteShownCount < remoteDirectCount) {
        remoteRows.push({
          kind: "more", groupKind: "remote",
          groupKey: groupPreviewKey("remote", "", host.id),
          remoteId: text(host.id), host: host, path: text(host.home), depth: 1,
          remaining: remoteDirectCount - remoteShownCount
        })
      }
      appendBlock(remoteRows, newestThreadTimestamp(matchingThreads),
        sectionPinned("remote", "", host.id))
    }

  return {
    blocks: blocks,
    projectCount: projects,
    visibleThreadCount: visibleThreads,
    nextBlockSequence: nextBlockSequence
  }
}
