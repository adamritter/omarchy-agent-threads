import fs from "node:fs"
import os from "node:os"
import path from "node:path"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const stateHome = process.env.XDG_STATE_HOME || path.join(home, ".local", "state")
const metadataPath = path.join(stateHome, "omarchy", "codex-thread-providers.json")
const openCodeCapabilitiesPath = path.join(stateHome, "omarchy", "opencode-capabilities.json")
const openCodeURL = process.env.OMARCHY_OPENCODE_URL || "http://127.0.0.1:43962"

function readJSON(filePath, fallback = null) {
  try { return JSON.parse(fs.readFileSync(filePath, "utf8")) } catch { return fallback }
}

function loadMetadata() {
  const value = readJSON(metadataPath, {})
  return value && typeof value === "object" ? value : {}
}

function cleanText(value) {
  return String(value || "").replace(/\s+/g, " ").trim()
}

function projectList(threads) {
  const seen = new Set()
  const projects = []
  for (const thread of threads) {
    const directory = String(thread.cwd || "")
    if (!directory || seen.has(directory)) continue
    seen.add(directory)
    projects.push({
      id: directory,
      name: path.basename(directory.replace(/\\\/$/, "")) || directory,
      roots: [{ path: directory }]
    })
  }
  return projects
}

function timestampSeconds(value, fallback = 0) {
  if (typeof value === "number") return value > 100000000000 ? value / 1000 : value
  const parsed = Date.parse(String(value || ""))
  return Number.isFinite(parsed) ? parsed / 1000 : fallback
}

async function requestOpenCodeAt(baseURL, endpoint, options = {}) {
  const response = await fetch(baseURL + endpoint, {
    ...options,
    signal: AbortSignal.timeout(options.timeout || 5000),
    headers: { "content-type": "application/json", ...(options.headers || {}) }
  })
  if (!response.ok) throw new Error(`OpenCode HTTP ${response.status}`)
  if (response.status === 204) return null
  return response.json()
}

async function requestOpenCode(endpoint, options = {}) {
  return requestOpenCodeAt(openCodeURL, endpoint, options)
}

function openCodeRuntimeServers() {
  const runtimeRoot = process.env.XDG_RUNTIME_DIR || "/tmp"
  const runtimeDirectory = path.join(runtimeRoot, `omarchy-codex-threads-${process.getuid()}`)
  let entries = []
  try { entries = fs.readdirSync(runtimeDirectory, { withFileTypes: true }) } catch { return [] }
  return entries.flatMap(entry => {
    const match = /^provider-opencode--(.+)\.server$/.exec(entry.name)
    if (!entry.isFile() || !match) return []
    let url = ""
    try { url = fs.readFileSync(path.join(runtimeDirectory, entry.name), "utf8").trim() } catch { return [] }
    if (!/^http:\/\/(127\.0\.0\.1|localhost):[0-9]+$/.test(url)) return []
    return [{ id: match[1], url, file: path.join(runtimeDirectory, entry.name) }]
  })
}

async function runtimeOpenCodeStatuses(sessions) {
  const directories = new Map(sessions.map(session => [String(session.id || ""), String(session.directory || home)]))
  const results = await Promise.all(openCodeRuntimeServers().map(async runtime => {
    try {
      const directory = directories.get(runtime.id) || home
      const status = await requestOpenCodeAt(
        runtime.url,
        `/session/status?directory=${encodeURIComponent(directory)}`,
        { timeout: 700 })
      return [runtime.id, status && status[runtime.id]]
    } catch {
      try { fs.unlinkSync(runtime.file) } catch { /* The runtime entry may already be gone. */ }
      return [runtime.id, null]
    }
  }))
  return Object.fromEntries(results.filter(([, status]) => status))
}

