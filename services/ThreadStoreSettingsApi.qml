import QtQuick

QtObject {
  required property var preferences

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
