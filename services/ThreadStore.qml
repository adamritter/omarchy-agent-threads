pragma Singleton
// Purpose: Provides shared Thread Store state and operations to the plugin.

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
  readonly property string localHome: Quickshell.env("HOME")
  readonly property string backendHomePath: localHome
  readonly property string pinnedSectionId: "01984de2-8f74-7c91-a3b2-5c5e937cf318"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
    || (stateHome + "/omarchy")
  readonly property string providerSnapshotPath:
    runtimeDir + "/omarchy-agent-threads-provider-snapshot.json"
  readonly property string sidebarSettingsPath: stateHome + "/omarchy/codex-threads.json"
  readonly property string codexServiceTier: settings.fastMode ? "fast" : "default"

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
    providerSettings: agentProviders.modelSettings
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
    appServer: agentProviders.appServer
    routing: agentProviders.routing
    localProviders: agentProviders.localProviders
    remotes: agentProviders.remotes
    supplementalHosts: agentProviders.supplementalHosts
    configuredRemoteHosts: agentProviders.configuredRemoteHosts
    actionHostId: agentProviders.actionHostId
    preferences: sidebarPreferences
    snapshots: providerSnapshotStore
  }
  ThreadStoreThreadApi {
    id: threadApi
    store: root
    appServer: agentProviders.appServer
    routing: agentProviders.routing
    localCodex: agentProviders.localCodex
  }
  ThreadStoreSettingsApi {
    id: settingsApi
    preferences: sidebarPreferences
    modelSettings: agentProviders.modelSettings
  }


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
