import QtQuick

QtObject {
  required property var preferences

  readonly property bool loaded: preferences.loaded
  readonly property bool hydrating: preferences.hydrating
  readonly property bool sidebarOpen: preferences.sidebarOpen
  readonly property string scope: preferences.scope
  readonly property bool globalOpen: preferences.globalOpen
  readonly property var openWorkspaces: preferences.openWorkspaces
  readonly property var collapsedProjects: preferences.collapsedProjects
  readonly property var collapsedRemotes: preferences.collapsedRemotes
  readonly property var pinnedSections: preferences.pinnedSections
  readonly property string selectedProvider: preferences.selectedProvider
  readonly property string selectedModel: preferences.selectedModel
  readonly property string selectedEffort: preferences.selectedEffort
  readonly property string threadFrontend: preferences.threadFrontend
  readonly property string threadFrontendChangedBy: preferences.threadFrontendChangedBy
  readonly property double threadFrontendChangedAt: preferences.threadFrontendChangedAt
  readonly property bool fastMode: preferences.fastMode
  readonly property bool notificationsEnabled: preferences.notificationsEnabled

  function sidebarOpenOnWorkspace(workspaceId) {
    return preferences.sidebarOpenOnWorkspace(workspaceId)
  }
  
  function setSidebarOpenOnWorkspace(workspaceId, value) {
    preferences.setSidebarOpenOnWorkspace(workspaceId, value)
  }
  
  function setSidebarScope(value, workspaceId, visibleNow) {
    preferences.setScope(value, workspaceId, visibleNow)
  }
  
  function migrateSidebarOpenState(workspaceId) {
    preferences.migrateOpenState(workspaceId)
  }
  
  function setSelectedProvider(value) {
    preferences.setSelectedProvider(value)
  }
  
  function setThreadFrontend(value, source) {
    return preferences.setThreadFrontend(value, source)
  }
  
  function toggleThreadFrontend(source) {
    return preferences.toggleThreadFrontend(source)
  }
  
  function setFastMode(value) {
    preferences.setFastMode(value)
  }
  
  function toggleFastMode() {
    return preferences.toggleFastMode()
  }
  
  function setNotificationsEnabled(value) {
    preferences.setNotificationsEnabled(value)
  }
  
  function toggleNotifications() {
    return preferences.toggleNotifications()
  }
  
  function setCollapsedProjects(value) {
    preferences.setCollapsedProjects(value)
  }
  
  function setCollapsedRemotes(value) {
    preferences.setCollapsedRemotes(value)
  }
  
  function setPinnedSections(value) {
    preferences.setPinnedSections(value)
  }
  
  function loadSidebarSettings(raw) {
    preferences.load(raw)
  }
  
  function flushSidebarSettings() {
    preferences.flush()
  }
}
