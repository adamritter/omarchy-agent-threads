import QtQuick
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

QtObject {
  required property var store
  required property var appServer
  required property var routing
  required property var localProviders
  required property var remotes
  required property var supplementalHosts
  required property var configuredRemoteHosts
  required property string actionHostId
  required property var preferences
  required property var snapshots

  readonly property bool ready: appServer.ready
  readonly property bool loading: appServer.loading
  readonly property bool refreshQueued: appServer.refreshQueued
  readonly property double lastRefreshMs: appServer.lastRefreshMs
  readonly property bool remoteConfigLoaded: remotes.configLoaded
  readonly property var remoteConfig: remotes.remoteConfig
  readonly property var remoteHosts: supplementalHosts
  readonly property string remoteQueryHostId: remotes.queryHostId
  readonly property string remoteActionHostId: actionHostId
  readonly property string remoteAddError: remotes.addError
  readonly property string remoteTestHostId: remotes.managementTestHostId
  readonly property bool remoteTestRunning: remotes.managementTestRunning
  readonly property bool remoteTestSucceeded: remotes.managementTestSucceeded
  readonly property string remoteTestMessage: remotes.managementTestMessage
  readonly property string remoteClaudeLoginHostId: remotes.loginHostId
  readonly property bool remoteClaudeLoginRunning: remotes.loginRunning
  readonly property var sshHosts: remotes.sshHosts
  readonly property bool sshHostsLoading: remotes.sshHostsLoading
  readonly property string sshHostsError: remotes.sshHostsError
  readonly property bool snapshotLoaded: snapshots.loaded
  readonly property bool snapshotRestored: snapshots.restored
  readonly property bool snapshotHydrating: snapshots.hydrating
  readonly property string snapshot: snapshots.encoded

  function clearRemoteError() {
    remotes.addError = ""
  }

  function providerSnapshotObject() {
    return {
      codex: {
        threads: store.threads,
        projects: store.projects,
        rateLimits: store.rateLimits,
        rateLimitResetCredits: store.rateLimitResetCredits,
        models: store.models,
        codexConfig: store.codexConfig,
        threadStatuses: store.threadStatuses,
        unreadThreads: store.unreadThreads,
        activeThreadId: store.activeThreadId
      },
      remoteHosts: configuredRemoteHosts,
      localProviders: localProviders.snapshotHosts()
    }
  }
  
  function scheduleProviderSnapshot() {
    if (store.shuttingDown) return
    snapshots.schedule(providerSnapshotObject())
  }
  
  function flushProviderSnapshot() {
    snapshots.flush(providerSnapshotObject())
  }
  
  function attachProviderSnapshot(snapshot) {
    snapshots.attach(snapshot)
  }
  
  function restoreProviderSnapshot(snapshot) {
    if (!snapshot) return
    var codex = ProviderSnapshotLogic.codexState(snapshot)
    store.threads = codex.threads
    store.projects = codex.projects
    store.rateLimits = codex.rateLimits
    store.rateLimitResetCredits = codex.rateLimitResetCredits
    store.models = codex.models
    store.codexConfig = codex.codexConfig
    store.threadStatuses = codex.threadStatuses
    store.unreadThreads = codex.unreadThreads
    store.activeThreadId = codex.activeThreadId
    remotes.restoreSnapshots(snapshot.remoteHosts)
    localProviders.restoreSnapshots(snapshot.localProviders)
  }
  
  function resetBackendState() {
    if (store.threadLaunchPhase === "launching")
      store.mutations.failThreadLaunch(store.threadLaunchRequestId, "The provider stopped during thread launch")
    appServer.reset()
  }
  
  function startAppServer() {
    appServer.start()
  }
  
  function remoteHostById(hostId) {
    return routing.hostById(hostId)
  }
  
  function remotePathForThread(host, thread) {
    return routing.pathForThread(host ? host.id : "", thread)
  }
  
  function remoteThreadStatus(thread) {
    var provider = localAgentProviderForThread(thread)
    var hostId = provider ? provider.hostId : ""
    return routing.threadStatus(hostId, thread)
  }
  
  function refreshRemotes(hostId) {
    routing.refreshSupplementalHosts(hostId)
  }
  
  function localAgentProvider(hostId) {
    return routing.localProviderForHost(hostId)
  }
  
  function localAgentProviderForThread(thread) {
    return routing.localProviderForThread(thread)
  }
  
  function addRemote(label, type, address, home, tokenFile, providerType) {
    return remotes.add(label, type, address, home, tokenFile, providerType)
  }
  
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) {
    return remotes.updateRemote(
      hostId, label, type, address, home, tokenFile, providerType)
  }
  
  function removeRemote(hostId) {
    return remotes.removeRemote(hostId)
  }
  
  function testRemote(hostId) {
    return remotes.testRemote(hostId)
  }
  
  function loginRemoteClaude(hostId) {
    return remotes.loginClaude(hostId)
  }
  
  function sshHostEnabled(alias, providerType) {
    return remotes.sshHostEnabled(alias, providerType)
  }
  
  function remoteIdForSshHost(alias, providerType) {
    return remotes.remoteIdForSshHost(alias, providerType)
  }
  
  function refreshSshHosts() {
    remotes.refreshSshHosts()
  }
  
  function archiveRemoteThread(hostId, thread) {
    return !!routing.archiveThread(hostId, thread)
  }
  
  function renameRemoteThread(hostId, thread, name) {
    var normalized = String(name || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (normalized === "") return false
    var started = routing.renameThread(hostId, thread, normalized)
    if (!started && store.errorText === "")
      store.errorText = "Could not start the thread rename"
    return !!started
  }
  
  function toggleRemoteThreadPin(hostId, thread) {
    return !!routing.toggleThreadPin(hostId, thread)
  }
  
  function openRemoteThread(hostId, thread, path, source) {
    return !!routing.openThread(hostId, thread, path, source)
  }
  
  function newRemoteThread(hostId, path) {
    routing.createThread(hostId, path)
  }
  
  function openTerminal(mode, endpoint, path) {
    if (!store.runtimeProcesses || store.runtimeProcesses.terminalRunning) return false
    store.launchError = ""
    return store.runtimeProcesses.startTerminal([
      store.streamGuardPath,
      "--",
      store.terminalOpenHelperPath,
      String(mode || ""),
      String(endpoint || ""),
      String(path || "")
    ])
  }
  
  function refreshThreads() {
    appServer.refreshThreads()
  }
  
  function threadIsPinned(thread) {
    return ThreadStateLogic.threadIsPinned(thread, store.pinnedSectionId)
  }
  
  function normalizePinnedThreads(items) {
    return ThreadStateLogic.normalizePinnedThreads(items, store.pinnedSectionId)
  }
  
  function refreshProjects() {
    appServer.refreshProjects()
  }
  
  function refreshRateLimits() {
    appServer.refreshRateLimits()
  }
  
  function refreshModels() {
    appServer.refreshModels()
  }
  
  function refreshConfig() {
    appServer.refreshConfig()
  }
  
}
