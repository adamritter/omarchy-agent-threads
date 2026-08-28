// Purpose: Implements the Agent Provider Library provider integration boundary.
import QtQuick
import "../logic/AgentProviderLogic.js" as AgentProviderLogic

// Shared provider boundary for every Agent Threads frontend. Provider and
// transport are independent dimensions: Codex, Claude, and OpenCode can be
// presented through local, SSH, or direct App Server hosts without teaching
// the UI which implementation owns a thread.
Item {
  id: root

  required property var controller

  // Internal domain ports used by ThreadStore. UI code only sees the store APIs.
  readonly property alias appServer: appServerClient
  readonly property alias localCodex: localCodexProvider
  readonly property alias localProviders: localRegistry
  readonly property alias remotes: remoteProvider
  readonly property alias routing: providerRouting
  readonly property alias modelSettings: providerModels

  readonly property string actionHostId: remoteProvider.actionHostId !== ""
    ? remoteProvider.actionHostId : localRegistry.actionHostId

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
    loading: appServerClient.loading,
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

  LocalProviderRegistry {
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
    threadActions: root.controller.threadActions
    appServerClient: appServerClient
    localRegistry: localRegistry
    remoteProvider: remoteProvider
    localCodexProvider: localCodexProvider
    allHosts: root.allHosts
  }

  AgentProviderModels {
    id: providerModels
    codexModels: root.controller.models
    codexConfig: root.controller.codexConfig
    settings: root.controller.settings
    registry: localRegistry
  }
}
