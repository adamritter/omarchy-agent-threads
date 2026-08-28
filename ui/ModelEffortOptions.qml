// Purpose: Implements the Model Effort Options user-interface component.
import QtQuick

QtObject {
  required property var panel
  required property var service
  required property string providerType
  property var contextHost
  required property string contextPath

  function contextDefaults() {
    var values = contextHost && contextHost.projectDefaults
    return values && typeof values === "object" && values[contextPath]
      ? values[contextPath] : (contextHost || ({}))
  }
  function compactModelLabel(value) {
    var label = String(value || "default")
    if (label === "") return "default"
    var parts = label.replace(/^(gpt|claude)-/i, "").replace(/-/g, " ").split(" ")
    for (var i = 0; i < parts.length; i++) {
      if (/^[a-z]/.test(parts[i]))
        parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
    }
    return parts.join(" ")
  }
  
  function effectiveModelLabel() {
    if (providerType === "codex")
      return compactModelLabel(service.settings.effectiveModel() || "gpt-5.6-sol")
    var selected = selectedModel()
    var defaults = contextDefaults()
    var effective = selected !== "" ? selected
      : String(defaults.defaultModel || defaults.model || "")
    return compactModelLabel(effective || "default")
  }
  
  function effectiveEffortLabel() {
    var effort = providerType === "codex"
      ? String(service.settings.effectiveEffort() || "medium")
      : String(selectedEffort() || contextDefaultEffort())
    if (effort === "") return ""
    return effort.charAt(0).toUpperCase() + effort.slice(1)
  }
  
  function selectorText() {
    var parts = [effectiveModelLabel()]
    var effort = effectiveEffortLabel()
    if (effort !== "") parts.push(effort)
    var agent = effectiveAgent()
    if (agent !== "") parts.push("@" + agent)
    return parts.join(" ") + " ▾"
  }
  
  function modelChoices() {
    var defaults = contextDefaults()
    var defaultModel = providerType === "codex" ? service.settings.defaultModelForProvider(providerType)
      : String(defaults.defaultModel || defaults.model || "")
    var result = [{
      id: "",
      label: "default" + (defaultModel !== ""
        ? " · " + compactModelLabel(defaultModel) : "")
    }]
    var entries = providerType !== "codex" && contextHost
        && Array.isArray(contextHost.models)
      ? contextHost.models : service.settings.modelsForProvider(providerType)
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i] || ({})
      var id = String(entry.model || entry.id || "")
      if (id === "") continue
      result.push({
        id: id,
        label: String(entry.displayName || entry.name || id),
        isDefault: entry.isDefault === true
      })
    }
    return result
  }
  
  function effortChoices() {
    var defaultEffort = contextDefaultEffort()
    var result = [{
      id: "",
      label: "default" + (defaultEffort !== "" ? " · " + defaultEffort : "")
    }]
    var efforts = contextModelEfforts(service.settings.selectedModelForProvider(providerType))
    for (var i = 0; i < efforts.length; i++)
      result.push({ id: efforts[i], label: efforts[i] })
    return result
  }
  
  function agentChoices() {
    var defaultAgent = contextDefaultAgent()
    var result = [{
      id: "",
      label: "default" + (defaultAgent !== "" ? " · @" + defaultAgent : "")
    }]
    var agents = contextAgentEntries()
    for (var i = 0; i < agents.length; i++) {
      var id = String(agents[i] && agents[i].id || "")
      if (id !== "") result.push({ id: id, label: String(agents[i].name || id) })
    }
    return result
  }
  
  function selectedModel() { return service.settings.selectedModelForProvider(providerType) }
  function selectedEffort() { return service.settings.selectedEffortForProvider(providerType) }
  function selectedAgent() { return service.settings.selectedAgentForProvider(providerType) }
  
  function contextAgentEntries() {
    if (providerType !== "codex" && contextHost) {
      var scoped = contextHost.projectAgents
      if (scoped && typeof scoped === "object" && Array.isArray(scoped[contextPath]))
        return scoped[contextPath]
    }
    return contextHost && Array.isArray(contextHost.agents)
      ? contextHost.agents : service.settings.agentsForProvider(providerType)
  }
  
  function contextDefaultAgent() {
    if (providerType === "codex") return ""
    var defaults = contextDefaults()
    return String(defaults.defaultAgent || defaults.agent || "")
  }
  
  function effectiveAgent() {
    return selectedAgent() || contextDefaultAgent()
  }
  
  function hasAgentChoices() {
    return (providerType === "claude" || providerType === "opencode")
      && (contextAgentEntries().length > 0 || contextDefaultAgent() !== "")
  }
  
  function contextModelEfforts(modelId) {
    if (providerType === "codex" || !contextHost)
      return service.settings.modelEffortsForProvider(providerType, modelId)
    var wanted = String(modelId || "")
    if (wanted === "") return service.settings.modelEffortsForProvider(providerType, "")
    var entries = Array.isArray(contextHost.models) ? contextHost.models : []
    for (var i = 0; i < entries.length; i++) {
      if (String(entries[i] && entries[i].id || "") === wanted)
        return Array.isArray(entries[i].efforts) ? entries[i].efforts : []
    }
    return []
  }
  
  function contextDefaultEffort() {
    if (providerType === "codex")
      return service.settings.defaultEffortForProvider(providerType, selectedModel())
    var selected = selectedModel()
    if (selected !== "" && contextHost) {
      var entries = Array.isArray(contextHost.models) ? contextHost.models : []
      for (var i = 0; i < entries.length; i++) {
        if (String(entries[i] && entries[i].id || "") === selected)
          return String(entries[i].defaultEffort || "")
      }
    }
    var defaults = contextDefaults()
    return String(defaults.defaultEffort || defaults.effort || "")
  }
}
