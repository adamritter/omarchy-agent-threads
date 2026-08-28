// Purpose: Provides reusable Claude project config helpers for command-line adapters.
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { readFileLimited, readJsonLimited } from "./bounded-io.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const MAX_CLAUDE_AGENT_FILES = 256
const MAX_CLAUDE_AGENT_BYTES = 128 * 1024
const MAX_CLAUDE_SETTINGS_BYTES = 2 * 1024 * 1024
function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_CLAUDE_SETTINGS_BYTES, "Claude settings", fallback)
}
function readBoundedText(filePath, maxBytes) {
  return readFileLimited(filePath, maxBytes, "Claude agent file")
}
function boundedDirectoryEntries(directoryPath, limit) {
  const entries = []; let directory
  try { directory = fs.opendirSync(directoryPath) } catch { return entries }
  try { while (entries.length < limit) { const entry = directory.readSync(); if (!entry) break; entries.push(entry) } }
  finally { try { directory.closeSync() } catch {} }
  return entries
}
function cleanText(value) { return String(value || "").replace(/\\s+/g, " ").trim() }
function claudeDefaultEffort(model) {
  return /opus[-_ ]?4[-_ ]?7|opus[-_ ]?5/.test(String(model || "").toLowerCase()) ? "xhigh" : "high"
}

function claudeAgentsInDirectory(directory, scope) {
  const entries = boundedDirectoryEntries(directory, MAX_CLAUDE_AGENT_FILES)
  const agents = []
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue
    let content = ""
    try { content = readBoundedText(path.join(directory, entry.name), MAX_CLAUDE_AGENT_BYTES) }
    catch { continue }
    const frontmatter = /^---\s*\n([\s\S]*?)\n---(?:\s*\n|$)/.exec(content)
    if (!frontmatter) continue
    const field = name => {
      const match = new RegExp(`^${name}:\\s*(.+?)\\s*$`, "mi").exec(frontmatter[1])
      return match ? cleanText(match[1].replace(/^['"]|['"]$/g, "")) : ""
    }
    const id = field("name") || path.basename(entry.name, ".md")
    if (!/^[A-Za-z0-9._:-]+$/.test(id)) continue
    agents.push({
      id,
      name: id,
      description: field("description"),
      scope: String(scope || "")
    })
  }
  return agents
}

function mergeClaudeAgents(...lists) {
  const merged = new Map()
  for (const list of lists) {
    for (const agent of Array.isArray(list) ? list : []) merged.set(agent.id, agent)
  }
  return [...merged.values()].sort((a, b) => a.name.localeCompare(b.name))
}

export function claudeAgentsForDirectory(configRoot, directory) {
  let agents = claudeAgentsInDirectory(path.join(configRoot, "agents"), "user")
  const target = String(directory || "")
  if (!path.isAbsolute(target)) return agents
  const ancestors = []
  let current = target
  while (current && current !== path.dirname(current)) {
    ancestors.push(current)
    current = path.dirname(current)
  }
  ancestors.reverse()
  for (const ancestor of ancestors) {
    agents = mergeClaudeAgents(agents,
      claudeAgentsInDirectory(path.join(ancestor, ".claude", "agents"), "project"))
  }
  return agents
}

function mergeClaudeSettings(base, override) {
  const first = base && typeof base === "object" ? base : {}
  const second = override && typeof override === "object" ? override : {}
  return {
    ...first,
    ...second,
    env: {
      ...(first.env && typeof first.env === "object" ? first.env : {}),
      ...(second.env && typeof second.env === "object" ? second.env : {})
    }
  }
}

export function claudeSettingsForDirectory(configRoot, directory) {
  let settings = readJSON(path.join(configRoot, "settings.json"), {}) || {}
  const target = String(directory || "")
  if (!path.isAbsolute(target)) return settings
  settings = mergeClaudeSettings(settings,
    readJSON(path.join(target, ".claude", "settings.json"), {}))
  settings = mergeClaudeSettings(settings,
    readJSON(path.join(target, ".claude", "settings.local.json"), {}))
  return settings
}

export function claudeDefaults(configRoot, threads, configuredSettings, configuredState) {
  const settings = configuredSettings || readJSON(path.join(configRoot, "settings.json"), {}) || {}
  const settingsEnv = settings.env && typeof settings.env === "object" ? settings.env : {}
  const state = configuredState || readJSON(path.join(home, ".claude.json"), {}) || {}
  const slots = state.clientDataCacheSlots && typeof state.clientDataCacheSlots === "object"
    ? Object.values(state.clientDataCacheSlots) : []
  const cachedModel = slots.map(slot => cleanText(slot && slot.model)).find(Boolean) || ""
  const recent = threads.find(thread => thread.lastModel || thread.lastEffort) || {}
  const model = cleanText(process.env.ANTHROPIC_MODEL
    || settingsEnv.ANTHROPIC_MODEL
    || settings.model
    || cachedModel
    || recent.lastModel
    || "sonnet")
  const configuredEffort = cleanText(process.env.CLAUDE_CODE_EFFORT_LEVEL
    || settingsEnv.CLAUDE_CODE_EFFORT_LEVEL
    || settings.effortLevel)
  const modelFamily = value => {
    const match = String(value || "").toLowerCase().match(/(sonnet|opus|haiku|fable)/)
    return match ? match[1] : String(value || "").toLowerCase()
  }
  const recentEffort = modelFamily(recent.lastModel) === modelFamily(model)
    ? cleanText(recent.lastEffort) : ""
  const effort = configuredEffort && configuredEffort !== "auto"
    ? configuredEffort
    : (recentEffort || claudeDefaultEffort(model))
  return { model, effort, agent: cleanText(settings.agent) }
}
