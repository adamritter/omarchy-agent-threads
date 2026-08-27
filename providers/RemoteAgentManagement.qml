import QtQuick

Item {
  required property var provider
  required property var processes
  required property var configStore
  required property var registry
  required property var manager

  function threadIndex(items, threadId) {
    var wanted = String(threadId || "")
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") === wanted) return i
    }
    return -1
  }
  
  function threadsWithoutId(items, threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return items.slice()
    var visible = []
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") !== wanted) visible.push(items[i])
    }
    return visible
  }
  
  function configuredRemoteById(hostId) {
    return configStore.configuredById(hostId)
  }
  
  function writeRemoteConfig(remotes) {
    configStore.write(remotes)
  }
  
  function add(label, type, address, home, tokenFile, providerType) {
    return configStore.add(label, type, address, home, tokenFile, providerType)
  }
  
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) {
    return configStore.update(
      hostId, label, type, address, home, tokenFile, providerType)
  }
  
  function removeRemote(hostId) {
    provider.addError = ""
    var id = String(hostId || "")
    if (!configuredRemoteById(id)) {
      provider.addError = "The remote no longer exists"
      return false
    }
    if ((processes.actionRunning && provider.actionHostId === id)
        || (processes.openRunning && provider.openHostId === id) || provider.pendingHostId === id) {
      provider.addError = "Wait for the remote operation to finish"
      return false
    }
    if (provider.loginRunning && provider.loginHostId === id) {
      provider.addError = "Wait for the Claude sign-in terminal to open"
      return false
    }
    if (provider.managementTestRunning && provider.managementTestHostId === id) {
      provider.addError = "Wait for the connection test to finish"
      return false
    }
  
    var configured = provider.remoteConfig.remotes || []
    var next = []
    for (var i = 0; i < configured.length; i++) {
      if (String(configured[i] && configured[i].id || "") !== id)
        next.push(configured[i])
    }
    provider.queryQueue = provider.queryQueue.filter(function(value) { return String(value || "") !== id })
    writeRemoteConfig(next)
    return true
  }
  
  function testRemote(hostId) {
    provider.addError = ""
    var id = String(hostId || "")
    if (!configuredRemoteById(id)) {
      provider.addError = "The remote no longer exists"
      return false
    }
    if (provider.controller.shuttingDown || processes.testRunning) return false
    provider.managementTestHostId = id
    provider.managementTestRunning = true
    provider.managementTestSucceeded = false
    provider.managementTestMessage = "Connecting…"
    processes.runTest([provider.queryHelperPath, provider.configPath, id, "snapshot"])
    return true
  }
  
  function loginClaude(hostId) {
    return manager.login(hostId)
  }
  
  function sshHostEnabled(alias, providerType) {
    var wanted = String(alias || "")
    var normalizedProvider = registry.normalize(providerType)
    var wantedProvider = normalizedProvider === "codex" ? "" : normalizedProvider
    var configured = provider.remoteConfig.remotes || []
    for (var i = 0; i < configured.length; i++) {
      var remote = configured[i] || ({})
      if (remote.type === "ssh" && String(remote.sshHost || "") === wanted
          && provider.providerTypeForEntry(remote) === wantedProvider) return true
    }
    return false
  }
  
  function remoteIdForSshHost(alias, providerType) {
    var wanted = String(alias || "")
    var normalizedProvider = registry.normalize(providerType)
    var wantedProvider = normalizedProvider === "codex" ? "" : normalizedProvider
    var configured = provider.remoteConfig.remotes || []
    for (var i = 0; i < configured.length; i++) {
      var remote = configured[i] || ({})
      if (remote.type === "ssh" && String(remote.sshHost || "") === wanted
          && provider.providerTypeForEntry(remote) === wantedProvider)
        return String(remote.id || "")
    }
    return ""
  }
  
  function refreshSshHosts() {
    if (provider.controller.shuttingDown || processes.sshHostsRunning) return
    provider.sshHostsLoading = true
    provider.sshHostsError = ""
    processes.runSshHosts([provider.sshHostsHelperPath])
  }
  
  function archiveThread(hostId, thread) {
    var id = String(thread && thread.id || "")
    provider.actionHostId = String(hostId || "")
    var host = provider.hostById(provider.actionHostId)
    if (id === "" || !host || processes.actionRunning
        || !provider.controller.mutations.beginThreadMutation("archive", id)) {
      provider.actionHostId = ""
      return false
    }
    provider.actionKind = "archive"
    provider.actionThreadId = id
    provider.archivedThreadId = id
    provider.archivedThreadSnapshot = thread
    provider.archivedThreadIndex = host ? threadIndex(host.threads, id) : -1
    if (host) provider.updateHost(provider.actionHostId, { threads: threadsWithoutId(host.threads, id) })
    processes.runAction([
      provider.queryHelperPath, provider.configPath, provider.actionHostId, "archive", id,
      provider.pathForThread(host, thread)
    ])
    return true
  }
  
  function renameThread(hostId, thread, name) {
    var id = String(thread && thread.id || "")
    provider.actionHostId = String(hostId || "")
    var host = provider.hostById(provider.actionHostId)
    if (id === "" || !host || processes.actionRunning
        || !provider.controller.mutations.beginThreadMutation("rename", id)) {
      provider.actionHostId = ""
      return false
    }
    provider.actionKind = "rename"
    provider.actionThreadId = id
    processes.runAction([
      provider.queryHelperPath, provider.configPath, provider.actionHostId, "rename", id,
      provider.pathForThread(host, thread), name
    ])
    return true
  }
  
  function toggleThreadPin(hostId, thread) {
    var id = String(thread && thread.id || "")
    provider.actionHostId = String(hostId || "")
    if (id === "" || !provider.hostById(provider.actionHostId) || processes.actionRunning
        || !provider.controller.mutations.beginThreadMutation("pin", id)) {
      provider.actionHostId = ""
      return false
    }
    provider.actionKind = "pin"
    provider.actionThreadId = id
    provider.actionPinValue = thread.isPinned !== true
    provider.controller.mutations.setPendingPinValue(provider.actionPinValue)
    processes.runAction([
      provider.queryHelperPath,
      provider.configPath,
      provider.actionHostId,
      "pin",
      id,
      provider.actionPinValue ? "true" : "false"
    ])
    return true
  }
  
  function applyThreadPin(hostId, threadId, pinned, returnedThread) {
    var host = provider.hostById(hostId)
    if (!host) return
    var next = []
    for (var i = 0; i < host.threads.length; i++) {
      var thread = host.threads[i]
      next.push(String(thread && thread.id || "") === String(threadId || "")
        ? Object.assign({}, thread, returnedThread || ({}), { isPinned: !!pinned })
        : thread)
    }
    provider.updateHost(hostId, { threads: next })
  }
  
  function restoreArchivedThread(hostId) {
    var host = provider.hostById(hostId)
    if (host && provider.archivedThreadSnapshot && threadIndex(host.threads, provider.archivedThreadId) < 0) {
      var restored = host.threads.slice()
      var index = Math.max(0, Math.min(provider.archivedThreadIndex, restored.length))
      restored.splice(index, 0, provider.archivedThreadSnapshot)
      provider.updateHost(hostId, { threads: restored })
    }
    provider.archivedThreadId = ""
    provider.archivedThreadSnapshot = null
    provider.archivedThreadIndex = -1
  }
  
}
