pragma Singleton

import QtQuick
import Quickshell
import "../providers" as Providers
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
import "../logic/ThreadListLogic.js" as ThreadListLogic
import "../logic/ThreadMutationLogic.js" as ThreadMutationLogic
import "../logic/ThreadLaunchLogic.js" as ThreadLaunchLogic
import "../logic/ThreadNotificationLogic.js" as ThreadNotificationLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

Item {
  id: root

  // Stable UI-facing store. Provider-specific transport logic lives under providers/.

  property var threads: []
  property var projects: []
  property var rateLimits: ({})
  property var rateLimitResetCredits: ({})
  property var models: []
  property var codexConfig: ({})
  property var threadStatuses: ({})
  property var unreadThreads: ({})
  readonly property alias ready: agentProviders.ready
  readonly property alias loading: agentProviders.loading
  readonly property alias refreshQueued: agentProviders.refreshQueued
  property bool shuttingDown: false
  property string errorText: ""
  property string launchError: ""
  property var threadLaunchState: ThreadLaunchLogic.idleThreadLaunchState()
  readonly property string threadLaunchPhase: String(threadLaunchState.phase || "idle")
  readonly property int threadLaunchRequestId: Number(threadLaunchState.requestId || 0)
  readonly property string launchingThreadId:
    String(threadLaunchState.targetThreadId || "")
  readonly property string failedLaunchThreadId:
    String(threadLaunchState.failedThreadId || "")
  readonly property string threadLaunchSource: String(threadLaunchState.source || "")
  property string launchingProjectPath: ""
  property var threadMutationState: ThreadMutationLogic.idleMutationState()
  readonly property string archivingThreadId:
    threadMutationState.kind === "archive" ? threadMutationState.threadId : ""
  readonly property string renamingThreadId:
    threadMutationState.kind === "rename" ? threadMutationState.threadId : ""
  readonly property string pinningThreadId:
    threadMutationState.kind === "pin" ? threadMutationState.threadId : ""
  readonly property bool pendingPinValue: threadMutationState.pinValue === true
  readonly property var archivedThreadSnapshot: threadMutationState.archiveSnapshot
  readonly property int archivedThreadIndex: Number(threadMutationState.archiveIndex)
  readonly property var archiveTombstones: threadMutationState.archiveTombstones || ({})
  property string archiveConfirmationId: ""
  readonly property string movingThreadId:
    threadMutationState.kind === "move" ? threadMutationState.threadId : ""
  readonly property string pendingMovePath: threadMutationState.movePath || ""
  readonly property string pendingMoveName: threadMutationState.moveName || ""
  property string activeThreadId: ""
  readonly property var runtimeProcesses: runtimeProcessesLoader.item
  readonly property alias remoteConfigLoaded: agentProviders.remoteConfigLoaded
  readonly property alias remoteConfig: agentProviders.remoteConfig
  readonly property alias remoteHosts: agentProviders.supplementalHosts
  readonly property alias remoteQueryHostId: agentProviders.remoteQueryHostId
  readonly property alias remoteActionHostId: agentProviders.actionHostId
  property alias remoteAddError: agentProviders.remoteAddError
  readonly property alias remoteTestHostId: agentProviders.remoteTestHostId
  readonly property alias remoteTestRunning: agentProviders.remoteTestRunning
  readonly property alias remoteTestSucceeded: agentProviders.remoteTestSucceeded
  readonly property alias remoteTestMessage: agentProviders.remoteTestMessage
  readonly property alias remoteClaudeLoginHostId: agentProviders.remoteClaudeLoginHostId
  readonly property alias remoteClaudeLoginRunning: agentProviders.remoteClaudeLoginRunning
  readonly property alias sshHosts: agentProviders.sshHosts
  readonly property alias sshHostsLoading: agentProviders.sshHostsLoading
  readonly property alias sshHostsError: agentProviders.sshHostsError
  readonly property alias sidebarSettingsLoaded: sidebarPreferences.loaded
  readonly property alias hydratingSidebarSettings: sidebarPreferences.hydrating
  readonly property alias providerSnapshotLoaded: providerSnapshotStore.loaded
  readonly property alias providerSnapshotRestored: providerSnapshotStore.restored
  readonly property alias hydratingProviderSnapshot: providerSnapshotStore.hydrating
  readonly property alias providerSnapshot: providerSnapshotStore.encoded
  property alias sidebarScope: sidebarPreferences.scope
  property alias globalSidebarOpen: sidebarPreferences.globalOpen
  property alias sidebarOpenWorkspaces: sidebarPreferences.openWorkspaces
  property alias collapsedProjects: sidebarPreferences.collapsedProjects
  property alias collapsedRemotes: sidebarPreferences.collapsedRemotes
  property alias pinnedSections: sidebarPreferences.pinnedSections
  readonly property alias lastRefreshMs: agentProviders.lastRefreshMs

  onThreadsChanged: providerApi.scheduleProviderSnapshot()
  onProjectsChanged: providerApi.scheduleProviderSnapshot()
  onRateLimitsChanged: providerApi.scheduleProviderSnapshot()
  onRateLimitResetCreditsChanged: providerApi.scheduleProviderSnapshot()
  onModelsChanged: providerApi.scheduleProviderSnapshot()
  onCodexConfigChanged: providerApi.scheduleProviderSnapshot()
  onThreadStatusesChanged: providerApi.scheduleProviderSnapshot()
  onUnreadThreadsChanged: providerApi.scheduleProviderSnapshot()

  readonly property string threadStatusesHelperPath: Qt.resolvedUrl("../bin/omarchy-codex-thread-statuses")
    .toString().replace(/^file:\/\//, "")
  readonly property string threadEventsHelperPath: Qt.resolvedUrl("../bin/omarchy-codex-thread-events")
    .toString().replace(/^file:\/\//, "")
  readonly property string terminalOpenHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-terminal-open").toString().replace(/^file:\/\//, "")
  readonly property string agentChatHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-chat").toString().replace(/^file:\/\//, "")
  readonly property string streamGuardPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-stream-guard").toString().replace(/^file:\/\//, "")
  readonly property string localHome: Quickshell.env("HOME") || "/tmp"
  readonly property string backendHomePath: localHome
  readonly property string pinnedSectionId: "01984de2-8f74-7c91-a3b2-5c5e937cf318"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    || (stateHome + "/omarchy")
  readonly property string providerSnapshotPath:
    runtimeDir + "/omarchy-agent-threads-provider-snapshot.json"
  readonly property string sidebarSettingsPath: stateHome + "/omarchy/codex-threads.json"
  readonly property alias sidebarOpen: sidebarPreferences.sidebarOpen
  readonly property alias selectedProvider: sidebarPreferences.selectedProvider
  readonly property alias selectedModel: sidebarPreferences.selectedModel
  readonly property alias selectedEffort: sidebarPreferences.selectedEffort
  readonly property alias threadFrontend: sidebarPreferences.threadFrontend
  readonly property alias threadFrontendChangedBy:
    sidebarPreferences.threadFrontendChangedBy
  readonly property alias threadFrontendChangedAt:
    sidebarPreferences.threadFrontendChangedAt
  readonly property alias fastMode: sidebarPreferences.fastMode
  readonly property alias notificationsEnabled: sidebarPreferences.notificationsEnabled
  readonly property string codexServiceTier: fastMode ? "fast" : "default"

  signal threadLaunchRequested(string threadId)


  Providers.AgentProviderLibrary {
    id: agentProviders
    controller: root
    onSettingsChanged: sidebarPreferences.scheduleSave()
    onSnapshotsChanged: providerApi.scheduleProviderSnapshot()
  }

  SidebarPreferences {
    id: sidebarPreferences
    path: root.sidebarSettingsPath
    providerSettings: agentProviders
    onReady: root.providers.startAppServer()
  }

  ProviderSnapshotStore {
    id: providerSnapshotStore
    path: root.providerSnapshotPath
    onRestoreRequested: function(snapshot) {
      root.providers.restoreProviderSnapshot(snapshot)
    }
  }

  Loader {
    id: runtimeProcessesLoader
  }

  readonly property alias mutations: mutationApi
  readonly property alias providers: providerApi
  readonly property alias threadActions: threadApi
  readonly property alias settings: settingsApi

  ThreadStoreMutations { id: mutationApi; store: root }
  ThreadStoreProviderApi {
    id: providerApi
    store: root
    providerLibrary: agentProviders
    preferences: sidebarPreferences
    snapshots: providerSnapshotStore
  }
  ThreadStoreThreadApi { id: threadApi; store: root; providerLibrary: agentProviders }
  ThreadStoreSettingsApi { id: settingsApi; preferences: sidebarPreferences }


  onActiveThreadIdChanged: {
    threadApi.markThreadSeen(activeThreadId)
    providerApi.scheduleProviderSnapshot()
  }

  Component.onCompleted: {
    runtimeProcessesLoader.setSource(
      Qt.resolvedUrl("ThreadRuntimeProcesses.qml"), { controller: root })
  }
  Component.onDestruction: {
    providerApi.flushProviderSnapshot()
    shuttingDown = true
    if (runtimeProcesses) runtimeProcesses.shutdown()
  }
}