function normalizeOpenCodeModels(providerResponse, defaultModel) {
  const connected = new Set(Array.isArray(providerResponse.connected) ? providerResponse.connected : [])
  const models = []
  for (const providerInfo of Array.isArray(providerResponse.all) ? providerResponse.all : []) {
    if (!connected.has(providerInfo.id)) continue
    for (const modelInfo of Object.values(providerInfo.models || {})) {
      const id = `${providerInfo.id}/${modelInfo.id}`
      const variants = Object.keys(modelInfo.variants || {}).filter(variant =>
        modelInfo.variants[variant] && modelInfo.variants[variant].disabled !== true)
      models.push({
        id,
        name: cleanText(modelInfo.name) || id,
        provider: providerInfo.name || providerInfo.id,
        isDefault: id === defaultModel,
        efforts: variants
      })
    }
  }
  models.sort((a, b) => Number(b.isDefault) - Number(a.isDefault)
    || a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name))
  return models
}

function normalizeOpenCodeAgents(agentResponse) {
  return (Array.isArray(agentResponse) ? agentResponse : [])
    .filter(agent => agent && agent.hidden !== true
      && (agent.mode === "primary" || agent.mode === "all"))
    .map(agent => ({
      id: String(agent.name || ""),
      name: String(agent.name || ""),
      description: cleanText(agent.description)
    }))
}

function openCodeDefaultModel(providerResponse, configResponse = {}) {
  const configured = cleanText(configResponse && configResponse.model)
  if (configured) return configured
  const connected = Array.isArray(providerResponse.connected) ? providerResponse.connected : []
  const defaults = providerResponse.default && typeof providerResponse.default === "object"
    ? providerResponse.default : {}
  for (const providerID of connected) {
    if (defaults[providerID]) return `${providerID}/${defaults[providerID]}`
  }
  return ""
}

function openCodeDefaultAgent(agentResponse, configResponse = {}) {
  const configured = cleanText(configResponse && configResponse.default_agent)
  if (configured) return configured
  const primary = normalizeOpenCodeAgents(agentResponse)
  return primary.length > 0 ? primary[0].id : ""
}

async function openCodeCapabilities(directories = []) {
  const cached = readJSON(openCodeCapabilitiesPath, null)
  try {
    const age = Date.now() - fs.statSync(openCodeCapabilitiesPath).mtimeMs
    if (age < 60000 && cached && Array.isArray(cached.models)
        && Array.isArray(cached.agents)
        && typeof cached.defaultModel === "string"
        && typeof cached.defaultAgent === "string"
        && typeof cached.version === "string"
        && directories.every(directory => cached.projectDefaults
          && Object.hasOwn(cached.projectDefaults, directory))) return cached
  } catch { /* Fetch the capabilities below. */ }

  try {
    const [healthResponse, providerResponse, agentResponse, configResponse] = await Promise.all([
      requestOpenCode("/global/health"),
      requestOpenCode("/provider"),
      requestOpenCode("/agent"),
      requestOpenCode("/config")
    ])
    const defaultModel = openCodeDefaultModel(providerResponse, configResponse)
    const defaultAgent = openCodeDefaultAgent(agentResponse, configResponse)
    const defaultEffort = cleanText(configResponse && configResponse.variant)
    const connected = Array.isArray(providerResponse.connected) ? providerResponse.connected : []
    const projectEntries = await Promise.all(directories.map(async directory => {
      try {
        const query = `?directory=${encodeURIComponent(directory)}`
        const [projectConfig, projectAgents] = await Promise.all([
          requestOpenCode(`/config${query}`),
          requestOpenCode(`/agent${query}`)
        ])
        return [directory, {
          defaults: {
            model: cleanText(projectConfig && projectConfig.model) || defaultModel,
            effort: cleanText(projectConfig && projectConfig.variant) || defaultEffort,
            agent: openCodeDefaultAgent(projectAgents, projectConfig) || defaultAgent
          },
          agents: normalizeOpenCodeAgents(projectAgents)
        }]
      } catch {
        return [directory, {
          defaults: { model: defaultModel, effort: defaultEffort, agent: defaultAgent },
          agents: normalizeOpenCodeAgents(agentResponse)
        }]
      }
    }))
    const capabilities = {
      models: normalizeOpenCodeModels(providerResponse, defaultModel),
      agents: normalizeOpenCodeAgents(agentResponse),
      defaultModel,
      defaultEffort,
      defaultAgent,
      projectDefaults: Object.fromEntries(projectEntries.map(([directory, value]) =>
        [directory, value.defaults])),
      projectAgents: Object.fromEntries(projectEntries.map(([directory, value]) =>
        [directory, value.agents])),
      available: healthResponse && healthResponse.healthy === true,
      authenticated: connected.length > 0,
      version: cleanText(healthResponse && healthResponse.version),
      error: connected.length > 0
        ? "" : "OpenCode has no connected provider; run: opencode auth login"
    }
    fs.mkdirSync(path.dirname(openCodeCapabilitiesPath), { recursive: true, mode: 0o700 })
    const temporary = `${openCodeCapabilitiesPath}.${process.pid}.tmp`
    fs.writeFileSync(temporary, JSON.stringify(capabilities) + "\n", { mode: 0o600 })
    fs.renameSync(temporary, openCodeCapabilitiesPath)
    return capabilities
  } catch (error) {
    if (cached && Array.isArray(cached.models) && Array.isArray(cached.agents)) return cached
    throw error
  }
}

