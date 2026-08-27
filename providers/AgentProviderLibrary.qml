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

  AgentProviderRouting {
    id: providerRouting
    controller: root.controller
    appServerClient: appServerClient
    localRegistry: localRegistry
    remoteProvider: remoteProvider
    localCodexProvider: localCodexProvider
    allHosts: root.allHosts
  }

  function normalizeProviderType(value) { return providerRouting.normalizeProviderType(value) }
  function hostById(hostId) { return providerRouting.hostById(hostId) }
  function isLocalCodex(hostId) { return providerRouting.isLocalCodex(hostId) }
  function localProviderForHost(hostId) { return providerRouting.localProviderForHost(hostId) }
  function localProviderForThread(thread) { return providerRouting.localProviderForThread(thread) }
  function pathForThread(hostId, thread) { return providerRouting.pathForThread(hostId, thread) }
  function threadStatus(hostId, thread) { return providerRouting.threadStatus(hostId, thread) }
  function refreshHost(hostId) { return providerRouting.refreshHost(hostId) }
  function refreshSupplementalHosts(hostId) { return providerRouting.refreshSupplementalHosts(hostId) }
  function markSupplementalThreadSeen(threadId) { return providerRouting.markSupplementalThreadSeen(threadId) }
  function archiveThread(hostId, thread) { return providerRouting.archiveThread(hostId, thread) }
  function renameThread(hostId, thread, name) { return providerRouting.renameThread(hostId, thread, name) }
  function toggleThreadPin(hostId, thread) { return providerRouting.toggleThreadPin(hostId, thread) }
  function openThread(hostId, thread, path, source) { return providerRouting.openThread(hostId, thread, path, source) }
  function createThread(hostId, path) { return providerRouting.createThread(hostId, path) }

  AgentProviderOperations {
    id: providerOperations
    appServerClient: appServerClient
    localCodexProvider: localCodexProvider
    localRegistry: localRegistry
    remoteProvider: remoteProvider
  }

  function reset() { return providerOperations.reset() }
  function start() { return providerOperations.start() }
  function refreshThreads() { return providerOperations.refreshThreads() }
  function refreshProjects() { return providerOperations.refreshProjects() }
  function refreshRateLimits() { return providerOperations.refreshRateLimits() }
  function refreshModels() { return providerOperations.refreshModels() }
  function refreshConfig() { return providerOperations.refreshConfig() }
  function createProject(threadId, name, path) { return providerOperations.createProject(threadId, name, path) }
  function moveThread(threadId, projectId) { return providerOperations.moveThread(threadId, projectId) }
  function clearMoveRequests() { return providerOperations.clearMoveRequests() }
  function archiveLocalCodexRpc(threadId) { return providerOperations.archiveLocalCodexRpc(threadId) }
  function renameLocalCodexRpc(threadId, name) { return providerOperations.renameLocalCodexRpc(threadId, name) }
  function pinLocalCodexRpc(threadId, pinned, sectionId) { return providerOperations.pinLocalCodexRpc(threadId, pinned, sectionId) }
  function clearPendingLocalCodexThread() { return providerOperations.clearPendingLocalCodexThread() }
  function resolvePendingLocalCodexThread() { return providerOperations.resolvePendingLocalCodexThread() }
  function refreshActiveThread() { return providerOperations.refreshActiveThread() }
  function snapshotLocalProviders() { return providerOperations.snapshotLocalProviders() }
  function restoreLocalProviders(snapshots) { return providerOperations.restoreLocalProviders(snapshots) }
  function restoreRemoteHosts(snapshots) { return providerOperations.restoreRemoteHosts(snapshots) }
  function addRemote(label, type, address, home, tokenFile, providerType) { return providerOperations.addRemote(label, type, address, home, tokenFile, providerType) }
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) { return providerOperations.updateRemote(hostId, label, type, address, home, tokenFile, providerType) }
  function removeRemote(hostId) { return providerOperations.removeRemote(hostId) }
  function testRemote(hostId) { return providerOperations.testRemote(hostId) }
  function loginRemoteClaude(hostId) { return providerOperations.loginRemoteClaude(hostId) }
  function sshHostEnabled(alias, providerType) { return providerOperations.sshHostEnabled(alias, providerType) }
  function remoteIdForSshHost(alias, providerType) { return providerOperations.remoteIdForSshHost(alias, providerType) }
  function refreshSshHosts() { return providerOperations.refreshSshHosts() }



  AgentProviderModels {
    id: providerModels
    controller: root.controller
    registry: localRegistry
  }

  function providerHost(providerType) { return providerModels.providerHost(providerType) }

  function modelState(providerType, modelId) { return providerModels.modelState(providerType, modelId) }

  function models(providerType) { return providerModels.models(providerType) }

  function agents(providerType) { return providerModels.agents(providerType) }

  function selectedModel(providerType) { return providerModels.selectedModel(providerType) }

  function selectedEffort(providerType) { return providerModels.selectedEffort(providerType) }

  function selectedAgent(providerType) { return providerModels.selectedAgent(providerType) }

  function defaultModel(providerType) { return providerModels.defaultModel(providerType) }

  function defaultEffort(providerType, modelId) { return providerModels.defaultEffort(providerType, modelId) }

  function defaultAgent(providerType) { return providerModels.defaultAgent(providerType) }

  function effectiveModel(providerType) { return providerModels.effectiveModel(providerType) }

  function effectiveEffort(providerType) { return providerModels.effectiveEffort(providerType) }

  function effectiveAgent(providerType) { return providerModels.effectiveAgent(providerType) }

  function modelEfforts(providerType, modelId) { return providerModels.modelEfforts(providerType, modelId) }

  function setModel(providerType, value) { return providerModels.setModel(providerType, value) }

  function setEffort(providerType, value) { return providerModels.setEffort(providerType, value) }

  function setAgent(providerType, value) { return providerModels.setAgent(providerType, value) }

  function loadSettings(settings) { return providerModels.loadSettings(settings) }

  function settingsObject() { return providerModels.settingsObject() }

}
