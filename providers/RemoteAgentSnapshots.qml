import QtQuick
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

Item {
  id: root
  required property var provider
  required property var processes
  required property var configStore
  required property var registry

  function providerTypeForEntry(entry) {
    return registry.typeForEntry(entry)
  }
  
  function providerLabel(host) {
    return registry.adapterForEntry(host).label
  }
  
  function hostById(hostId) {
    var wanted = String(hostId || "")
    for (var i = 0; i < provider.remoteHosts.length; i++) {
      if (String(provider.remoteHosts[i].id || "") === wanted) return provider.remoteHosts[i]
    }
    return null
  }
  
  function updateHost(hostId, patch) {
    var wanted = String(hostId || "")
    var next = []
    for (var i = 0; i < provider.remoteHosts.length; i++) {
      var host = provider.remoteHosts[i]
      next.push(String(host.id || "") === wanted ? Object.assign({}, host, patch) : host)
    }
    provider.remoteHosts = next
  }
  
  function restoreSnapshots(snapshots) {
    provider.remoteHosts = ProviderSnapshotLogic.hydratedHosts(snapshots)
    // If the config read won the startup race, reapply it over the cached data.
    // This keeps current connection settings authoritative and removes stale hosts.
    if (provider.configLoaded) configStore.load(JSON.stringify(configStore.config))
  }
  
  function projectForId(host, projectId) {
    var wanted = String(projectId || "")
    var items = host && Array.isArray(host.projects) ? host.projects : []
    for (var i = 0; i < items.length; i++) {
      if (String(items[i].id || "") === wanted) return items[i]
    }
    return null
  }
  
  function projectRoot(project) {
    if (!project || !project.roots || project.roots.length === 0) return ""
    return String(project.roots[0].path || "")
  }
  
  function pathForThread(host, thread) {
    var project = projectForId(host, thread ? thread.projectId : "")
    var rootPath = projectRoot(project)
    return rootPath !== "" ? rootPath : String(thread && thread.cwd || host && host.home || "")
  }
  
  function threadStatus(thread) {
    var status = thread ? thread.status : null
    var flags = status && Array.isArray(status.activeFlags)
      ? status.activeFlags : []
    if (flags.indexOf("waitingOnApproval") >= 0
        || flags.indexOf("waitingOnUserInput") >= 0)
      return "blocked"
    var type = typeof status === "string" ? status : String(status && status.type || "")
    return type === "active" ? "busy" : "done"
  }
  
  function mergeUnread(host, nextThreads) {
    return ThreadStateLogic.mergeProviderUnread(
      host && host.threads, nextThreads, provider.controller.activeThreadId)
  }
  
  function markThreadSeen(threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return
    for (var hostIndex = 0; hostIndex < provider.remoteHosts.length; hostIndex++) {
      var host = provider.remoteHosts[hostIndex]
      var threads = host.threads || []
      var changed = false
      var next = []
      for (var threadIndex = 0; threadIndex < threads.length; threadIndex++) {
        var thread = threads[threadIndex]
        if (String(thread && thread.id || "") === wanted && thread.unread === true) {
          next.push(Object.assign({}, thread, { unread: false }))
          changed = true
        } else next.push(thread)
      }
      if (changed) updateHost(host.id, { threads: next })
    }
  }
  
  function refresh(hostId) {
    if (!provider.configLoaded) return
    var wanted = String(hostId || "")
    var queue = provider.queryQueue.slice()
    function append(id) {
      if (id === provider.queryHostId || queue.indexOf(id) >= 0) return
      queue.push(id)
      var host = hostById(id)
      updateHost(id, { loading: !(host && host.loaded === true) })
    }
    if (wanted !== "") append(wanted)
    else for (var i = 0; i < provider.remoteHosts.length; i++) append(String(provider.remoteHosts[i].id || ""))
    provider.queryQueue = queue
    startNextQuery()
  }
  
  function refreshVisibleProvider() {
    if (!provider.controller.sidebarOpen) {
      refresh()
      return
    }
    var selected = String(provider.controller.selectedProvider || "codex").toLowerCase()
    for (var i = 0; i < provider.remoteHosts.length; i++) {
      var hostProvider = providerTypeForEntry(provider.remoteHosts[i]) || "codex"
      if (hostProvider === selected) refresh(provider.remoteHosts[i].id)
    }
  }
  
  function startNextQuery() {
    if (provider.controller.shuttingDown || processes.queryRunning
        || provider.queryQueue.length === 0) return
    var queue = provider.queryQueue.slice()
    provider.queryHostId = String(queue.shift() || "")
    provider.queryQueue = queue
    if (provider.queryHostId === "" || !hostById(provider.queryHostId)) {
      provider.queryHostId = ""
      Qt.callLater(root.startNextQuery)
      return
    }
    processes.runQuery([
      provider.queryHelperPath, provider.configPath, provider.queryHostId, "snapshot"])
  }
  
  function applySnapshot(snapshot) {
    var hostId = String(snapshot && snapshot.hostId || "")
    if (hostId === "") return
    var existing = hostById(hostId)
    if (!existing) return
    var snapshotThreads = Array.isArray(snapshot.threads) ? snapshot.threads : []
    var hiddenArchiveId = hostId === provider.actionHostId ? provider.archivedThreadId
      : (hostId === provider.archiveConfirmationHostId ? provider.archiveConfirmationThreadId : "")
    var visibleThreads = provider.threadsWithoutId(snapshotThreads, hiddenArchiveId)
    updateHost(hostId, {
      home: String(snapshot.home || existing.home || ""),
      providerType: providerTypeForEntry(snapshot),
      threads: mergeUnread(existing, visibleThreads),
      projects: Array.isArray(snapshot.projects) ? snapshot.projects : [],
      projectDefaults: snapshot.projectDefaults && typeof snapshot.projectDefaults === "object"
        ? snapshot.projectDefaults : ({}),
      projectAgents: snapshot.projectAgents && typeof snapshot.projectAgents === "object"
        ? snapshot.projectAgents : ({}),
      models: Array.isArray(snapshot.models) ? snapshot.models : [],
      agents: Array.isArray(snapshot.agents) ? snapshot.agents : [],
      defaultModel: String(snapshot.defaultModel || ""),
      defaultEffort: String(snapshot.defaultEffort || ""),
      defaultAgent: String(snapshot.defaultAgent || ""),
      available: snapshot.available !== false,
      authenticated: snapshot.authenticated !== false,
      version: String(snapshot.version || ""),
      subscriptionType: String(snapshot.subscriptionType || ""),
      rateLimits: snapshot.rateLimits && typeof snapshot.rateLimits === "object"
        ? snapshot.rateLimits : ({}),
      loaded: true,
      loading: false,
      error: String(snapshot.error || "")
    })
    if (hostId === provider.archiveConfirmationHostId) {
      provider.archiveConfirmationHostId = ""
      provider.archiveConfirmationThreadId = ""
    }
    provider.resolvePendingNew(hostId)
  }
  
}
