import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { mapWithConcurrency, readJsonLimited, readResponseJsonLimited } from "./bounded-io.mjs"
import { openCodeLoopbackUrl, openCodeRequestHeaders } from "./opencode-auth.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const stateHome = process.env.XDG_STATE_HOME || path.join(home, ".local", "state")
const openCodeCapabilitiesPath = path.join(stateHome, "omarchy", "opencode-capabilities.json")
const openCodeURL = openCodeLoopbackUrl(
  process.env.OMARCHY_OPENCODE_URL || "http://127.0.0.1:43962")
const MAX_CAPABILITIES_BYTES = 2 * 1024 * 1024
const MAX_RESPONSE_BYTES = 8 * 1024 * 1024
const MAX_MODELS = 2000
const MAX_AGENTS = 1000
const MAX_PROJECTS = 1000

function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_CAPABILITIES_BYTES, "OpenCode capability cache", fallback)
}

function cleanText(value) {
  return String(value || "").replace(/\\s+/g, " ").trim()
}

async function requestOpenCode(endpoint, options = {}) {
  const response = await fetch(openCodeURL + endpoint, {
    ...options,
    signal: AbortSignal.timeout(options.timeout || 5000),
    headers: {
      "content-type": "application/json",
      ...openCodeRequestHeaders(true),
      ...(options.headers || {})
    }
  })
  if (!response.ok) throw new Error(`OpenCode HTTP ${response.status}`)
  if (response.status === 204) return null
  return readResponseJsonLimited(response, MAX_RESPONSE_BYTES, "OpenCode response")
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
      if (models.length > MAX_MODELS)
        throw new Error(`OpenCode returned more than ${MAX_MODELS} models`)
    }
  }
  models.sort((a, b) => Number(b.isDefault) - Number(a.isDefault)
    || a.provider.localeCompare(b.provider) || a.name.localeCompare(b.name))
  return models
}

function normalizeOpenCodeAgents(agentResponse) {
  const agents = Array.isArray(agentResponse) ? agentResponse : []
  if (agents.length > MAX_AGENTS)
    throw new Error(`OpenCode returned more than ${MAX_AGENTS} agents`)
  return agents
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

export async function openCodeCapabilities(directories = []) {
  if (!Array.isArray(directories) || directories.length > MAX_PROJECTS)
    throw new Error(`OpenCode capability lookup exceeded ${MAX_PROJECTS} projects`)
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
    const projectEntries = await mapWithConcurrency(directories, 8, async directory => {
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
    })
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
    fs.writeFileSync(temporary, JSON.stringify(capabilities) + "\n", {
      mode: 0o600, flag: "wx"
    })
    fs.renameSync(temporary, openCodeCapabilitiesPath)
    return capabilities
  } catch (error) {
    if (cached && Array.isArray(cached.models) && Array.isArray(cached.agents)) return cached
    throw error
  }
}