export async function openCodeSnapshot() {
  const sessions = await requestOpenCode("/experimental/session?roots=true&limit=1000&archived=false")
  const directories = [...new Set(sessions.map(item => String(item.directory || "")).filter(Boolean))]
  const capabilities = await openCodeCapabilities(directories)
  const metadata = loadMetadata()
  const statuses = {}
  await Promise.all(directories.map(async directory => {
    try {
      const scoped = await requestOpenCode(`/session/status?directory=${encodeURIComponent(directory)}`)
      Object.assign(statuses, scoped || {})
    } catch { /* A stale project directory should not hide the session history. */ }
  }))
  Object.assign(statuses, await runtimeOpenCodeStatuses(sessions))
  const threads = sessions.map(session => {
    const id = String(session.id || "")
    const status = statuses[id] || { type: "idle" }
    const local = metadata[`opencode:${id}`] || {}
    return {
      id,
      name: cleanText(session.title) || "Untitled OpenCode session",
      preview: cleanText(session.title),
      cwd: String(session.directory || home),
      projectId: String(session.projectID || session.directory || home),
      createdAt: timestampSeconds(session.time && session.time.created),
      updatedAt: timestampSeconds(session.time && session.time.updated),
      status: { type: status.type === "busy" || status.type === "retry" ? "active" : "idle" },
      lifecycle: String(status.type || "idle"),
      completionToken: String(session.time && session.time.updated || ""),
      attention: status.type === "retry",
      runtimeError: cleanText(status.message || status.error),
      providerType: "opencode",
      isPinned: local.pinned === true
    }
  }).sort((a, b) => b.updatedAt - a.updatedAt)
  return {
    hostId: "provider-opencode",
    label: "OPENCODE",
    providerType: "opencode",
    type: "provider",
    home,
    threads,
    projects: projectList(threads),
    ...capabilities
  }
}


export async function archiveOpenCode(threadID, threadPath) {
  if (!threadID) throw new Error("missing session id")
  await requestOpenCode(`/session/${encodeURIComponent(threadID)}?directory=${encodeURIComponent(threadPath || home)}`, {
    method: "PATCH",
    body: JSON.stringify({ time: { archived: Date.now() } })
  })
}

export async function renameOpenCode(threadID, threadPath, title) {
  const name = cleanText(title).slice(0, 200)
  if (!threadID) throw new Error("missing session id")
  if (!name) throw new Error("missing session name")
  return requestOpenCode(`/session/${encodeURIComponent(threadID)}?directory=${encodeURIComponent(threadPath || home)}`, {
    method: "PATCH",
    body: JSON.stringify({ title: name })
  })
}
