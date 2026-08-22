pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../providers" as Providers

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
  readonly property alias ready: appServerClient.ready
  readonly property alias loading: appServerClient.loading
  readonly property alias refreshQueued: appServerClient.refreshQueued
  property bool shuttingDown: false
  property string errorText: ""
  property string launchError: ""
  property string launchingThreadId: ""
  property string launchingProjectPath: ""
  property string archivingThreadId: ""
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
  readonly property alias remoteConfigLoaded: remoteProvider.configLoaded
  readonly property alias remoteConfig: remoteProvider.remoteConfig
  readonly property var remoteHosts: remoteProvider.remoteHosts.concat(providerRegistry.hosts)
  readonly property alias remoteQueryHostId: remoteProvider.queryHostId
  readonly property string remoteActionHostId: remoteProvider.actionHostId !== ""
    ? remoteProvider.actionHostId
    : providerRegistry.actionHostId
  property alias remoteAddError: remoteProvider.addError
  readonly property alias sshHosts: remoteProvider.sshHosts
  readonly property alias sshHostsLoading: remoteProvider.sshHostsLoading
  readonly property alias sshHostsError: remoteProvider.sshHostsError
  property bool sidebarSettingsLoaded: false
  property bool hydratingSidebarSettings: false
  property var collapsedProjects: ({})
  property var collapsedRemotes: ({})
  property var pinnedSections: ({})
  readonly property alias lastRefreshMs: appServerClient.lastRefreshMs

  readonly property string threadStatusesHelperPath: Qt.resolvedUrl("../bin/omarchy-codex-thread-statuses")
    .toString().replace(/^file:\/\//, "")
  readonly property string threadEventsHelperPath: Qt.resolvedUrl("../bin/omarchy-codex-thread-events")
    .toString().replace(/^file:\/\//, "")
  readonly property string localHome: Quickshell.env("HOME") || "/tmp"
  readonly property string backendHomePath: localHome
  readonly property string pinnedSectionId: "01984de2-8f74-7c91-a3b2-5c5e937cf318"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string sidebarSettingsPath: stateHome + "/omarchy/codex-threads.json"
  readonly property alias sidebarOpen: persisted.sidebarOpen
  readonly property alias selectedProvider: persisted.selectedProvider
  readonly property alias selectedModel: persisted.selectedModel
  readonly property alias selectedEffort: persisted.selectedEffort

  PersistentProperties {
    id: persisted
    reloadableId: "adam-codex-threads"
    property bool sidebarOpen: false
    property string selectedProvider: "codex"
    property string selectedModel: ""
    property string selectedEffort: ""
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

  signal threadLaunchRequested(string threadId)

  Providers.RemoteAgentProvider {
    id: remoteProvider
    controller: root
  }

  Providers.CodexAppServerClient {
    id: appServerClient
    controller: root
  }

  Providers.LocalCodexProvider {
    id: localCodexProvider
    controller: root
  }

  Providers.ProviderRegistry {
    id: providerRegistry
    controller: root
    onSettingsChanged: {
      if (!root.hydratingSidebarSettings) sidebarSaveTimer.restart()
    }
  }

  function resetBackendState() {
    appServerClient.reset()
  }

  function startAppServer() {
    appServerClient.start()
  }

  function remoteHostById(hostId) {
    var provider = localAgentProvider(hostId)
    if (provider) return provider.host
    return remoteProvider.hostById(hostId)
  }

  function remotePathForThread(host, thread) {
    var provider = localAgentProvider(host ? host.id : "")
    if (provider) return provider.pathForThread(thread)
    return remoteProvider.pathForThread(host, thread)
  }

  function remoteThreadStatus(thread) {
    var provider = localAgentProviderForThread(thread)
    if (provider) return provider.threadStatus(thread)
    return remoteProvider.threadStatus(thread)
  }

  function refreshRemotes(hostId) {
    var provider = localAgentProvider(hostId)
    if (provider) {
      provider.refresh()
      return
    }
    remoteProvider.refresh(hostId)
  }

  function localAgentProvider(hostId) {
    return providerRegistry.providerForHost(hostId)
  }

  function localAgentProviderForThread(thread) {
    return providerRegistry.providerForThread(thread)
  }

  function addRemote(label, type, address, home, tokenFile, providerType) {
    return remoteProvider.add(label, type, address, home, tokenFile, providerType)
  }

  function sshHostEnabled(alias, providerType) {
    return remoteProvider.sshHostEnabled(alias, providerType)
  }

  function refreshSshHosts() {
    remoteProvider.refreshSshHosts()
  }

  function archiveRemoteThread(hostId, thread) {
    var provider = localAgentProvider(hostId)
    if (provider) {
      provider.archiveThread(thread)
      return
    }
    remoteProvider.archiveThread(hostId, thread)
  }

  function toggleRemoteThreadPin(hostId, thread) {
    var provider = localAgentProvider(hostId)
    if (provider) {
      provider.toggleThreadPin(thread)
      return
    }
    remoteProvider.toggleThreadPin(hostId, thread)
  }

  function openRemoteThread(hostId, thread, path) {
    var provider = localAgentProvider(hostId)
    if (provider) {
      provider.openThread(thread, path)
      return
    }
    remoteProvider.openThread(hostId, thread, path)
  }

  function newRemoteThread(hostId, path) {
    var provider = localAgentProvider(hostId)
    if (provider) {
      provider.newThread(path)
      return
    }
    remoteProvider.newThread(hostId, path)
  }

  function refreshThreads() {
    appServerClient.refreshThreads()
  }

  function threadIsPinned(thread) {
    if (!thread) return false
    if (thread.isPinned === true) return true
    var section = thread.section
    return section !== null && section !== undefined
      && (String(section.id || "") === pinnedSectionId
        || String(section.name || "").toLowerCase() === "pinned")
  }

  function normalizePinnedThreads(items) {
    var normalized = []
    for (var i = 0; i < items.length; i++) {
      var thread = items[i]
      normalized.push(Object.assign({}, thread, { isPinned: threadIsPinned(thread) }))
    }
    return normalized
  }

  function refreshProjects() {
    appServerClient.refreshProjects()
  }

  function refreshRateLimits() {
    appServerClient.refreshRateLimits()
  }

  function refreshModels() {
    appServerClient.refreshModels()
  }

  function refreshConfig() {
    appServerClient.refreshConfig()
  }

  function setSelectedModel(value) {
    persisted.selectedModel = String(value || "")
    if (persisted.selectedEffort === "") return
    var supported = selectedModelEfforts()
    if (supported.indexOf(persisted.selectedEffort) < 0)
      persisted.selectedEffort = ""
  }

  function setSelectedEffort(value) {
    persisted.selectedEffort = String(value || "")
  }

  function selectedModelInfo() {
    var wanted = String(persisted.selectedModel || codexConfig.model || "")
    var fallback = null
    for (var i = 0; i < models.length; i++) {
      var entry = models[i]
      if (wanted !== "" && String(entry.model || entry.id || "") === wanted) return entry
      if (entry.isDefault === true) fallback = entry
    }
    return fallback || (models.length > 0 ? models[0] : null)
  }

  function effectiveModel() {
    var configured = String(persisted.selectedModel || codexConfig.model || "")
    if (configured !== "") return configured
    var info = selectedModelInfo() || ({})
    return String(info.model || info.id || "")
  }

  function effectiveEffort() {
    var configured = String(persisted.selectedEffort
      || codexConfig.model_reasoning_effort || "")
    if (configured !== "") return configured
    var info = selectedModelInfo() || ({})
    return String(info.defaultReasoningEffort || "")
  }

  function selectedModelEfforts() {
    var info = selectedModelInfo()
    var entries = info && Array.isArray(info.supportedReasoningEfforts)
      ? info.supportedReasoningEfforts : []
    var result = []
    for (var i = 0; i < entries.length; i++) {
      var effort = String(entries[i] && entries[i].reasoningEffort || entries[i] || "")
      if (effort !== "" && result.indexOf(effort) < 0) result.push(effort)
    }
    return result
  }

  function providerHost(providerType) {
    return providerRegistry.host(providerType)
  }

  function modelsForProvider(providerType) {
    var type = String(providerType || "codex")
    if (type === "codex") return models || []
    return providerRegistry.models(type)
  }

  function agentsForProvider(providerType) {
    return providerRegistry.agents(providerType)
  }

  function selectedModelForProvider(providerType) {
    var type = String(providerType || "codex")
    return type === "codex" ? persisted.selectedModel : providerRegistry.selectedModel(type)
  }

  function selectedEffortForProvider(providerType) {
    var type = String(providerType || "codex")
    return type === "codex" ? persisted.selectedEffort : providerRegistry.selectedEffort(type)
  }

  function selectedAgentForProvider(providerType) {
    return providerRegistry.selectedAgent(providerType)
  }

  function defaultModelForProvider(providerType) {
    var type = String(providerType || "codex")
    if (type === "codex") return effectiveModel()
    return providerRegistry.defaultModel(type)
  }

  function defaultEffortForProvider(providerType, modelId) {
    var type = String(providerType || "codex")
    if (type === "codex") return effectiveEffort()
    return providerRegistry.defaultEffort(type, modelId)
  }

  function defaultAgentForProvider(providerType) {
    return providerRegistry.defaultAgent(providerType)
  }

  function effectiveModelForProvider(providerType) {
    var type = String(providerType || "codex")
    return type === "codex" ? effectiveModel() : providerRegistry.effectiveModel(type)
  }

  function effectiveEffortForProvider(providerType) {
    var type = String(providerType || "codex")
    return type === "codex" ? effectiveEffort() : providerRegistry.effectiveEffort(type)
  }

  function effectiveAgentForProvider(providerType) {
    return providerRegistry.effectiveAgent(providerType)
  }

  function modelEffortsForProvider(providerType, modelId) {
    var type = String(providerType || "codex")
    if (type === "codex") return selectedModelEfforts()
    return providerRegistry.modelEfforts(type, modelId)
  }

  function setModelForProvider(providerType, value) {
    var type = String(providerType || "codex")
    if (type === "codex") setSelectedModel(value)
    else providerRegistry.setModel(type, value)
  }

  function setEffortForProvider(providerType, value) {
    var type = String(providerType || "codex")
    if (type === "codex") setSelectedEffort(value)
    else providerRegistry.setEffort(type, value)
  }

  function setAgentForProvider(providerType, value) {
    providerRegistry.setAgent(providerType, value)
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

    appServerClient.createProject(threadId, pendingMoveName, path)
  }

  function assignMovingThreadToProject(projectId) {
    if (movingThreadId === "" || projectId === "") {
      failThreadMove("Could not resolve the target Codex project")
      return
    }
    appServerClient.moveThread(movingThreadId, projectId)
  }

  function failThreadMove(message, silent) {
    appServerClient.clearMoveRequests()
    movingThreadId = ""
    pendingMovePath = ""
    pendingMoveName = ""
    if (!silent) errorText = String(message || "Could not move the Codex thread")
  }

  function finishThreadMove() {
    appServerClient.clearMoveRequests()
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
    var nextUnread = Object.assign({}, unreadThreads)
    for (var id in nextStatuses) {
      if (threadStatuses[id] === "busy" && nextStatuses[id] === "done"
          && id !== activeThreadId)
        nextUnread[id] = true
      if (id === activeThreadId) delete nextUnread[id]
    }
    threadStatuses = nextStatuses
    unreadThreads = nextUnread
  }

  function remoteStatusValue(status) {
    var type = typeof status === "string"
      ? status : String(status && status.type || "")
    return type === "active" ? "busy" : "done"
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

    var args = [threadStatusesHelperPath]
    for (var i = 0; i < threads.length; i++) {
      var thread = threads[i]
      if (!thread || !thread.id || !thread.path) continue
      args.push(String(thread.id), String(thread.path))
    }
    threadStatusesProcess.command = args
    threadStatusesProcess.running = true
  }

  function archiveThread(thread) {
    if (!thread || !thread.id || archivingThreadId !== "") return

    archivingThreadId = String(thread.id)
    archivedThreadSnapshot = thread
    archivedThreadIndex = threadIndex(threads, archivingThreadId)
    setArchiveTombstone(archivingThreadId, true)
    threads = threadsWithoutArchiveTombstones(threads)
    errorText = ""
    if (!appServerClient.archiveThread(archivingThreadId)) {
      restoreArchivedThread()
      errorText = "Could not reach the Codex App Server"
    }
  }

  function toggleThreadPin(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || pinningThreadId !== "") return

    pinningThreadId = id
    pendingPinValue = thread.isPinned !== true
    errorText = ""
    if (!appServerClient.setThreadPinned(id, pendingPinValue, pinnedSectionId)) {
      pinningThreadId = ""
      pendingPinValue = false
      errorText = "Could not reach the Codex App Server"
    }
  }

  function applyThreadPin(items, threadId, pinned, returnedThread) {
    var wanted = String(threadId || "")
    var next = []
    for (var i = 0; i < items.length; i++) {
      var thread = items[i]
      next.push(String(thread && thread.id || "") === wanted
        ? Object.assign({}, thread, returnedThread || ({}), { isPinned: !!pinned })
        : thread)
    }
    return next
  }

  function threadIndex(items, threadId) {
    var wanted = String(threadId || "")
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") === wanted) return i
    }
    return -1
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
    var visible = []
    for (var i = 0; i < items.length; i++) {
      var thread = items[i]
      if (archiveTombstones[String(thread && thread.id || "")] !== true)
        visible.push(thread)
    }
    return visible
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

  function openThread(thread, cwdOverride) {
    localCodexProvider.openThread(thread, cwdOverride)
  }

  function newProjectThread(projectPath) {
    localCodexProvider.newThread(projectPath)
  }

  function clearPendingNewThread() {
    localCodexProvider.clearPendingNew()
  }

  function resolvePendingNewThread() {
    localCodexProvider.resolvePendingNew()
  }

  function refreshActiveThread() {
    localCodexProvider.refreshActiveThread()
  }

  function scheduleEventRefresh() {
    eventRefresh.restart()
  }

  function setSidebarOpen(value) {
    persisted.sidebarOpen = !!value
  }

  function setSelectedProvider(value) {
    var provider = String(value || "").toLowerCase()
    if (provider !== "codex" && provider !== "claude" && provider !== "opencode")
      return
    persisted.selectedProvider = provider
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
      if (typeof parsed.open === "boolean") persisted.sidebarOpen = parsed.open
      if (parsed.provider === "codex" || parsed.provider === "claude"
          || parsed.provider === "opencode")
        persisted.selectedProvider = parsed.provider
      persisted.selectedModel = String(parsed.model || "")
      persisted.selectedEffort = String(parsed.effort || "")
      var providerSettings = parsed.providerSettings && typeof parsed.providerSettings === "object"
        ? parsed.providerSettings : ({})
      providerRegistry.loadSettings(providerSettings)
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
    if (!parsed || Number(parsed.version || 0) < 9) sidebarSaveTimer.restart()
    startAppServer()
  }

  function flushSidebarSettings() {
    if (!sidebarSettingsLoaded) return
    sidebarSettingsFile.setText(JSON.stringify({
      version: 9,
      open: persisted.sidebarOpen,
      provider: persisted.selectedProvider,
      model: persisted.selectedModel,
      effort: persisted.selectedEffort,
      collapsedProjects: collapsedProjects,
      collapsedRemotes: collapsedRemotes,
      pinnedSections: pinnedSections,
      providerSettings: providerRegistry.settingsObject()
    }, null, 2) + "\n")
  }

  Process {
    id: threadStatusesProcess
    running: false

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.applyThreadStatuses(JSON.parse(String(text || "{}")))
        } catch (error) {
          console.warn("Codex Threads: invalid thread statuses:", error)
        }
      }
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

  onActiveThreadIdChanged: markThreadSeen(activeThreadId)

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
    shuttingDown = true
    threadEventsProcess.running = false
  }
}
