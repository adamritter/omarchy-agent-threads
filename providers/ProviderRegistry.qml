import QtQuick

Item {
  id: root

  required property var controller

  property string claudeModel: ""
  property string claudeEffort: ""
  property string claudeAgent: ""
  property string openCodeModel: ""
  property string openCodeEffort: ""
  property string openCodeAgent: ""

  readonly property var hosts: [claudeProvider.host, openCodeProvider.host]
  readonly property string actionHostId: claudeProvider.actionHostId !== ""
    ? claudeProvider.actionHostId : openCodeProvider.actionHostId

  signal settingsChanged()
  signal snapshotsChanged()

  onClaudeModelChanged: settingsChanged()
  onClaudeEffortChanged: settingsChanged()
  onClaudeAgentChanged: settingsChanged()
  onOpenCodeModelChanged: settingsChanged()
  onOpenCodeEffortChanged: settingsChanged()
  onOpenCodeAgentChanged: settingsChanged()

  LocalAgentProvider {
    id: claudeProvider
    controller: root.controller
    providerType: "claude"
    label: "CLAUDE"
    onHostChanged: root.snapshotsChanged()
  }

  LocalAgentProvider {
    id: openCodeProvider
    controller: root.controller
    providerType: "opencode"
    label: "OPENCODE"
    onHostChanged: root.snapshotsChanged()
  }

  function providerByType(providerType) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") return claudeProvider
    if (type === "opencode") return openCodeProvider
    return null
  }

  function providerForHost(hostId) {
    var id = String(hostId || "")
    if (id === claudeProvider.hostId) return claudeProvider
    if (id === openCodeProvider.hostId) return openCodeProvider
    return null
  }

  function providerForThread(thread) {
    return providerByType(thread && thread.providerType)
  }

  function markThreadSeen(threadId) {
    claudeProvider.markThreadSeen(threadId)
    openCodeProvider.markThreadSeen(threadId)
  }

  function snapshotHosts() {
    return {
      claude: claudeProvider.host,
      opencode: openCodeProvider.host
    }
  }

  function restoreSnapshots(snapshots) {
    var values = snapshots && typeof snapshots === "object" ? snapshots : ({})
    claudeProvider.restoreSnapshot(values.claude)
    openCodeProvider.restoreSnapshot(values.opencode)
  }

  function host(providerType) {
    var provider = providerByType(providerType)
    return provider ? provider.host : null
  }

  function models(providerType) {
    var value = host(providerType)
    return value && Array.isArray(value.models) ? value.models : []
  }

  function agents(providerType) {
    var value = host(providerType)
    return value && Array.isArray(value.agents) ? value.agents : []
  }

  function selectedModel(providerType) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") return claudeModel
    if (type === "opencode") return openCodeModel
    return ""
  }

  function selectedEffort(providerType) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") return claudeEffort
    if (type === "opencode") return openCodeEffort
    return ""
  }

  function selectedAgent(providerType) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") return claudeAgent
    if (type === "opencode") return openCodeAgent
    return ""
  }

  function defaultModel(providerType) {
    var value = host(providerType)
    return String(value && value.defaultModel || "")
  }

  function defaultEffort(providerType, modelId) {
    var value = host(providerType)
    var wanted = String(modelId !== undefined ? modelId : selectedModel(providerType))
    if (wanted !== "") {
      var entries = models(providerType)
      for (var i = 0; i < entries.length; i++) {
        if (String(entries[i] && entries[i].id || "") === wanted)
          return String(entries[i].defaultEffort || "")
      }
    }
    return String(value && value.defaultEffort || "")
  }

  function defaultAgent(providerType) {
    var value = host(providerType)
    return String(value && value.defaultAgent || "")
  }

  function effectiveModel(providerType) {
    return selectedModel(providerType) || defaultModel(providerType)
  }

  function effectiveEffort(providerType) {
    return selectedEffort(providerType)
      || defaultEffort(providerType, selectedModel(providerType))
  }

  function effectiveAgent(providerType) {
    return selectedAgent(providerType) || defaultAgent(providerType)
  }

  function modelEfforts(providerType, modelId) {
    var type = String(providerType || "").toLowerCase()
    var wanted = String(modelId !== undefined ? modelId : selectedModel(type))
    if (type === "claude" && wanted === "")
      return ["low", "medium", "high", "xhigh", "max"]
    var entries = models(type)
    for (var i = 0; i < entries.length; i++) {
      if (String(entries[i] && entries[i].id || "") === wanted)
        return Array.isArray(entries[i].efforts) ? entries[i].efforts : []
    }
    return []
  }

  function setModel(providerType, value) {
    var type = String(providerType || "").toLowerCase()
    var model = String(value || "")
    if (type === "claude") claudeModel = model
    else if (type === "opencode") openCodeModel = model
    else return

    var effort = selectedEffort(type)
    if (effort !== "" && modelEfforts(type, model).indexOf(effort) < 0)
      setEffort(type, "")
  }

  function setEffort(providerType, value) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") claudeEffort = String(value || "")
    else if (type === "opencode") openCodeEffort = String(value || "")
  }

  function setAgent(providerType, value) {
    var type = String(providerType || "").toLowerCase()
    if (type === "claude") claudeAgent = String(value || "")
    else if (type === "opencode") openCodeAgent = String(value || "")
  }

  function loadSettings(settings) {
    var values = settings && typeof settings === "object" ? settings : ({})
    var claude = values.claude || ({})
    var openCode = values.opencode || ({})
    claudeModel = String(claude.model || "")
    claudeEffort = String(claude.effort || "")
    claudeAgent = String(claude.agent || "")
    openCodeModel = String(openCode.model || "")
    openCodeEffort = String(openCode.effort || "")
    openCodeAgent = String(openCode.agent || "")
  }

  function settingsObject() {
    return {
      claude: { model: claudeModel, effort: claudeEffort, agent: claudeAgent },
      opencode: { model: openCodeModel, effort: openCodeEffort, agent: openCodeAgent }
    }
  }
}
