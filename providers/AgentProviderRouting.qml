import QtQuick
import "../logic/AgentProviderLogic.js" as AgentProviderLogic

Item {
  required property var controller
  required property var appServerClient
  required property var localRegistry
  required property var remoteProvider
  required property var localCodexProvider
  required property var allHosts

  function normalizeProviderType(value) {
    return AgentProviderLogic.providerType(value)
  }
  
  function hostById(hostId) {
    return AgentProviderLogic.hostById(allHosts, hostId)
  }
  
  function isLocalCodex(hostId) {
    return AgentProviderLogic.isLocalCodexHost(hostId)
  }
  
  function localProviderForHost(hostId) {
    return localRegistry.providerForHost(hostId)
  }
  
  function localProviderForThread(thread) {
    return localRegistry.providerForThread(thread)
  }
  
  function pathForThread(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.threadActions.projectPathForThread(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.pathForThread(thread)
    return remoteProvider.pathForThread(remoteProvider.hostById(hostId), thread)
  }
  
  function threadStatus(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.threadActions.threadStatus(thread ? thread.id : "")
    var local = localProviderForHost(hostId)
    if (local) return local.threadStatus(thread)
    return remoteProvider.threadStatus(thread)
  }
  
  function refreshHost(hostId) {
    if (isLocalCodex(hostId)) {
      appServerClient.refreshThreads()
      return
    }
    var local = localProviderForHost(hostId)
    if (local) local.refresh()
    else remoteProvider.refresh(hostId)
  }
  
  function refreshSupplementalHosts(hostId) {
    var id = String(hostId || "")
    if (id !== "") {
      refreshHost(id)
      return
    }
    remoteProvider.refresh()
    for (var i = 0; i < localRegistry.hosts.length; i++)
      refreshHost(String(localRegistry.hosts[i].id || ""))
  }
  
  function markSupplementalThreadSeen(threadId) {
    localRegistry.markThreadSeen(threadId)
    remoteProvider.markThreadSeen(threadId)
  }
  
  function archiveThread(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.threadActions.archiveLocalCodexThread(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.archiveThread(thread)
    return remoteProvider.archiveThread(hostId, thread)
  }
  
  function renameThread(hostId, thread, name) {
    if (isLocalCodex(hostId)) return controller.threadActions.renameLocalCodexThread(thread, name)
    var local = localProviderForHost(hostId)
    if (local) return local.renameThread(thread, name)
    return remoteProvider.renameThread(hostId, thread, name)
  }
  
  function toggleThreadPin(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.threadActions.toggleLocalCodexThreadPin(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.toggleThreadPin(thread)
    return remoteProvider.toggleThreadPin(hostId, thread)
  }
  
  function openThread(hostId, thread, path, source) {
    if (isLocalCodex(hostId))
      return localCodexProvider.openThread(thread, path, source)
    var local = localProviderForHost(hostId)
    if (local) return local.openThread(thread, path, source)
    return remoteProvider.openThread(hostId, thread, path, source)
  }
  
  function createThread(hostId, path) {
    if (isLocalCodex(hostId)) return localCodexProvider.newThread(path)
    var local = localProviderForHost(hostId)
    if (local) return local.newThread(path)
    return remoteProvider.newThread(hostId, path)
  }
}
