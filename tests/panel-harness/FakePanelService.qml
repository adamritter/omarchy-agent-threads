// Purpose: Provides a controlled Fake Panel Service harness for behavioral tests.
import QtQuick
import Quickshell

QtObject {
  id: root

  readonly property var mutations: root
  readonly property var providers: root
  readonly property var threadActions: root
  readonly property var settings: root

  property string selectedProvider: "codex"
  property var threads: [
    { id: "home", name: "Home thread", cwd: Quickshell.env("HOME"), updatedAt: 30 },
    { id: "alpha", name: "Alpha", cwd: "/work/demo", updatedAt: 20 },
    { id: "beta", name: "Beta", cwd: "/work/demo", updatedAt: 10 }
  ]
  property var projects: []
  property var remoteHosts: []
  property var collapsedProjects: ({ "local:/work/demo": false })
  property var collapsedRemotes: ({})
  property var pinnedSections: ({})
  property var sshHosts: []
  property string sshHostsError: ""
  property bool sshHostsLoading: false
  property bool ready: true
  property bool loading: false
  property bool providerSnapshotRestored: true
  property string errorText: ""
  property string launchError: ""
  property string launchingThreadId: ""
  property string launchingProjectPath: ""
  property string archivingThreadId: ""
  property string pinningThreadId: ""
  property string renamingThreadId: ""
  property string movingThreadId: ""
  property string remoteActionHostId: ""
  property string activeThreadId: "beta"
  property string failedLaunchThreadId: ""
  property string remoteAddError: ""
  property string remoteClaudeLoginHostId: ""
  property bool remoteClaudeLoginRunning: false
  property string remoteTestHostId: ""
  property bool remoteTestRunning: false
  property bool remoteTestSucceeded: false
  property string remoteTestMessage: ""
  property var rateLimits: ({})
  property var rateLimitResetCredits: ({ availableCount: 0 })
  property bool sidebarSettingsLoaded: false
  property bool sidebarOpen: false
  property string sidebarScope: "global"
  property string threadFrontend: "terminal"
  property string threadFrontendChangedBy: ""
  property double threadFrontendChangedAt: 0
  property bool fastMode: false
  property bool notificationsEnabled: false
  property int openedThreadCount: 0
  property int newProjectThreadCount: 0
  property int pinnedThreadCount: 0
  property int archivedThreadCount: 0
  property int openedTerminalCount: 0

  function projectPathForThread(thread) { return String(thread && thread.cwd || "") }
  function projectRootPath(project) { return String(project && project.path || "") }
  function remotePathForThread(host, thread) { return String(thread && thread.cwd || "") }
  function remoteThreadStatus(thread) { return String(thread && thread.status || "done") }
  function threadStatus(threadId) { return threadId === "alpha" ? "busy" : "done" }
  function threadUnread(threadId) { return false }
  function modelsForProvider(provider) { return [] }
  function agentsForProvider(provider) { return [] }
  function modelEffortsForProvider(provider, model) { return [] }
  function selectedModelForProvider(provider) { return "" }
  function selectedEffortForProvider(provider) { return "" }
  function selectedAgentForProvider(provider) { return "" }
  function defaultModelForProvider(provider) { return "" }
  function defaultEffortForProvider(provider) { return "" }
  function effectiveModel() { return "gpt-test" }
  function effectiveEffort() { return "medium" }
  function effectiveModelForProvider(provider) { return "gpt-test" }
  function effectiveEffortForProvider(provider) { return "medium" }
  function effectiveAgentForProvider(provider) { return "" }
  function setEffortForProvider(provider, effort) {}
  function sidebarOpenOnWorkspace(workspaceId) { return false }
  function migrateSidebarOpenState(workspaceId) {}
  function refreshThreads() {}
  function flushProviderSnapshot() {}
  function refreshActiveThread() {}
  function refreshRemotes(remoteId) {}
  function refreshSshHosts() {}
  function setCollapsedProjects(value) { collapsedProjects = value }
  function setCollapsedRemotes(value) { collapsedRemotes = value }
  function setPinnedSections(value) { pinnedSections = value }
  function setSelectedProvider(value) { selectedProvider = value }
  function setThreadFrontend(value, source) {
    threadFrontend = value === "agent-chat" ? "agent-chat" : "terminal"
    threadFrontendChangedBy = String(source || "unknown")
    threadFrontendChangedAt = Date.now()
  }
  function toggleThreadFrontend(source) {
    setThreadFrontend(
      threadFrontend === "agent-chat" ? "terminal" : "agent-chat", source)
    return threadFrontend
  }
  function setFastMode(value) { fastMode = value === true }
  function toggleFastMode() { fastMode = !fastMode; return fastMode }
  function setNotificationsEnabled(value) { notificationsEnabled = value === true }
  function toggleNotifications() {
    notificationsEnabled = !notificationsEnabled
    return notificationsEnabled
  }
  function setSidebarOpenOnWorkspace(workspaceId, opened) {}
  function setSidebarScope(scope, workspaceId, opened) { sidebarScope = scope }
  function openThread(thread, path, source) {
    openedThreadCount++
    launchingThreadId = String(thread && thread.id || "")
    return true
  }
  function newProjectThread(path) { newProjectThreadCount++ }
  function toggleThreadPin(thread) { pinnedThreadCount++ }
  function archiveThread(thread) { archivedThreadCount++ }
  function openTerminal(mode, endpoint, path) { openedTerminalCount++; return true }
}
