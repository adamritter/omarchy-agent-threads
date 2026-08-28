.pragma library
// Purpose: Provides deterministic Agent Provider decisions shared by QML adapters.

var supportedProviders = ["codex", "claude", "opencode"]
var supportedConnections = ["local", "ssh", "app-server"]

function providerType(value) {
  var normalized = String(value || "codex").toLowerCase()
  return supportedProviders.indexOf(normalized) >= 0 ? normalized : "codex"
}

function connectionType(value, legacyType) {
  var normalized = String(value || "").toLowerCase()
  if (supportedConnections.indexOf(normalized) >= 0) return normalized
  var legacy = String(legacyType || "").toLowerCase()
  if (legacy === "ssh" || legacy === "app-server") return legacy
  return "local"
}

function capabilities(provider, connection, advertised) {
  var type = providerType(provider)
  var transport = connectionType(connection)
  var defaults = {
    threads: true,
    projects: true,
    status: true,
    openThread: true,
    createThread: true,
    renameThread: true,
    archiveThread: true,
    pinThread: true,
    models: true,
    reasoningEffort: true,
    agents: type !== "codex",
    filesystem: transport !== "app-server",
    directAppServer: type === "codex" && transport === "app-server"
  }
  if (!advertised || typeof advertised !== "object" || Array.isArray(advertised))
    return defaults
  return Object.assign(defaults, advertised)
}

function normalizeHost(host, fallback) {
  var source = host && typeof host === "object" && !Array.isArray(host) ? host : ({})
  var defaults = fallback && typeof fallback === "object" && !Array.isArray(fallback)
    ? fallback : ({})
  var result = Object.assign({}, defaults, source)
  result.providerType = providerType(result.providerType)
  result.connectionType = connectionType(result.connectionType, result.type)
  result.capabilities = capabilities(
    result.providerType, result.connectionType, result.capabilities)
  if (!Array.isArray(result.threads)) result.threads = []
  if (!Array.isArray(result.projects)) result.projects = []
  if (!Array.isArray(result.models)) result.models = []
  if (!Array.isArray(result.agents)) result.agents = []
  return result
}

function normalizeHosts(hosts) {
  if (!Array.isArray(hosts)) return []
  var result = []
  var seen = ({})
  for (var i = 0; i < hosts.length; i++) {
    var host = normalizeHost(hosts[i])
    var id = String(host.id || "")
    if (id === "" || seen[id] === true) continue
    seen[id] = true
    result.push(host)
  }
  return result
}

function hostById(hosts, hostId) {
  var wanted = String(hostId || "")
  var entries = Array.isArray(hosts) ? hosts : []
  for (var i = 0; i < entries.length; i++) {
    if (String(entries[i] && entries[i].id || "") === wanted) return entries[i]
  }
  return null
}

function isLocalCodexHost(hostId) {
  return String(hostId || "") === "provider-codex"
}

function modelId(entry) {
  return String(entry && (entry.model || entry.id) || "")
}

function modelEntry(models, wantedId) {
  var entries = Array.isArray(models) ? models : []
  var wanted = String(wantedId || "")
  var fallback = null
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i] || ({})
    if (wanted !== "" && modelId(entry) === wanted) return entry
    if (entry.isDefault === true) fallback = entry
  }
  if (wanted !== "") return null
  return fallback || (entries.length > 0 ? entries[0] : null)
}

function modelEfforts(entry) {
  var source = entry && Array.isArray(entry.supportedReasoningEfforts)
    ? entry.supportedReasoningEfforts
    : (entry && Array.isArray(entry.efforts) ? entry.efforts : [])
  var result = []
  for (var i = 0; i < source.length; i++) {
    var effort = String(source[i] && (source[i].reasoningEffort || source[i].effort)
      || source[i] || "")
    if (effort !== "" && result.indexOf(effort) < 0) result.push(effort)
  }
  return result
}

function supportedEffort(efforts, effort) {
  var value = String(effort || "")
  return value !== "" && (efforts.length === 0 || efforts.indexOf(value) >= 0)
}

function modelState(models, config, selectedModel, selectedEffort, modelOverride) {
  var entries = Array.isArray(models) ? models : []
  var settings = config && typeof config === "object" && !Array.isArray(config)
    ? config : ({})
  var catalogDefault = modelEntry(entries, "")
  var defaultModel = String(settings.model || modelId(catalogDefault))
  var selectedModelId = String(selectedModel || "")
  var effectiveModel = selectedModelId || defaultModel
  var requestedModel = modelOverride !== undefined && String(modelOverride || "") !== ""
    ? String(modelOverride) : effectiveModel
  var info = modelEntry(entries, requestedModel)
  if (!info && requestedModel === "") info = catalogDefault
  var efforts = modelEfforts(info)
  var configuredEffort = String(settings.model_reasoning_effort || settings.effort || "")
  var catalogEffort = String(info
    && (info.defaultReasoningEffort || info.defaultEffort) || "")
  var defaultEffort = supportedEffort(efforts, configuredEffort)
    ? configuredEffort : catalogEffort
  var selectedEffortId = String(selectedEffort || "")
  var effectiveEffort = supportedEffort(efforts, selectedEffortId)
    ? selectedEffortId : defaultEffort
  return {
    models: entries,
    model: info,
    selectedModel: selectedModelId,
    selectedEffort: selectedEffortId,
    defaultModel: defaultModel,
    defaultEffort: defaultEffort,
    effectiveModel: effectiveModel,
    effectiveEffort: effectiveEffort,
    efforts: efforts
  }
}
