// Purpose: Provides shared Thread Store Settings API state and operations to the plugin.
import QtQuick

QtObject {
  required property var preferences
  required property var modelSettings

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

  function setSelectedModel(value) {
    preferences.setSelectedModel(value)
  }

  function setSelectedEffort(value) {
    preferences.setSelectedEffort(value)
  }

  function selectedModelInfo() {
    return modelSettings.modelState("codex").model
  }

  function effectiveModel() {
    return modelSettings.effectiveModel("codex")
  }

  function effectiveEffort() {
    return modelSettings.effectiveEffort("codex")
  }

  function selectedModelEfforts(modelId) {
    return modelSettings.modelEfforts("codex", modelId)
  }

  function providerHost(providerType) {
    return modelSettings.providerHost(providerType)
  }

  function modelsForProvider(providerType) {
    return modelSettings.models(providerType)
  }

  function agentsForProvider(providerType) {
    return modelSettings.agents(providerType)
  }

  function selectedModelForProvider(providerType) {
    return modelSettings.selectedModel(providerType)
  }

  function selectedEffortForProvider(providerType) {
    return modelSettings.selectedEffort(providerType)
  }

  function selectedAgentForProvider(providerType) {
    return modelSettings.selectedAgent(providerType)
  }

  function defaultModelForProvider(providerType) {
    return modelSettings.defaultModel(providerType)
  }

  function defaultEffortForProvider(providerType, modelId) {
    return modelSettings.defaultEffort(providerType, modelId)
  }

  function defaultAgentForProvider(providerType) {
    return modelSettings.defaultAgent(providerType)
  }

  function effectiveModelForProvider(providerType) {
    return modelSettings.effectiveModel(providerType)
  }

  function effectiveEffortForProvider(providerType) {
    return modelSettings.effectiveEffort(providerType)
  }

  function effectiveAgentForProvider(providerType) {
    return modelSettings.effectiveAgent(providerType)
  }

  function modelEffortsForProvider(providerType, modelId) {
    return modelSettings.modelEfforts(providerType, modelId)
  }

  function setModelForProvider(providerType, value) {
    modelSettings.setModel(providerType, value)
  }

  function setEffortForProvider(providerType, value) {
    modelSettings.setEffort(providerType, value)
  }

  function setAgentForProvider(providerType, value) {
    modelSettings.setAgent(providerType, value)
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
