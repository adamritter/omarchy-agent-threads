import QtQuick
import "../logic/ActionLogic.js" as ActionLogic

Item {
  required property var provider
  required property var processes
  required property var launches

  function openThread(hostId, thread, path, source) {
    if (!thread || !thread.id || processes.openRunning) return false
    var host = provider.hostById(hostId)
    if (!host) return false
    if (provider.providerTypeForEntry(host) !== "" && host.available === false) {
      provider.controller.launchError = host.error || provider.providerLabel(host) + " is unavailable on this remote"
      return false
    }
    var providerType = provider.providerTypeForEntry(host) || "codex"
    var threadId = String(thread.id)
    var requestId = provider.controller.mutations.beginThreadLaunch(
      threadId, source || (providerType + "-remote"))
    if (requestId === 0) return false
    if (launches.focusCachedThread(threadId, String(hostId || ""))) {
      provider.controller.mutations.observeActiveThread(
        threadId, "cached-remote-" + providerType + "-window")
      return true
    }
    provider.openIsNew = false
    provider.openHostId = String(hostId || "")
    provider.openRequestId = requestId
    provider.openThreadId = threadId
    processes.runOpen(ActionLogic.remoteAgentOpenCommand(
      provider.openHelperPath,
      provider.configPath,
      String(hostId || ""),
      String(path || thread.cwd || ""),
      threadId,
      provider.controller.providers.selectedModelForProvider(providerType),
      provider.controller.providers.selectedEffortForProvider(providerType),
      provider.controller.providers.selectedAgentForProvider(providerType),
      providerType === "codex" ? provider.controller.codexServiceTier : ""))
    return true
  }
  
  function newThread(hostId, path) {
    if (processes.openRunning) return
    var host = provider.hostById(hostId)
    if (!host) return
    if (provider.providerTypeForEntry(host) !== "" && host.available === false) {
      provider.controller.launchError = host.error || provider.providerLabel(host) + " is unavailable on this remote"
      return
    }
    var providerType = provider.providerTypeForEntry(host) || "codex"
    var remotePath = String(path || host.home || "")
    if (remotePath === "") {
      provider.controller.launchError = "The remote home is unknown; set it in the remote settings"
      return
    }
    provider.openIsNew = true
    provider.openHostId = String(hostId || "")
    provider.controller.launchingProjectPath = remotePath
    provider.pendingHostId = String(hostId || "")
    provider.pendingPath = remotePath
    provider.pendingWindowAddress = ""
    provider.pendingAttempts = 24
    provider.pendingKnownIds = ({})
    for (var i = 0; i < host.threads.length; i++) {
      if (host.threads[i] && host.threads[i].id)
        provider.pendingKnownIds[String(host.threads[i].id)] = true
    }
    provider.controller.launchError = ""
    processes.runOpen(ActionLogic.remoteAgentOpenCommand(
      provider.openHelperPath,
      provider.configPath,
      provider.pendingHostId,
      provider.pendingPath,
      "", // new session
      provider.controller.providers.selectedModelForProvider(providerType),
      provider.controller.providers.selectedEffortForProvider(providerType),
      provider.controller.providers.selectedAgentForProvider(providerType),
      providerType === "codex" ? provider.controller.codexServiceTier : ""))
  }
  
  function clearPendingNew() {
    provider.openIsNew = false
    provider.openHostId = ""
    provider.pendingHostId = ""
    provider.pendingPath = ""
    provider.pendingKnownIds = ({})
    provider.pendingWindowAddress = ""
    provider.pendingAttempts = 0
    provider.controller.launchingProjectPath = ""
    provider.stopNewResolveTimer()
  }
  
  function resolvePendingNew(hostId) {
    if (provider.pendingHostId === "" || provider.pendingHostId !== String(hostId || "")
        || provider.pendingWindowAddress === "") return
    var host = provider.hostById(provider.pendingHostId)
    if (!host) return
    for (var i = 0; i < host.threads.length; i++) {
      var thread = host.threads[i]
      var id = String(thread && thread.id || "")
      if (id === "" || provider.pendingKnownIds[id] === true) continue
      if (provider.pathForThread(host, thread) !== provider.pendingPath
          && String(thread.cwd || "") !== provider.pendingPath) continue
      launches.map(id, provider.pendingWindowAddress, provider.pendingHostId, "")
      provider.controller.mutations.observeActiveThread(id, "new-remote-thread")
      clearPendingNew()
      return
    }
  }
}
