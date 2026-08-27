function text(value) {
  return String(value || "")
}

function cleanText(value) {
  return text(value).replace(/\s+/g, " ").trim()
}

function directoryName(path) {
  var value = text(path)
  if (value === "") return "Unknown folder"
  var parts = value.replace(/\/$/, "").split("/")
  return parts.length > 0 && parts[parts.length - 1] !== ""
    ? parts[parts.length - 1] : value
}

function providerHost(hosts, providerId) {
  var wanted = text(providerId).toLowerCase()
  var items = Array.isArray(hosts) ? hosts : []
  var fallback = null
  for (var i = 0; i < items.length; i++) {
    if (text(items[i] && items[i].providerType).toLowerCase() !== wanted) continue
    if (text(items[i] && items[i].id) === "provider-" + wanted) return items[i]
    if (!fallback) fallback = items[i]
  }
  return fallback
}

function projectRoot(project) {
  if (!project || !Array.isArray(project.roots) || project.roots.length === 0)
    return ""
  return text(project.roots[0] && project.roots[0].path)
}

function projectForId(projects, projectId) {
  var wanted = text(projectId)
  var items = Array.isArray(projects) ? projects : []
  for (var i = 0; i < items.length; i++) {
    if (text(items[i] && items[i].id) === wanted) return items[i]
  }
  return null
}

function projectForRoot(projects, path) {
  var wanted = text(path)
  var items = Array.isArray(projects) ? projects : []
  for (var i = 0; i < items.length; i++) {
    if (projectRoot(items[i]) === wanted) return items[i]
  }
  return null
}

function pathForThread(projects, thread, fallbackHome, preferThreadCwd) {
  var cwd = text(thread && thread.cwd)
  if (preferThreadCwd && cwd !== "") return cwd
  var root = projectRoot(projectForId(projects, thread && thread.projectId))
  if (root !== "") return root
  return cwd !== "" ? cwd : text(fallbackHome)
}

function isProjectPath(path, homePath, workPath, scratchRoot) {
  var value = text(path)
  var scratch = text(scratchRoot)
  return value !== "" && value !== text(homePath)
    && value !== text(workPath)
    && (scratch === "" || value.indexOf(scratch) !== 0)
}

function rowKey(row) {
  if (!row) return ""
  if (row.kind === "remote") return "remote:" + text(row.remoteId)
  if (row.kind === "project")
    return "project:" + text(row.remoteId || "local") + ":" + text(row.path)
  if (row.kind === "more") return "more:" + text(row.groupKey)
  return "thread:" + text(row.remoteId || "local") + ":"
    + text(row.thread && row.thread.id)
}

function rowIndexForKey(rows, key) {
  var wanted = text(key)
  var items = Array.isArray(rows) ? rows : []
  for (var i = 0; i < items.length; i++) {
    if (rowKey(items[i]) === wanted) return i
  }
  return -1
}

function groupPreviewKey(kind, path, remoteId) {
  return kind === "remote"
    ? "remote:" + text(remoteId)
    : "project:" + text(remoteId || "local") + ":" + text(path)
}

function projectCollapseKey(path, remoteId) {
  return text(remoteId || "local") + ":" + text(path)
}

function sectionPinKey(kind, path, remoteId) {
  return kind === "remote"
    ? "remote:" + text(remoteId)
    : "project:" + projectCollapseKey(path, remoteId)
}

function threadSearchTitle(thread) {
  var name = cleanText(thread && thread.name)
  if (name !== "") return name
  return cleanText(text(thread && thread.preview).split(/\r?\n/)[0])
}

function threadVisible(thread, path, searchText) {
  var query = cleanText(searchText).toLowerCase()
  if (query === "") return true
  var haystack = [threadSearchTitle(thread), directoryName(path)].join(" ").toLowerCase()
  var terms = query.split(" ")
  for (var i = 0; i < terms.length; i++) {
    if (terms[i] !== "" && haystack.indexOf(terms[i]) < 0) return false
  }
  return true
}

function projectMoveTargets(projects, threads, currentThread, options) {
  var settings = options && typeof options === "object" ? options : ({})
  var currentPath = pathForThread(
    projects, currentThread, settings.homePath, false)
  var seen = ({})
  var targets = []

  function append(path, name) {
    var value = text(path)
    if (value === "" || value === currentPath || seen[value]
        || !isProjectPath(value, settings.homePath,
          settings.workPath, settings.scratchRoot)) return
    seen[value] = true
    targets.push({ path: value, name: text(name) || directoryName(value) })
  }

  var projectItems = Array.isArray(projects) ? projects : []
  for (var projectIndex = 0; projectIndex < projectItems.length; projectIndex++)
    append(projectRoot(projectItems[projectIndex]), projectItems[projectIndex].name)

  var threadItems = Array.isArray(threads) ? threads : []
  for (var threadIndex = 0; threadIndex < threadItems.length; threadIndex++) {
    var path = pathForThread(projectItems, threadItems[threadIndex],
      settings.homePath, false)
    append(path, directoryName(path))
  }

  targets.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return targets
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
