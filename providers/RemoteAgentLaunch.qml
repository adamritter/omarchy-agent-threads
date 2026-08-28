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
    launches.state.trackOpen(requestId, threadId, hostId)
    processes.runOpen(ActionLogic.remoteAgentOpenCommand(
      provider.openHelperPath,
      provider.configPath,
      String(hostId || ""),
      String(path || thread.cwd || ""),
      threadId,
      provider.controller.settings.selectedModelForProvider(providerType),
      provider.controller.settings.selectedEffortForProvider(providerType),
      provider.controller.settings.selectedAgentForProvider(providerType),
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
    provider.controller.launchingProjectPath = remotePath
    launches.state.beginPending(host.threads, remotePath, hostId, 24)
    provider.controller.launchError = ""
    processes.runOpen(ActionLogic.remoteAgentOpenCommand(
      provider.openHelperPath,
      provider.configPath,
      launches.state.pendingHostId,
      launches.state.pendingPath,
      "", // new session
      provider.controller.settings.selectedModelForProvider(providerType),
      provider.controller.settings.selectedEffortForProvider(providerType),
      provider.controller.settings.selectedAgentForProvider(providerType),
      providerType === "codex" ? provider.controller.codexServiceTier : ""))
  }
  
  function clearPendingNew() {
    launches.state.clearPending()
    provider.controller.launchingProjectPath = ""
    provider.stopNewResolveTimer()
  }
  
  function resolvePendingNew(hostId) {
    if (!launches.state.pending
        || launches.state.pendingHostId !== String(hostId || "")
        || launches.state.pendingWindowAddress === "") return
    var host = provider.hostById(launches.state.pendingHostId)
    if (!host) return
    var id = launches.state.discoverPendingThread(host.threads,
      function(thread) { return provider.pathForThread(host, thread) })
    if (id === "") return
    launches.map(id, launches.state.pendingWindowAddress,
      launches.state.pendingHostId, launches.state.pendingServerUrl)
    provider.controller.mutations.observeActiveThread(id, "new-remote-thread")
    clearPendingNew()
  }
}
