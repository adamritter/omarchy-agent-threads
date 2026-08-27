import QtQuick

Item {
  required property var appServerClient
  required property var localCodexProvider
  required property var localRegistry
  required property var remoteProvider

  function reset() { appServerClient.reset() }
  function start() { appServerClient.start() }
  function refreshThreads() { appServerClient.refreshThreads() }
  function refreshProjects() { appServerClient.refreshProjects() }
  function refreshRateLimits() { appServerClient.refreshRateLimits() }
  function refreshModels() { appServerClient.refreshModels() }
  function refreshConfig() { appServerClient.refreshConfig() }
  function createProject(threadId, name, path) {
    return appServerClient.createProject(threadId, name, path)
  }
  function moveThread(threadId, projectId) {
    return appServerClient.moveThread(threadId, projectId)
  }
  function clearMoveRequests() { appServerClient.clearMoveRequests() }
  function archiveLocalCodexRpc(threadId) { return appServerClient.archiveThread(threadId) }
  function renameLocalCodexRpc(threadId, name) {
    return appServerClient.renameThread(threadId, name)
  }
  function pinLocalCodexRpc(threadId, pinned, sectionId) {
    return appServerClient.setThreadPinned(threadId, pinned, sectionId)
  }
  function clearPendingLocalCodexThread() { localCodexProvider.clearPendingNew() }
  function resolvePendingLocalCodexThread() { localCodexProvider.resolvePendingNew() }
  function refreshActiveThread() { localCodexProvider.refreshActiveThread() }
  
  function snapshotLocalProviders() { return localRegistry.snapshotHosts() }
  function restoreLocalProviders(snapshots) { localRegistry.restoreSnapshots(snapshots) }
  function restoreRemoteHosts(snapshots) { remoteProvider.restoreSnapshots(snapshots) }
  
  function addRemote(label, type, address, home, tokenFile, providerType) {
    return remoteProvider.add(label, type, address, home, tokenFile, providerType)
  }
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) {
    return remoteProvider.updateRemote(
      hostId, label, type, address, home, tokenFile, providerType)
  }
  function removeRemote(hostId) { return remoteProvider.removeRemote(hostId) }
  function testRemote(hostId) { return remoteProvider.testRemote(hostId) }
  function loginRemoteClaude(hostId) { return remoteProvider.loginClaude(hostId) }
  function sshHostEnabled(alias, providerType) {
    return remoteProvider.sshHostEnabled(alias, providerType)
  }
  function remoteIdForSshHost(alias, providerType) {
    return remoteProvider.remoteIdForSshHost(alias, providerType)
  }
  function refreshSshHosts() { remoteProvider.refreshSshHosts() }
}
