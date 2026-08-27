import QtQuick
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

QtObject {
  required property var store
  required property var providerLibrary
  required property var preferences
  required property var snapshots

  readonly property bool ready: providerLibrary.ready
  readonly property bool loading: providerLibrary.loading
  readonly property bool refreshQueued: providerLibrary.refreshQueued
  readonly property double lastRefreshMs: providerLibrary.lastRefreshMs
  readonly property bool remoteConfigLoaded: providerLibrary.remoteConfigLoaded
  readonly property var remoteConfig: providerLibrary.remoteConfig
  readonly property var remoteHosts: providerLibrary.supplementalHosts
  readonly property string remoteQueryHostId: providerLibrary.remoteQueryHostId
  readonly property string remoteActionHostId: providerLibrary.actionHostId
  readonly property string remoteAddError: providerLibrary.remoteAddError
  readonly property string remoteTestHostId: providerLibrary.remoteTestHostId
  readonly property bool remoteTestRunning: providerLibrary.remoteTestRunning
  readonly property bool remoteTestSucceeded: providerLibrary.remoteTestSucceeded
  readonly property string remoteTestMessage: providerLibrary.remoteTestMessage
  readonly property string remoteClaudeLoginHostId: providerLibrary.remoteClaudeLoginHostId
  readonly property bool remoteClaudeLoginRunning: providerLibrary.remoteClaudeLoginRunning
  readonly property var sshHosts: providerLibrary.sshHosts
  readonly property bool sshHostsLoading: providerLibrary.sshHostsLoading
  readonly property string sshHostsError: providerLibrary.sshHostsError
  readonly property bool snapshotLoaded: snapshots.loaded
  readonly property bool snapshotRestored: snapshots.restored
  readonly property bool snapshotHydrating: snapshots.hydrating
  readonly property string snapshot: snapshots.encoded

  function clearRemoteError() {
    providerLibrary.remoteAddError = ""
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
      remoteHosts: providerLibrary.configuredRemoteHosts,
      localProviders: providerLibrary.snapshotLocalProviders()
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
    providerLibrary.restoreRemoteHosts(snapshot.remoteHosts)
    providerLibrary.restoreLocalProviders(snapshot.localProviders)
  }
  
  function resetBackendState() {
    if (store.threadLaunchPhase === "launching")
      store.mutations.failThreadLaunch(store.threadLaunchRequestId, "The provider stopped during thread launch")
    providerLibrary.reset()
  }
  
  function startAppServer() {
    providerLibrary.start()
  }
  
  function remoteHostById(hostId) {
    return providerLibrary.hostById(hostId)
  }
  
  function remotePathForThread(host, thread) {
    return providerLibrary.pathForThread(host ? host.id : "", thread)
  }
  
  function remoteThreadStatus(thread) {
    var provider = localAgentProviderForThread(thread)
    var hostId = provider ? provider.hostId : ""
    return providerLibrary.threadStatus(hostId, thread)
  }
  
  function refreshRemotes(hostId) {
    providerLibrary.refreshSupplementalHosts(hostId)
  }
  
  function localAgentProvider(hostId) {
    return providerLibrary.localProviderForHost(hostId)
  }
  
  function localAgentProviderForThread(thread) {
    return providerLibrary.localProviderForThread(thread)
  }
  
  function addRemote(label, type, address, home, tokenFile, providerType) {
    return providerLibrary.addRemote(label, type, address, home, tokenFile, providerType)
  }
  
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) {
    return providerLibrary.updateRemote(
      hostId, label, type, address, home, tokenFile, providerType)
  }
  
  function removeRemote(hostId) {
    return providerLibrary.removeRemote(hostId)
  }
  
  function testRemote(hostId) {
    return providerLibrary.testRemote(hostId)
  }
  
  function loginRemoteClaude(hostId) {
    return providerLibrary.loginRemoteClaude(hostId)
  }
  
  function sshHostEnabled(alias, providerType) {
    return providerLibrary.sshHostEnabled(alias, providerType)
  }
  
  function remoteIdForSshHost(alias, providerType) {
    return providerLibrary.remoteIdForSshHost(alias, providerType)
  }
  
  function refreshSshHosts() {
    providerLibrary.refreshSshHosts()
  }
  
  function archiveRemoteThread(hostId, thread) {
    return !!providerLibrary.archiveThread(hostId, thread)
  }
  
  function renameRemoteThread(hostId, thread, name) {
    var normalized = String(name || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (normalized === "") return false
    var started = providerLibrary.renameThread(hostId, thread, normalized)
    if (!started && store.errorText === "")
      store.errorText = "Could not start the thread rename"
    return !!started
  }
  
  function toggleRemoteThreadPin(hostId, thread) {
    return !!providerLibrary.toggleThreadPin(hostId, thread)
  }
  
  function openRemoteThread(hostId, thread, path, source) {
    return !!providerLibrary.openThread(hostId, thread, path, source)
  }
  
  function newRemoteThread(hostId, path) {
    providerLibrary.createThread(hostId, path)
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
    providerLibrary.refreshThreads()
  }
  
  function threadIsPinned(thread) {
    return ThreadStateLogic.threadIsPinned(thread, store.pinnedSectionId)
  }
  
  function normalizePinnedThreads(items) {
    return ThreadStateLogic.normalizePinnedThreads(items, store.pinnedSectionId)
  }
  
  function refreshProjects() {
    providerLibrary.refreshProjects()
  }
  
  function refreshRateLimits() {
    providerLibrary.refreshRateLimits()
  }
  
  function refreshModels() {
    providerLibrary.refreshModels()
  }
  
  function refreshConfig() {
    providerLibrary.refreshConfig()
  }
  
  function setSelectedModel(value) {
    preferences.setSelectedModel(value)
  }
  
  function setSelectedEffort(value) {
    preferences.setSelectedEffort(value)
  }
  
  function selectedModelInfo() {
    return providerLibrary.modelState("codex").model
  }
  
  function effectiveModel() {
    return providerLibrary.effectiveModel("codex")
  }
  
  function effectiveEffort() {
    return providerLibrary.effectiveEffort("codex")
  }
  
  function selectedModelEfforts(modelId) {
    return providerLibrary.modelEfforts("codex", modelId)
  }
  
  function providerHost(providerType) {
    return providerLibrary.providerHost(providerType)
  }
  
  function modelsForProvider(providerType) {
    return providerLibrary.models(providerType)
  }
  
  function agentsForProvider(providerType) {
    return providerLibrary.agents(providerType)
  }
  
  function selectedModelForProvider(providerType) {
    return providerLibrary.selectedModel(providerType)
  }
  
  function selectedEffortForProvider(providerType) {
    return providerLibrary.selectedEffort(providerType)
  }
  
  function selectedAgentForProvider(providerType) {
    return providerLibrary.selectedAgent(providerType)
  }
  
  function defaultModelForProvider(providerType) {
    return providerLibrary.defaultModel(providerType)
  }
  
  function defaultEffortForProvider(providerType, modelId) {
    return providerLibrary.defaultEffort(providerType, modelId)
  }
  
  function defaultAgentForProvider(providerType) {
    return providerLibrary.defaultAgent(providerType)
  }
  
  function effectiveModelForProvider(providerType) {
    return providerLibrary.effectiveModel(providerType)
  }
  
  function effectiveEffortForProvider(providerType) {
    return providerLibrary.effectiveEffort(providerType)
  }
  
  function effectiveAgentForProvider(providerType) {
    return providerLibrary.effectiveAgent(providerType)
  }
  
  function modelEffortsForProvider(providerType, modelId) {
    return providerLibrary.modelEfforts(providerType, modelId)
  }
  
  function setModelForProvider(providerType, value) {
    providerLibrary.setModel(providerType, value)
  }
  
  function setEffortForProvider(providerType, value) {
    providerLibrary.setEffort(providerType, value)
  }
  
  function setAgentForProvider(providerType, value) {
    providerLibrary.setAgent(providerType, value)
  }
}
