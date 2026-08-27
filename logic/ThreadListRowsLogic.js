.pragma library
.import "ThreadListBaseLogic.js" as Base
.import "ThreadListRemoteRowsLogic.js" as RemoteRows

function text(value) { return Base.text(value) }
function cleanText(value) { return Base.cleanText(value) }
function directoryName(path) { return Base.directoryName(path) }
function providerHost(hosts, providerId) { return Base.providerHost(hosts, providerId) }
function pathForThread(projects, thread, fallbackHome, preferThreadCwd) {
  return Base.pathForThread(projects, thread, fallbackHome, preferThreadCwd)
}
function isProjectPath(path, homePath, workPath, scratchRoot) {
  return Base.isProjectPath(path, homePath, workPath, scratchRoot)
}
function groupPreviewKey(kind, path, remoteId) {
  return Base.groupPreviewKey(kind, path, remoteId)
}
function projectCollapseKey(path, remoteId) {
  return Base.projectCollapseKey(path, remoteId)
}
function sectionPinKey(kind, path, remoteId) {
  return Base.sectionPinKey(kind, path, remoteId)
}
function threadVisible(thread, path, searchText) {
  return Base.threadVisible(thread, path, searchText)
}

function buildRows(input) {
  var options = input && typeof input === "object" ? input : ({})
  var activeProvider = text(options.activeProvider || "codex")
  var searchText = text(options.searchText)
  var groupPreviewLimit = Math.max(1, Number(options.groupPreviewLimit || 10))
  var localThreads = Array.isArray(options.localThreads) ? options.localThreads : []
  var localProjects = Array.isArray(options.localProjects) ? options.localProjects : []
  var remoteHosts = Array.isArray(options.remoteHosts) ? options.remoteHosts : []
  var expandedGroups = options.expandedGroups || ({})
  var collapsedProjects = options.collapsedProjects || ({})
  var collapsedRemotes = options.collapsedRemotes || ({})
  var pinnedSections = options.pinnedSections || ({})

  function showsAll(kind, path, remoteId) {
    return expandedGroups[groupPreviewKey(kind, path, remoteId)] === true
  }

  function sectionPinned(kind, path, remoteId) {
    return pinnedSections[sectionPinKey(kind, path, remoteId)] === true
  }

  function projectCollapsed(path, remoteId) {
    return collapsedProjects[projectCollapseKey(path, remoteId)] !== false
  }

  function remoteCollapsed(remoteId) {
    return collapsedRemotes[text(remoteId)] !== false
  }

  function localPath(thread) {
    return pathForThread(localProjects, thread, options.homePath, false)
      || text(options.homePath)
  }

  function hostPath(host, thread) {
    return pathForThread(host && host.projects, thread, host && host.home,
      text(host && host.id).indexOf("provider-") === 0)
  }

  function validProjectPath(path) {
    return isProjectPath(path, options.homePath, options.workPath, options.scratchRoot)
  }

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
    if (!threadVisible(thread, path, searchText)) return
    var scope = text(remoteId)
    var item = { thread: thread, path: path, remoteId: scope, host: host || null }
    if (thread.isPinned === true) {
      pinnedRows.push({
        kind: "thread", path: path, remoteId: scope, host: host || null,
        grouped: false, pinnedDetached: true, thread: thread
      })
      return
    }
    if (!validProjectPath(path)) {
      order.push({
        kind: "thread", path: path, remoteId: scope, host: host || null,
        thread: thread
      })
      return
    }
    var key = text(scope || "local") + ":" + path
    if (!groups[key]) {
      groups[key] = []
      order.push({
        kind: "project", key: key, path: path, remoteId: scope,
        host: host || null
      })
    }
    groups[key].push(item)
  }

  if (activeProvider === "codex") {
    for (var localIndex = 0; localIndex < localThreads.length; localIndex++)
      appendFlatThread(localThreads[localIndex], localPath(localThreads[localIndex]), "", null)
  } else {
    var selectedHost = providerHost(remoteHosts, activeProvider)
    var providerThreads = selectedHost && Array.isArray(selectedHost.threads)
      ? selectedHost.threads : []
    for (var providerIndex = 0; providerIndex < providerThreads.length; providerIndex++) {
      var providerThread = providerThreads[providerIndex]
      appendFlatThread(providerThread, hostPath(selectedHost, providerThread),
        text(selectedHost && selectedHost.id), selectedHost)
    }
  }

  var rows = pinnedRows.slice()
  var projects = 0
  var visibleThreads = pinnedRows.length

  var remoteResult = RemoteRows.buildRemoteBlocks({
    remoteHosts: remoteHosts,
    activeProvider: activeProvider,
    searchText: searchText,
    groupPreviewLimit: groupPreviewLimit,
    nextBlockSequence: nextBlockSequence
  }, {
    text: text,
    cleanText: cleanText,
    hostPath: hostPath,
    threadVisible: threadVisible,
    sectionPinned: sectionPinned,
    newestThreadTimestamp: newestThreadTimestamp,
    projectCollapsed: projectCollapsed,
    showsAll: showsAll,
    groupPreviewKey: groupPreviewKey,
    remoteCollapsed: remoteCollapsed,
    directoryName: directoryName
  })
  blocks = blocks.concat(remoteResult.blocks)
  projects += remoteResult.projectCount
  visibleThreads += remoteResult.visibleThreadCount
  nextBlockSequence = remoteResult.nextBlockSequence


  for (var projectIndex = 0; projectIndex < order.length; projectIndex++) {
    var entry = order[projectIndex]
    if (entry.kind === "thread") {
      visibleThreads++
      appendBlock([{
        kind: "thread", path: entry.path, remoteId: entry.remoteId,
        host: entry.host, grouped: false, thread: entry.thread
      }], Number(entry.thread && entry.thread.updatedAt || 0))
      continue
    }

    var project = entry.path
    var projectThreads = groups[entry.key]
    projects++
    visibleThreads += projectThreads.length
    var projectRows = [{
      kind: "project", path: project, remoteId: entry.remoteId,
      host: entry.host, name: directoryName(project), count: projectThreads.length
    }]
    if (!projectCollapsed(project, entry.remoteId)) {
      var projectShownCount = showsAll("project", project, entry.remoteId)
        ? projectThreads.length : Math.min(groupPreviewLimit, projectThreads.length)
      for (var threadIndex = 0; threadIndex < projectShownCount; threadIndex++) {
        var projectThread = projectThreads[threadIndex]
        projectRows.push({
          kind: "thread", path: project, remoteId: projectThread.remoteId,
          host: projectThread.host, grouped: true,
          depth: entry.remoteId ? 2 : 1, thread: projectThread.thread
        })
      }
      if (projectShownCount < projectThreads.length) {
        projectRows.push({
          kind: "more", groupKind: "project",
          groupKey: groupPreviewKey("project", project, entry.remoteId),
          path: project, remoteId: entry.remoteId, host: entry.host,
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

  return { rows: rows, projectCount: projects, visibleThreadCount: visibleThreads }
}
