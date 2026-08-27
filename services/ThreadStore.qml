pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../providers" as Providers
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
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
  property string launchingThreadId: ""
  property string launchingProjectPath: ""
  property string archivingThreadId: ""
  property string renamingThreadId: ""
  property string pinningThreadId: ""
  property bool pendingPinValue: false
  property var archivedThreadSnapshot: null
  property int archivedThreadIndex: -1
  property var archiveTombstones: ({})
  property string archiveConfirmationId: ""
  property string movingThreadId: ""
  property string pendingMovePath: ""
  property string pendingMoveName: ""
  property string activeThreadId: ""
  property string agentChatLaunchKind: ""
  property string agentChatPendingThreadId: ""
  property string agentChatErrorOutput: ""
  property string terminalErrorOutput: ""
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
  property bool sidebarSettingsLoaded: false
  property bool hydratingSidebarSettings: false
  property bool providerSnapshotLoaded: false
  property bool providerSnapshotRestored: false
  property bool hydratingProviderSnapshot: false
  property string providerSnapshot: ""
  property bool migrateOpenSidebarToActiveWorkspace: false
  property string sidebarScope: "workspace"
  property bool globalSidebarOpen: false
  property var sidebarOpenWorkspaces: ({})
  property var collapsedProjects: ({})
  property var collapsedRemotes: ({})
  property var pinnedSections: ({})
  readonly property alias lastRefreshMs: agentProviders.lastRefreshMs

  onThreadsChanged: scheduleProviderSnapshot()
  onProjectsChanged: scheduleProviderSnapshot()
  onRateLimitsChanged: scheduleProviderSnapshot()
  onRateLimitResetCreditsChanged: scheduleProviderSnapshot()
  onModelsChanged: scheduleProviderSnapshot()
  onCodexConfigChanged: scheduleProviderSnapshot()
  onThreadStatusesChanged: scheduleProviderSnapshot()
  onUnreadThreadsChanged: scheduleProviderSnapshot()

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
  readonly property bool sidebarOpen: {
    if (sidebarScope === "global") return globalSidebarOpen
    var states = sidebarOpenWorkspaces
    for (var workspaceId in states)
      if (states[workspaceId] === true) return true
    return false
  }
  readonly property alias selectedProvider: persisted.selectedProvider
  readonly property alias selectedModel: persisted.selectedModel
  readonly property alias selectedEffort: persisted.selectedEffort
  readonly property alias threadFrontend: persisted.threadFrontend
  readonly property alias fastMode: persisted.fastMode
  readonly property string codexServiceTier: fastMode ? "fast" : "default"

  PersistentProperties {
    id: persisted
    reloadableId: "adam-codex-threads"
    property bool sidebarOpen: false
    property string selectedProvider: "codex"
    property string selectedModel: ""
    property string selectedEffort: ""
    // Agent Chat is deliberately opt-in; existing behavior remains the default.
    property string threadFrontend: "terminal"
    property bool fastMode: false
    onSidebarOpenChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onSelectedProviderChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onSelectedModelChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onSelectedEffortChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onThreadFrontendChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onFastModeChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
  }

  onCollapsedProjectsChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }
  onCollapsedRemotesChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }
  onPinnedSectionsChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }
  onSidebarOpenWorkspacesChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }
  onSidebarScopeChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }
  onGlobalSidebarOpenChanged: {
    if (sidebarSettingsLoaded && !hydratingSidebarSettings) sidebarSaveTimer.restart()
  }

  signal threadLaunchRequested(string threadId)

  Providers.AgentProviderLibrary {
    id: agentProviders
    controller: root
    onSettingsChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
    onSnapshotsChanged: root.scheduleProviderSnapshot()
  }

  function providerSnapshotObject() {
    return {
      codex: {
        threads: threads,
        projects: projects,
        rateLimits: rateLimits,
        rateLimitResetCredits: rateLimitResetCredits,
        models: models,
        codexConfig: codexConfig,
        threadStatuses: threadStatuses,
        unreadThreads: unreadThreads,
        activeThreadId: activeThreadId
      },
      remoteHosts: agentProviders.configuredRemoteHosts,
      localProviders: agentProviders.snapshotLocalProviders()
    }
  }

  function scheduleProviderSnapshot() {
    if (!providerSnapshotLoaded || hydratingProviderSnapshot || shuttingDown) return
    providerSnapshotTimer.restart()
  }

  function flushProviderSnapshot() {
    if (!providerSnapshotLoaded || hydratingProviderSnapshot) return
    providerSnapshotTimer.stop()
    var encoded = ProviderSnapshotLogic.encode(providerSnapshotObject())
    if (encoded !== "" && encoded !== providerSnapshot) {
      providerSnapshot = encoded
      providerSnapshotFile.setText(encoded)
    }
  }

  function attachProviderSnapshot(snapshot) {
    if (providerSnapshotLoaded) return
    providerSnapshot = String(snapshot || "")
    providerSnapshotRestored = restoreProviderSnapshot()
    providerSnapshotLoaded = true
    scheduleProviderSnapshot()
  }

  function restoreProviderSnapshot() {
    var snapshot = ProviderSnapshotLogic.decode(providerSnapshot)
    if (!snapshot) return false
    var codex = snapshot.codex && typeof snapshot.codex === "object"
      ? snapshot.codex : ({})
    hydratingProviderSnapshot = true
    threads = Array.isArray(codex.threads) ? codex.threads : []
    projects = Array.isArray(codex.projects) ? codex.projects : []
    rateLimits = codex.rateLimits && typeof codex.rateLimits === "object"
      ? codex.rateLimits : ({})
    rateLimitResetCredits = codex.rateLimitResetCredits
      && typeof codex.rateLimitResetCredits === "object"
      ? codex.rateLimitResetCredits : ({})
    models = Array.isArray(codex.models) ? codex.models : []
    codexConfig = codex.codexConfig && typeof codex.codexConfig === "object"
      ? codex.codexConfig : ({})
    threadStatuses = codex.threadStatuses && typeof codex.threadStatuses === "object"
      ? codex.threadStatuses : ({})
    unreadThreads = codex.unreadThreads && typeof codex.unreadThreads === "object"
      ? codex.unreadThreads : ({})
    activeThreadId = String(codex.activeThreadId || "")
    agentProviders.restoreRemoteHosts(snapshot.remoteHosts)
    agentProviders.restoreLocalProviders(snapshot.localProviders)
    hydratingProviderSnapshot = false
    return true
  }

  function resetBackendState() {
    agentProviders.reset()
  }

  function startAppServer() {
    agentProviders.start()
  }

  function remoteHostById(hostId) {
    return agentProviders.hostById(hostId)
  }

  function remotePathForThread(host, thread) {
    return agentProviders.pathForThread(host ? host.id : "", thread)
  }

  function remoteThreadStatus(thread) {
    var provider = localAgentProviderForThread(thread)
    var hostId = provider ? provider.hostId : ""
    return agentProviders.threadStatus(hostId, thread)
  }

  function refreshRemotes(hostId) {
    agentProviders.refreshSupplementalHosts(hostId)
  }

  function localAgentProvider(hostId) {
    return agentProviders.localProviderForHost(hostId)
  }

  function localAgentProviderForThread(thread) {
    return agentProviders.localProviderForThread(thread)
  }

  function addRemote(label, type, address, home, tokenFile, providerType) {
    return agentProviders.addRemote(label, type, address, home, tokenFile, providerType)
  }

  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) {
    return agentProviders.updateRemote(
      hostId, label, type, address, home, tokenFile, providerType)
  }

  function removeRemote(hostId) {
    return agentProviders.removeRemote(hostId)
  }

  function testRemote(hostId) {
    return agentProviders.testRemote(hostId)
  }

  function loginRemoteClaude(hostId) {
    return agentProviders.loginRemoteClaude(hostId)
  }

  function sshHostEnabled(alias, providerType) {
    return agentProviders.sshHostEnabled(alias, providerType)
  }

  function remoteIdForSshHost(alias, providerType) {
    return agentProviders.remoteIdForSshHost(alias, providerType)
  }

  function refreshSshHosts() {
    agentProviders.refreshSshHosts()
  }

  function archiveRemoteThread(hostId, thread) {
    agentProviders.archiveThread(hostId, thread)
  }

  function renameRemoteThread(hostId, thread, name) {
    var normalized = String(name || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (normalized === "" || renamingThreadId !== "") return false
    var started = agentProviders.renameThread(hostId, thread, normalized)
    if (!started) launchError = "Could not start the thread rename"
    return !!started
  }

  function toggleRemoteThreadPin(hostId, thread) {
    agentProviders.toggleThreadPin(hostId, thread)
  }

  function openRemoteThread(hostId, thread, path) {
    agentProviders.openThread(hostId, thread, path)
  }

  function newRemoteThread(hostId, path) {
    agentProviders.createThread(hostId, path)
  }

  function openTerminal(mode, endpoint, path) {
    if (terminalOpenProcess.running) return false
    launchError = ""
    terminalErrorOutput = ""
    terminalOpenProcess.command = [
      streamGuardPath,
      "--",
      terminalOpenHelperPath,
      String(mode || ""),
      String(endpoint || ""),
      String(path || "")
    ]
    terminalOpenProcess.running = true
    return true
  }

  function refreshThreads() {
    agentProviders.refreshThreads()
  }

  function threadIsPinned(thread) {
    return ThreadStateLogic.threadIsPinned(thread, pinnedSectionId)
  }

  function normalizePinnedThreads(items) {
    return ThreadStateLogic.normalizePinnedThreads(items, pinnedSectionId)
  }

  function refreshProjects() {
    agentProviders.refreshProjects()
  }

  function refreshRateLimits() {
    agentProviders.refreshRateLimits()
  }

  function refreshModels() {
    agentProviders.refreshModels()
  }

  function refreshConfig() {
    agentProviders.refreshConfig()
  }

  function setSelectedModel(value) {
    persisted.selectedModel = String(value || "")
    if (persisted.selectedEffort === "") return
    var supported = agentProviders.modelEfforts("codex", persisted.selectedModel)
    if (supported.indexOf(persisted.selectedEffort) < 0)
      persisted.selectedEffort = ""
  }

  function setSelectedEffort(value) {
    persisted.selectedEffort = String(value || "")
  }

  function selectedModelInfo() {
    return agentProviders.modelState("codex").model
  }

  function effectiveModel() {
    return agentProviders.effectiveModel("codex")
  }

  function effectiveEffort() {
    return agentProviders.effectiveEffort("codex")
  }

  function selectedModelEfforts(modelId) {
    return agentProviders.modelEfforts("codex", modelId)
  }

  function providerHost(providerType) {
    return agentProviders.providerHost(providerType)
  }

  function modelsForProvider(providerType) {
    return agentProviders.models(providerType)
  }

  function agentsForProvider(providerType) {
    return agentProviders.agents(providerType)
  }

  function selectedModelForProvider(providerType) {
    return agentProviders.selectedModel(providerType)
  }

  function selectedEffortForProvider(providerType) {
    return agentProviders.selectedEffort(providerType)
  }

  function selectedAgentForProvider(providerType) {
    return agentProviders.selectedAgent(providerType)
  }

  function defaultModelForProvider(providerType) {
    return agentProviders.defaultModel(providerType)
  }

  function defaultEffortForProvider(providerType, modelId) {
    return agentProviders.defaultEffort(providerType, modelId)
  }

  function defaultAgentForProvider(providerType) {
    return agentProviders.defaultAgent(providerType)
  }

  function effectiveModelForProvider(providerType) {
    return agentProviders.effectiveModel(providerType)
  }

  function effectiveEffortForProvider(providerType) {
    return agentProviders.effectiveEffort(providerType)
  }

  function effectiveAgentForProvider(providerType) {
    return agentProviders.effectiveAgent(providerType)
  }

  function modelEffortsForProvider(providerType, modelId) {
    return agentProviders.modelEfforts(providerType, modelId)
  }

  function setModelForProvider(providerType, value) {
    agentProviders.setModel(providerType, value)
  }

  function setEffortForProvider(providerType, value) {
    agentProviders.setEffort(providerType, value)
  }

  function setAgentForProvider(providerType, value) {
    agentProviders.setAgent(providerType, value)
  }

  function projectForId(projectId) {
    var wanted = String(projectId || "")
    if (wanted === "") return null
    for (var i = 0; i < projects.length; i++) {
      if (String(projects[i].id || "") === wanted) return projects[i]
    }
    return null
  }

  function projectRootPath(project) {
    if (!project || !project.roots || project.roots.length === 0) return ""
    return String(project.roots[0].path || "")
  }

  function projectPathForThread(thread) {
    var project = projectForId(thread ? thread.projectId : "")
    var path = projectRootPath(project)
    return path !== "" ? path : String(thread && thread.cwd || "")
  }

  function projectForRoot(path) {
    var wanted = String(path || "")
    for (var i = 0; i < projects.length; i++) {
      if (projectRootPath(projects[i]) === wanted) return projects[i]
    }
    return null
  }

  function moveThreadToProject(thread, targetPath, targetName) {
    var threadId = String(thread && thread.id || "")
    var path = String(targetPath || "")
    if (threadId === "" || path === "" || movingThreadId !== "") return

    movingThreadId = threadId
    pendingMovePath = path
    pendingMoveName = String(targetName || "") || path
    errorText = ""

    var project = projectForRoot(path)
    if (project) {
      assignMovingThreadToProject(String(project.id || ""))
      return
    }

    agentProviders.createProject(threadId, pendingMoveName, path)
  }

  function assignMovingThreadToProject(projectId) {
    if (movingThreadId === "" || projectId === "") {
      failThreadMove("Could not resolve the target Codex project")
      return
    }
    agentProviders.moveThread(movingThreadId, projectId)
  }

  function failThreadMove(message, silent) {
    agentProviders.clearMoveRequests()
    movingThreadId = ""
    pendingMovePath = ""
    pendingMoveName = ""
    if (!silent) errorText = String(message || "Could not move the Codex thread")
  }

  function finishThreadMove() {
    agentProviders.clearMoveRequests()
    movingThreadId = ""
    pendingMovePath = ""
    pendingMoveName = ""
    refreshProjects()
    scheduleEventRefresh()
  }

  function threadStatus(threadId) {
    return threadStatuses[String(threadId || "")] || "done"
  }

  function threadUnread(threadId) {
    return unreadThreads[String(threadId || "")] === true
  }

  function markThreadSeen(threadId) {
    var id = String(threadId || "")
    if (id === "" || unreadThreads[id] !== true) return
    var nextUnread = Object.assign({}, unreadThreads)
    delete nextUnread[id]
    unreadThreads = nextUnread
  }

  function applyThreadStatuses(nextStatuses) {
    var nextUnread = ThreadStateLogic.nextUnreadThreads(
      threadStatuses, unreadThreads, nextStatuses, activeThreadId)
    threadStatuses = nextStatuses
    unreadThreads = nextUnread
  }

  function remoteStatusValue(status) {
    return ThreadStateLogic.remoteStatusValue(status)
  }

  function applyRemoteThreadStatuses() {
    var next = ({})
    for (var i = 0; i < threads.length; i++) {
      var thread = threads[i]
      if (thread && thread.id)
        next[String(thread.id)] = remoteStatusValue(thread.status)
    }
    applyThreadStatuses(next)
  }

  function applyRemoteStatusNotification(params) {
    var id = String(params && params.threadId || "")
    if (id === "") return
    var next = Object.assign({}, threadStatuses)
    next[id] = remoteStatusValue(params.status)
    applyThreadStatuses(next)
  }

  function refreshThreadStatuses() {
    if (threadStatusesProcess.running) return

    var args = [streamGuardPath, "--", threadStatusesHelperPath]
    for (var i = 0; i < threads.length; i++) {
      var thread = threads[i]
      if (!thread || !thread.id || !thread.path) continue
      args.push(String(thread.id), String(thread.path))
    }
    threadStatusesProcess.command = args
    threadStatusesProcess.running = true
  }

  function archiveLocalCodexThread(thread) {
    if (!thread || !thread.id || archivingThreadId !== "") return

    archivingThreadId = String(thread.id)
    archivedThreadSnapshot = thread
    archivedThreadIndex = threadIndex(threads, archivingThreadId)
    setArchiveTombstone(archivingThreadId, true)
    threads = threadsWithoutArchiveTombstones(threads)
    errorText = ""
    if (!agentProviders.archiveLocalCodexRpc(archivingThreadId)) {
      restoreArchivedThread()
      errorText = "Could not reach the Codex App Server"
    }
  }

  function renameLocalCodexThread(thread, name) {
    var id = String(thread && thread.id || "")
    var normalized = String(name || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (id === "" || normalized === "" || renamingThreadId !== "") return false
    renamingThreadId = id
    errorText = ""
    if (!agentProviders.renameLocalCodexRpc(id, normalized)) {
      renamingThreadId = ""
      errorText = "Could not reach the Codex App Server"
      return false
    }
    return true
  }

  function toggleLocalCodexThreadPin(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || pinningThreadId !== "") return

    pinningThreadId = id
    pendingPinValue = thread.isPinned !== true
    errorText = ""
    if (!agentProviders.pinLocalCodexRpc(id, pendingPinValue, pinnedSectionId)) {
      pinningThreadId = ""
      pendingPinValue = false
      errorText = "Could not reach the Codex App Server"
    }
  }

  function applyThreadPin(items, threadId, pinned, returnedThread) {
    return ThreadStateLogic.applyThreadPin(items, threadId, pinned, returnedThread)
  }

  function threadIndex(items, threadId) {
    return ThreadStateLogic.threadIndex(items, threadId)
  }

  function setArchiveTombstone(threadId, archived) {
    var id = String(threadId || "")
    if (id === "") return
    var next = Object.assign({}, archiveTombstones)
    if (archived) next[id] = true
    else delete next[id]
    archiveTombstones = next
  }

  function threadsWithoutArchiveTombstones(items) {
    return ThreadStateLogic.withoutArchiveTombstones(items, archiveTombstones)
  }

  function restoreArchivedThread() {
    var id = archivingThreadId
    setArchiveTombstone(id, false)
    if (archivedThreadSnapshot && threadIndex(threads, id) < 0) {
      var restored = threads.slice()
      var index = Math.max(0, Math.min(archivedThreadIndex, restored.length))
      restored.splice(index, 0, archivedThreadSnapshot)
      threads = restored
    }
    archivedThreadSnapshot = null
    archivedThreadIndex = -1
    archivingThreadId = ""
  }

  function archiveThread(thread) {
    return agentProviders.archiveThread("provider-codex", thread)
  }

  function renameThread(thread, name) {
    return agentProviders.renameThread("provider-codex", thread, name)
  }

  function toggleThreadPin(thread) {
    return agentProviders.toggleThreadPin("provider-codex", thread)
  }

  function openThread(thread, cwdOverride) {
    if (persisted.threadFrontend === "agent-chat") {
      var path = String(cwdOverride || projectPathForThread(thread) || backendHomePath)
      return launchAgentChat(thread, path)
    }
    return agentProviders.openThread("provider-codex", thread, cwdOverride)
  }

  function newProjectThread(projectPath) {
    if (persisted.threadFrontend === "agent-chat")
      return launchAgentChat(null, projectPath)
    return agentProviders.createThread("provider-codex", projectPath)
  }

  function launchAgentChat(thread, cwd) {
    if (agentChatProcess.running) return false
    var path = String(cwd || "")
    var threadId = String(thread && thread.id || "")
    if (path === "" || (thread && threadId === "")) return false

    launchError = ""
    agentChatErrorOutput = ""
    agentChatLaunchKind = threadId !== "" ? "thread" : "project"
    agentChatPendingThreadId = threadId
    if (threadId !== "") {
      launchingThreadId = threadId
      threadLaunchRequested(threadId)
    } else launchingProjectPath = path

    agentChatProcess.command = ActionLogic.agentChatCommand(
      streamGuardPath, agentChatHelperPath, threadId, path, selectedModel,
      selectedEffort, codexServiceTier)
    agentChatProcess.running = true
    return true
  }

  function clearPendingNewThread() {
    agentProviders.clearPendingLocalCodexThread()
  }

  function resolvePendingNewThread() {
    agentProviders.resolvePendingLocalCodexThread()
  }

  function refreshActiveThread() {
    agentProviders.refreshActiveThread()
  }

  function scheduleEventRefresh() {
    eventRefresh.restart()
  }

  function sidebarOpenOnWorkspace(workspaceId) {
    if (sidebarScope === "global") return globalSidebarOpen
    var id = String(workspaceId || "")
    return id !== "" && sidebarOpenWorkspaces[id] === true
  }

  function setSidebarOpenOnWorkspace(workspaceId, value) {
    if (sidebarScope === "global") {
      globalSidebarOpen = !!value
      return
    }
    var id = String(workspaceId || "")
    if (id === "" || id === "0") return
    var next = Object.assign({}, sidebarOpenWorkspaces)
    if (value) next[id] = true
    else delete next[id]
    sidebarOpenWorkspaces = next
  }

  function setSidebarScope(value, workspaceId, visibleNow) {
    var nextScope = value === "global" ? "global" : "workspace"
    if (nextScope === sidebarScope) return
    var id = String(workspaceId || "")
    if (id === "" || id === "0") return
    var currentlyOpen = visibleNow === undefined
      ? sidebarOpenOnWorkspace(id) : !!visibleNow
    if (nextScope === "global") {
      globalSidebarOpen = currentlyOpen
    } else if (id !== "" && id !== "0") {
      var next = Object.assign({}, sidebarOpenWorkspaces)
      if (currentlyOpen) next[id] = true
      else delete next[id]
      sidebarOpenWorkspaces = next
    }
    sidebarScope = nextScope
  }

  function migrateSidebarOpenState(workspaceId) {
    if (!migrateOpenSidebarToActiveWorkspace) return
    migrateOpenSidebarToActiveWorkspace = false
    setSidebarOpenOnWorkspace(workspaceId, true)
  }

  function setSelectedProvider(value) {
    var provider = String(value || "").toLowerCase()
    if (provider !== "codex" && provider !== "claude" && provider !== "opencode")
      return
    persisted.selectedProvider = provider
  }

  function setThreadFrontend(value) {
    persisted.threadFrontend = ActionLogic.normalizeThreadFrontend(value)
  }

  function toggleThreadFrontend() {
    setThreadFrontend(persisted.threadFrontend === "agent-chat"
      ? "terminal" : "agent-chat")
    return persisted.threadFrontend
  }

  function setFastMode(value) {
    persisted.fastMode = value === true
  }

  function toggleFastMode() {
    setFastMode(!persisted.fastMode)
    return persisted.fastMode
  }

  function setCollapsedProjects(value) {
    collapsedProjects = Object.assign({}, value || ({}))
  }

  function setCollapsedRemotes(value) {
    collapsedRemotes = Object.assign({}, value || ({}))
  }

  function setPinnedSections(value) {
    pinnedSections = Object.assign({}, value || ({}))
  }

  function loadSidebarSettings(raw) {
    if (sidebarSettingsLoaded) return

    var parsed = null
    try {
      parsed = String(raw || "").trim() === "" ? null : JSON.parse(raw)
    } catch (error) {
      console.warn("Codex Threads: invalid sidebar state:", error)
    }

    if (parsed) {
      hydratingSidebarSettings = true
      var parsedOpenWorkspaces = parsed.openWorkspaces
        && typeof parsed.openWorkspaces === "object"
        && !Array.isArray(parsed.openWorkspaces)
        ? Object.assign({}, parsed.openWorkspaces) : ({})
      sidebarOpenWorkspaces = parsedOpenWorkspaces
      sidebarScope = parsed.scope === "global" ? "global" : "workspace"
      globalSidebarOpen = typeof parsed.globalOpen === "boolean"
        ? parsed.globalOpen : parsed.open === true
      migrateOpenSidebarToActiveWorkspace = Object.keys(parsedOpenWorkspaces).length === 0
        && parsed.open === true
      persisted.sidebarOpen = parsed.open === true
      if (parsed.provider === "codex" || parsed.provider === "claude"
          || parsed.provider === "opencode")
        persisted.selectedProvider = parsed.provider
      persisted.selectedModel = String(parsed.model || "")
      persisted.selectedEffort = String(parsed.effort || "")
      persisted.threadFrontend = ActionLogic.normalizeThreadFrontend(parsed.threadFrontend)
      persisted.fastMode = parsed.fastMode === true
      var providerSettings = parsed.providerSettings && typeof parsed.providerSettings === "object"
        ? parsed.providerSettings : ({})
      agentProviders.loadSettings(providerSettings)
      collapsedProjects = parsed.collapsedProjects
        && typeof parsed.collapsedProjects === "object"
        && !Array.isArray(parsed.collapsedProjects)
        ? Object.assign({}, parsed.collapsedProjects) : ({})
      collapsedRemotes = parsed.collapsedRemotes
        && typeof parsed.collapsedRemotes === "object"
        && !Array.isArray(parsed.collapsedRemotes)
        ? Object.assign({}, parsed.collapsedRemotes) : ({})
      pinnedSections = parsed.pinnedSections
        && typeof parsed.pinnedSections === "object"
        && !Array.isArray(parsed.pinnedSections)
        ? Object.assign({}, parsed.pinnedSections) : ({})
      hydratingSidebarSettings = false
    }

    sidebarSettingsLoaded = true
    if (!parsed || Number(parsed.version || 0) < 13) sidebarSaveTimer.restart()
    startAppServer()
  }

  function flushSidebarSettings() {
    if (!sidebarSettingsLoaded) return
    sidebarSettingsFile.setText(JSON.stringify({
      version: 13,
      open: sidebarOpen,
      scope: sidebarScope,
      globalOpen: globalSidebarOpen,
      openWorkspaces: sidebarOpenWorkspaces,
      provider: persisted.selectedProvider,
      model: persisted.selectedModel,
      effort: persisted.selectedEffort,
      threadFrontend: persisted.threadFrontend,
      fastMode: persisted.fastMode,
      collapsedProjects: collapsedProjects,
      collapsedRemotes: collapsedRemotes,
      pinnedSections: pinnedSections,
      providerSettings: agentProviders.settingsObject()
    }, null, 2) + "\n")
  }

  Process {
    id: threadStatusesProcess
    running: false

    stdout: SplitParser {
      onRead: function(line) {
        try {
          root.applyThreadStatuses(JSON.parse(String(line || "{}")))
        } catch (error) {
          console.warn("Codex Threads: invalid thread statuses:", error)
        }
      }
    }
  }

  Process {
    id: agentChatProcess
    running: false
    stderr: SplitParser {
      onRead: function(line) {
        root.agentChatErrorOutput = (root.agentChatErrorOutput
          + String(line || "") + "\n").slice(-30000)
      }
    }
    onExited: function(exitCode) {
      var kind = root.agentChatLaunchKind
      var threadId = root.agentChatPendingThreadId
      if (exitCode !== 0) {
        root.launchError = root.agentChatErrorOutput.trim()
          || (kind === "thread"
            ? "Could not open the thread in Agent Chat"
            : "Could not open Agent Chat in the project")
      } else if (kind === "thread") root.activeThreadId = threadId

      if (kind === "thread") root.launchingThreadId = ""
      else if (kind === "project") root.launchingProjectPath = ""
      root.agentChatLaunchKind = ""
      root.agentChatPendingThreadId = ""
      root.scheduleEventRefresh()
    }
  }

  Process {
    id: terminalOpenProcess
    running: false
    stderr: SplitParser {
      onRead: function(line) {
        root.terminalErrorOutput = (root.terminalErrorOutput
          + String(line || "") + "\n").slice(-30000)
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.launchError = root.terminalErrorOutput.trim() || "Could not open the terminal"
    }
  }

  Process {
    id: threadEventsProcess
    command: [root.threadEventsHelperPath]
    running: false

    stdout: SplitParser {
      onRead: function(line) {
        var event = String(line || "")
        if (event.indexOf("rollout-") < 0) return

        // A rollout can receive many writes per second. Status stays live, but
        // the heavier list refresh waits until the burst settles. New files
        // are listed immediately so externally-created threads appear quickly.
        rolloutStatusDebounce.restart()
        rolloutSettleDebounce.restart()
        if (event.indexOf("CREATE") >= 0 || event.indexOf("MOVED_TO") >= 0)
          rolloutStructureDebounce.restart()
      }
    }

    onExited: if (!root.shuttingDown)
      threadEventsRestart.restart()
  }

  onActiveThreadIdChanged: {
    markThreadSeen(activeThreadId)
    scheduleProviderSnapshot()
  }

  FileView {
    id: providerSnapshotFile
    path: root.providerSnapshotPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.attachProviderSnapshot(text())
    onLoadFailed: root.attachProviderSnapshot("")
  }

  FileView {
    id: sidebarSettingsFile
    path: root.sidebarSettingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSidebarSettings(text())
    onLoadFailed: root.loadSidebarSettings("")
  }

  Timer {
    id: providerSnapshotTimer
    interval: 100
    repeat: false
    onTriggered: root.flushProviderSnapshot()
  }

  Timer {
    id: sidebarSaveTimer
    interval: 100
    repeat: false
    onTriggered: root.flushSidebarSettings()
  }

  Timer {
    // App Server events normally refresh immediately; polling is the fallback
    // if inotify or an App Server event is ever missed.
    interval: 60000
    running: root.ready
    repeat: true
    onTriggered: {
      root.refreshThreads()
      root.refreshThreadStatuses()
      root.refreshActiveThread()
    }
  }

  Timer {
    interval: 900000
    running: root.ready
    repeat: true
    onTriggered: root.refreshRateLimits()
  }

  Timer {
    id: eventRefresh
    interval: 350
    repeat: false
    onTriggered: root.refreshThreads()
  }

  Timer {
    id: rolloutStatusDebounce
    interval: 750
    repeat: false
    onTriggered: root.refreshThreadStatuses()
  }

  Timer {
    id: rolloutStructureDebounce
    interval: 200
    repeat: false
    onTriggered: {
      root.refreshActiveThread()
      eventRefresh.restart()
    }
  }

  Timer {
    id: rolloutSettleDebounce
    interval: 2000
    repeat: false
    onTriggered: eventRefresh.restart()
  }

  Timer {
    id: threadEventsRestart
    interval: 1500
    repeat: false
    onTriggered: if (!root.shuttingDown && !threadEventsProcess.running)
      threadEventsProcess.running = true
  }

  Component.onCompleted: {
    threadEventsProcess.running = true
  }
  Component.onDestruction: {
    flushProviderSnapshot()
    shuttingDown = true
    threadEventsProcess.running = false
  }
}
