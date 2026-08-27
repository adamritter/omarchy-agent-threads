import QtQuick
import "../logic/AgentProviderLogic.js" as AgentProviderLogic

// Shared provider boundary for every Agent Threads frontend. Provider and
// transport are independent dimensions: Codex, Claude, and OpenCode can be
// presented through local, SSH, or direct App Server hosts without teaching
// the UI which implementation owns a thread.
Item {
  id: root

  required property var controller

  readonly property alias ready: appServerClient.ready
  readonly property alias loading: appServerClient.loading
  readonly property alias refreshQueued: appServerClient.refreshQueued
  readonly property alias lastRefreshMs: appServerClient.lastRefreshMs

  readonly property alias remoteConfigLoaded: remoteProvider.configLoaded
  readonly property alias remoteConfig: remoteProvider.remoteConfig
  readonly property alias remoteQueryHostId: remoteProvider.queryHostId
  readonly property string actionHostId: remoteProvider.actionHostId !== ""
    ? remoteProvider.actionHostId : localRegistry.actionHostId
  property alias remoteAddError: remoteProvider.addError
  readonly property alias remoteTestHostId: remoteProvider.managementTestHostId
  readonly property alias remoteTestRunning: remoteProvider.managementTestRunning
  readonly property alias remoteTestSucceeded: remoteProvider.managementTestSucceeded
  readonly property alias remoteTestMessage: remoteProvider.managementTestMessage
  readonly property alias remoteClaudeLoginHostId: remoteProvider.loginHostId
  readonly property alias remoteClaudeLoginRunning: remoteProvider.loginRunning
  readonly property alias sshHosts: remoteProvider.sshHosts
  readonly property alias sshHostsLoading: remoteProvider.sshHostsLoading
  readonly property alias sshHostsError: remoteProvider.sshHostsError

  readonly property var localCodexHost: AgentProviderLogic.normalizeHost({
    id: "provider-codex",
    label: "CODEX",
    providerType: "codex",
    type: "provider",
    connectionType: "local",
    home: controller.localHome,
    threads: controller.threads,
    projects: controller.projects,
    models: controller.models,
    agents: [],
    rateLimits: controller.rateLimits,
    loading: loading,
    error: controller.errorText
  })
  readonly property var localHosts: AgentProviderLogic.normalizeHosts(localRegistry.hosts)
  readonly property var configuredRemoteHosts:
    AgentProviderLogic.normalizeHosts(remoteProvider.remoteHosts)
  // The existing sidebar calls these supplemental hosts "remoteHosts". Keep
  // that view for compatibility while exposing allHosts to new frontends.
  readonly property var supplementalHosts: configuredRemoteHosts.concat(localHosts)
  readonly property var allHosts: AgentProviderLogic.normalizeHosts(
    [localCodexHost].concat(localHosts, configuredRemoteHosts))

  signal settingsChanged()
  signal snapshotsChanged()
  signal remoteHostsChanged()

  CodexAppServerClient {
    id: appServerClient
    controller: root.controller
  }

  LocalCodexProvider {
    id: localCodexProvider
    controller: root.controller
  }

  ProviderRegistry {
    id: localRegistry
    controller: root.controller
    onSettingsChanged: root.settingsChanged()
    onSnapshotsChanged: root.snapshotsChanged()
  }

  RemoteAgentProvider {
    id: remoteProvider
    controller: root.controller
    onRemoteHostsChanged: {
      root.remoteHostsChanged()
      root.snapshotsChanged()
    }
  }

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
    if (isLocalCodex(hostId)) return controller.projectPathForThread(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.pathForThread(thread)
    return remoteProvider.pathForThread(remoteProvider.hostById(hostId), thread)
  }

  function threadStatus(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.threadStatus(thread ? thread.id : "")
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
    if (isLocalCodex(hostId)) return controller.archiveLocalCodexThread(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.archiveThread(thread)
    return remoteProvider.archiveThread(hostId, thread)
  }

  function renameThread(hostId, thread, name) {
    if (isLocalCodex(hostId)) return controller.renameLocalCodexThread(thread, name)
    var local = localProviderForHost(hostId)
    if (local) return local.renameThread(thread, name)
    return remoteProvider.renameThread(hostId, thread, name)
  }

  function toggleThreadPin(hostId, thread) {
    if (isLocalCodex(hostId)) return controller.toggleLocalCodexThreadPin(thread)
    var local = localProviderForHost(hostId)
    if (local) return local.toggleThreadPin(thread)
    return remoteProvider.toggleThreadPin(hostId, thread)
  }

  function openThread(hostId, thread, path) {
    if (isLocalCodex(hostId)) return localCodexProvider.openThread(thread, path)
    var local = localProviderForHost(hostId)
    if (local) return local.openThread(thread, path)
    return remoteProvider.openThread(hostId, thread, path)
  }

  function createThread(hostId, path) {
    if (isLocalCodex(hostId)) return localCodexProvider.newThread(path)
    var local = localProviderForHost(hostId)
    if (local) return local.newThread(path)
    return remoteProvider.newThread(hostId, path)
  }

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

  function providerHost(providerType) { return localRegistry.host(providerType) }
  function modelState(providerType, modelId) {
    var type = normalizeProviderType(providerType)
    if (type === "codex") {
      return AgentProviderLogic.modelState(
        controller.models, controller.codexConfig,
        controller.selectedModel, controller.selectedEffort, modelId)
    }
    var selected = localRegistry.selectedModel(type)
    var requested = modelId !== undefined ? modelId : selected
    return AgentProviderLogic.modelState(localRegistry.models(type), {
      model: localRegistry.defaultModel(type),
      model_reasoning_effort: localRegistry.defaultEffort(type, requested)
    }, selected, localRegistry.selectedEffort(type), modelId)
  }
  function models(providerType) {
    var type = normalizeProviderType(providerType)
    return type === "codex" ? (controller.models || []) : localRegistry.models(type)
  }
  function agents(providerType) { return localRegistry.agents(providerType) }
  function selectedModel(providerType) {
    var type = normalizeProviderType(providerType)
    return type === "codex" ? String(controller.selectedModel || "")
      : localRegistry.selectedModel(type)
  }
  function selectedEffort(providerType) {
    var type = normalizeProviderType(providerType)
    return type === "codex" ? String(controller.selectedEffort || "")
      : localRegistry.selectedEffort(type)
  }
  function selectedAgent(providerType) { return localRegistry.selectedAgent(providerType) }
  function defaultModel(providerType) { return modelState(providerType).defaultModel }
  function defaultEffort(providerType, modelId) {
    return modelState(providerType, modelId).defaultEffort
  }
  function defaultAgent(providerType) { return localRegistry.defaultAgent(providerType) }
  function effectiveModel(providerType) { return modelState(providerType).effectiveModel }
  function effectiveEffort(providerType) { return modelState(providerType).effectiveEffort }
  function effectiveAgent(providerType) { return localRegistry.effectiveAgent(providerType) }
  function modelEfforts(providerType, modelId) {
    return modelState(providerType, modelId).efforts
  }
  function setModel(providerType, value) {
    var type = normalizeProviderType(providerType)
    if (type === "codex") controller.setSelectedModel(value)
    else localRegistry.setModel(type, value)
  }
  function setEffort(providerType, value) {
    var type = normalizeProviderType(providerType)
    if (type === "codex") controller.setSelectedEffort(value)
    else localRegistry.setEffort(type, value)
  }
  function setAgent(providerType, value) { localRegistry.setAgent(providerType, value) }
  function loadSettings(settings) { localRegistry.loadSettings(settings) }
  function settingsObject() { return localRegistry.settingsObject() }
}
