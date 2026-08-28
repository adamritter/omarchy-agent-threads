// Purpose: Implements the Agent Provider Models provider integration boundary.
import QtQuick
import "../logic/AgentProviderLogic.js" as AgentProviderLogic

Item {
  required property var codexModels
  required property var codexConfig
  required property var settings
  required property var registry

  function providerHost(providerType) { return registry.host(providerType) }
  function modelState(providerType, modelId) {
    var type = AgentProviderLogic.providerType(providerType)
    if (type === "codex") {
      return AgentProviderLogic.modelState(
        codexModels, codexConfig,
        settings.selectedModel, settings.selectedEffort, modelId)
    }
    var selected = registry.selectedModel(type)
    var requested = modelId !== undefined ? modelId : selected
    return AgentProviderLogic.modelState(registry.models(type), {
      model: registry.defaultModel(type),
      model_reasoning_effort: registry.defaultEffort(type, requested)
    }, selected, registry.selectedEffort(type), modelId)
  }
  function models(providerType) {
    var type = AgentProviderLogic.providerType(providerType)
    return type === "codex" ? (codexModels || []) : registry.models(type)
  }
  function agents(providerType) { return registry.agents(providerType) }
  function selectedModel(providerType) {
    var type = AgentProviderLogic.providerType(providerType)
    return type === "codex" ? String(settings.selectedModel || "")
      : registry.selectedModel(type)
  }
  function selectedEffort(providerType) {
    var type = AgentProviderLogic.providerType(providerType)
    return type === "codex" ? String(settings.selectedEffort || "")
      : registry.selectedEffort(type)
  }
  function selectedAgent(providerType) { return registry.selectedAgent(providerType) }
  function defaultModel(providerType) { return modelState(providerType).defaultModel }
  function defaultEffort(providerType, modelId) {
    return modelState(providerType, modelId).defaultEffort
  }
  function defaultAgent(providerType) { return registry.defaultAgent(providerType) }
  function effectiveModel(providerType) { return modelState(providerType).effectiveModel }
  function effectiveEffort(providerType) { return modelState(providerType).effectiveEffort }
  function effectiveAgent(providerType) { return registry.effectiveAgent(providerType) }
  function modelEfforts(providerType, modelId) {
    return modelState(providerType, modelId).efforts
  }
  function setModel(providerType, value) {
    var type = AgentProviderLogic.providerType(providerType)
    if (type === "codex") settings.setSelectedModel(value)
    else registry.setModel(type, value)
  }
  function setEffort(providerType, value) {
    var type = AgentProviderLogic.providerType(providerType)
    if (type === "codex") settings.setSelectedEffort(value)
    else registry.setEffort(type, value)
  }
  function setAgent(providerType, value) { registry.setAgent(providerType, value) }
  function loadSettings(settings) { registry.loadSettings(settings) }
  function settingsObject() { return registry.settingsObject() }
}
