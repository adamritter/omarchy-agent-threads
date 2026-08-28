// Purpose: Provides shared Sidebar Preferences state and operations to the plugin.
import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/SidebarPreferencesLogic.js" as PreferencesLogic

Item {
  id: root

  required property string path
  required property var providerSettings

  property bool loaded: false
  property bool hydrating: false
  property bool migrateOpenToActiveWorkspace: false
  property string scope: "workspace"
  property bool globalOpen: false
  property var openWorkspaces: ({})
  property var collapsedProjects: ({})
  property var collapsedRemotes: ({})
  property var pinnedSections: ({})

  readonly property alias selectedProvider: persisted.selectedProvider
  readonly property alias selectedModel: persisted.selectedModel
  readonly property alias selectedEffort: persisted.selectedEffort
  readonly property alias threadFrontend: persisted.threadFrontend
  readonly property alias threadFrontendChangedBy: persisted.threadFrontendChangedBy
  readonly property alias threadFrontendChangedAt: persisted.threadFrontendChangedAt
  readonly property alias fastMode: persisted.fastMode
  readonly property alias notificationsEnabled: persisted.notificationsEnabled
  readonly property bool sidebarOpen: {
    if (scope === "global") return globalOpen
    for (var workspaceId in openWorkspaces)
      if (openWorkspaces[workspaceId] === true) return true
    return false
  }

  signal ready()

  PersistentProperties {
    id: persisted
    reloadableId: "adam-codex-threads"
    property bool sidebarOpen: false
    property string selectedProvider: "codex"
    property string selectedModel: ""
    property string selectedEffort: ""
    property string threadFrontend: "terminal"
    property string threadFrontendChangedBy: ""
    property double threadFrontendChangedAt: 0
    property bool fastMode: false
    property bool notificationsEnabled: false

    onSidebarOpenChanged: root.scheduleSave()
    onSelectedProviderChanged: root.scheduleSave()
    onSelectedModelChanged: root.scheduleSave()
    onSelectedEffortChanged: root.scheduleSave()
    onThreadFrontendChanged: root.scheduleSave()
    onThreadFrontendChangedByChanged: root.scheduleSave()
    onThreadFrontendChangedAtChanged: root.scheduleSave()
    onFastModeChanged: root.scheduleSave()
    onNotificationsEnabledChanged: root.scheduleSave()
  }

  onCollapsedProjectsChanged: scheduleSave()
  onCollapsedRemotesChanged: scheduleSave()
  onPinnedSectionsChanged: scheduleSave()
  onOpenWorkspacesChanged: scheduleSave()
  onScopeChanged: scheduleSave()
  onGlobalOpenChanged: scheduleSave()

  function scheduleSave() {
    if (loaded && !hydrating) saveTimer.restart()
  }

  function sidebarOpenOnWorkspace(workspaceId) {
    return PreferencesLogic.workspaceOpen(
      scope, globalOpen, openWorkspaces, workspaceId)
  }

  function setSidebarOpenOnWorkspace(workspaceId, value) {
    var result = PreferencesLogic.setWorkspaceOpen(
      scope, globalOpen, openWorkspaces, workspaceId, value === true)
    globalOpen = result.globalOpen
    openWorkspaces = result.openWorkspaces
  }

  function setScope(value, workspaceId, visibleNow) {
    var result = PreferencesLogic.changeScope(
      scope, globalOpen, openWorkspaces, value, workspaceId, visibleNow)
    globalOpen = result.globalOpen
    openWorkspaces = result.openWorkspaces
    scope = result.scope
  }

  function migrateOpenState(workspaceId) {
    if (!migrateOpenToActiveWorkspace) return
    migrateOpenToActiveWorkspace = false
    setSidebarOpenOnWorkspace(workspaceId, true)
  }

  function setSelectedProvider(value) {
    persisted.selectedProvider = PreferencesLogic.provider(
      value, persisted.selectedProvider)
  }

  function setSelectedModel(value) {
    persisted.selectedModel = String(value || "")
    if (persisted.selectedEffort === "") return
    var supported = providerSettings.modelEfforts("codex", persisted.selectedModel)
    if (supported.indexOf(persisted.selectedEffort) < 0)
      persisted.selectedEffort = ""
  }

  function setSelectedEffort(value) {
    persisted.selectedEffort = String(value || "")
  }

  function setThreadFrontend(value, source) {
    var result = PreferencesLogic.frontendPreference(
      threadFrontend, ActionLogic.normalizeThreadFrontend(value), source, Date.now())
    if (!result.changed) return false
    persisted.threadFrontend = result.frontend
    persisted.threadFrontendChangedBy = result.changedBy
    persisted.threadFrontendChangedAt = result.changedAt
    return true
  }

  function toggleThreadFrontend(source) {
    setThreadFrontend(
      threadFrontend === "agent-chat" ? "terminal" : "agent-chat", source)
    return threadFrontend
  }

  function setFastMode(value) { persisted.fastMode = value === true }
  function toggleFastMode() {
    setFastMode(!fastMode)
    return fastMode
  }

  function setNotificationsEnabled(value) {
    persisted.notificationsEnabled = value === true
  }
  function toggleNotifications() {
    setNotificationsEnabled(!notificationsEnabled)
    return notificationsEnabled
  }

  function setCollapsedProjects(value) {
    collapsedProjects = PreferencesLogic.map(value)
  }
  function setCollapsedRemotes(value) {
    collapsedRemotes = PreferencesLogic.map(value)
  }
  function setPinnedSections(value) {
    pinnedSections = PreferencesLogic.map(value)
  }

  function load(raw) {
    if (loaded) return
    var parsed = null
    try {
      parsed = String(raw || "").trim() === "" ? null : JSON.parse(raw)
    } catch (error) {
      console.warn("Codex Threads: invalid sidebar state:", error)
    }

    if (parsed) {
      hydrating = true
      var parsedWorkspaces = parsed.openWorkspaces
        && typeof parsed.openWorkspaces === "object"
        && !Array.isArray(parsed.openWorkspaces)
        ? Object.assign({}, parsed.openWorkspaces) : ({})
      openWorkspaces = parsedWorkspaces
      scope = parsed.scope === "global" ? "global" : "workspace"
      globalOpen = typeof parsed.globalOpen === "boolean"
        ? parsed.globalOpen : parsed.open === true
      migrateOpenToActiveWorkspace = Object.keys(parsedWorkspaces).length === 0
        && parsed.open === true
      persisted.sidebarOpen = parsed.open === true
      setSelectedProvider(parsed.provider)
      persisted.selectedModel = String(parsed.model || "")
      persisted.selectedEffort = String(parsed.effort || "")
      persisted.threadFrontend = ActionLogic.normalizeThreadFrontend(parsed.threadFrontend)
      persisted.threadFrontendChangedBy = String(parsed.threadFrontendChangedBy || "")
      persisted.threadFrontendChangedAt = Math.max(
        0, Number(parsed.threadFrontendChangedAt || 0))
      persisted.fastMode = parsed.fastMode === true
      persisted.notificationsEnabled = parsed.notificationsEnabled === true
      providerSettings.loadSettings(parsed.providerSettings || ({}))
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
      hydrating = false
    }

    loaded = true
    if (!parsed || Number(parsed.version || 0) < 15) saveTimer.restart()
    ready()
  }

  function flush() {
    if (!loaded) return
    settingsFile.setText(JSON.stringify({
      version: 15,
      open: sidebarOpen,
      scope: scope,
      globalOpen: globalOpen,
      openWorkspaces: openWorkspaces,
      provider: selectedProvider,
      model: selectedModel,
      effort: selectedEffort,
      threadFrontend: threadFrontend,
      threadFrontendChangedBy: threadFrontendChangedBy,
      threadFrontendChangedAt: threadFrontendChangedAt,
      fastMode: fastMode,
      notificationsEnabled: notificationsEnabled,
      collapsedProjects: collapsedProjects,
      collapsedRemotes: collapsedRemotes,
      pinnedSections: pinnedSections,
      providerSettings: providerSettings.settingsObject()
    }, null, 2) + "\n")
  }

  FileView {
    id: settingsFile
    path: root.path
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
  }

  Timer {
    id: saveTimer
    interval: 100
    repeat: false
    onTriggered: root.flush()
  }

  Component.onDestruction: flush()
}
