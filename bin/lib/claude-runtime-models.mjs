// Purpose: Provides reusable Claude runtime models helpers for command-line adapters.
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { spawnSync } from "node:child_process"
import { readJsonLimited } from "./bounded-io.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const stateHome = process.env.XDG_STATE_HOME || path.join(home, ".local", "state")
const claudeRuntimePath = path.join(stateHome, "omarchy", "claude-runtime.json")
const claudeCommand = process.env.OMARCHY_CLAUDE_COMMAND || "claude"
const MAX_CLAUDE_STATE_BYTES = 2 * 1024 * 1024
function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_CLAUDE_STATE_BYTES, "Claude runtime cache", fallback)
}
function writePrivateJSON(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true, mode: 0o700 })
  const temporary = `${filePath}.${process.pid}.tmp`
  fs.writeFileSync(temporary, JSON.stringify(value) + "\\n", { mode: 0o600, flag: "wx" })
  fs.renameSync(temporary, filePath)
}
function cleanText(value) { return String(value || "").replace(/\\s+/g, " ").trim() }

function claudeDefaultEffort(model) {
  const value = String(model || "").toLowerCase()
  return /opus[-_ ]?4[-_ ]?7|opus[-_ ]?5/.test(value) ? "xhigh" : "high"
}

export function claudeRuntimeInfo() {
  const cached = readJSON(claudeRuntimePath, null)
  try {
    const age = Date.now() - fs.statSync(claudeRuntimePath).mtimeMs
    if (age < 60000 && cached && typeof cached === "object"
        && cached.available === true && cached.authenticated === true)
      return cached
  } catch { /* Probe the CLI below. */ }

  const candidates = [claudeCommand]
  if (!claudeCommand.includes("/")) {
    candidates.push(path.join(home, ".local", "bin", claudeCommand))
    candidates.push(path.join(home, ".claude", "local", claudeCommand))
  }
  let resolvedCommand = claudeCommand
  let versionResult = null
  for (const candidate of [...new Set(candidates)]) {
    const result = spawnSync(candidate, ["--version"], {
      encoding: "utf8",
      timeout: 3000,
      maxBuffer: 256 * 1024,
      windowsHide: true
    })
    // Some sandboxed launchers report a harmless EPERM alongside a successful
    // child exit. A zero status and version output are authoritative here.
    if (result.status === 0 && cleanText(result.stdout) !== "") {
      resolvedCommand = candidate
      versionResult = result
      break
    }
  }
  versionResult ||= { error: new Error("Claude CLI not found"), status: 127, stdout: "" }
  const available = versionResult.status === 0 && cleanText(versionResult.stdout) !== ""
  const info = {
    available,
    version: available ? cleanText(versionResult.stdout) : "",
    commandPath: available ? resolvedCommand : "",
    authenticated: false,
    subscriptionType: ""
  }
  if (available) {
    const authResult = spawnSync(resolvedCommand, ["auth", "status"], {
      encoding: "utf8",
      timeout: 4000,
      maxBuffer: 256 * 1024,
      windowsHide: true
    })
    try {
      const auth = JSON.parse(String(authResult.stdout || "{}"))
      info.authenticated = auth.loggedIn === true
      info.subscriptionType = cleanText(auth.subscriptionType)
    } catch { info.authenticated = authResult.status === 0 }
  }
  try { writePrivateJSON(claudeRuntimePath, info) } catch { /* Runtime info is best effort. */ }
  return info
}

function claudeModelEfforts(model) {
  const value = String(model || "").toLowerCase()
  if (value.includes("haiku")) return []
  return ["low", "medium", "high", "xhigh", "max"]
}

export function claudeModels(settings, state, configuredModels = []) {
  const entries = [
    { id: "sonnet", name: "Sonnet", defaultEffort: "high" },
    { id: "opus", name: "Opus", defaultEffort: "xhigh" },
    { id: "haiku", name: "Haiku", defaultEffort: "" }
  ]
  const additional = Array.isArray(state.additionalModelOptionsCache)
    ? state.additionalModelOptionsCache : []
  for (const option of additional) {
    const id = cleanText(option && option.value)
    if (!id || entries.some(entry => entry.id === id)) continue
    entries.push({
      id,
      name: cleanText(option.label) || id,
      description: cleanText(option.description),
      defaultEffort: claudeDefaultEffort(id)
    })
  }

  for (const configuredModel of configuredModels) {
    const id = cleanText(configuredModel)
    if (!id || entries.some(entry => entry.id === id)) continue
    entries.push({ id, name: id, defaultEffort: claudeDefaultEffort(id) })
  }

  const available = Array.isArray(settings.availableModels)
    ? settings.availableModels.map(String) : null
  if (available) {
    for (const id of available) {
      if (!entries.some(entry => entry.id === id))
        entries.push({ id, name: id, defaultEffort: claudeDefaultEffort(id) })
    }
  }
  return entries
    .filter(entry => !available || available.includes(entry.id))
    .map(entry => Object.assign({}, entry, { efforts: claudeModelEfforts(entry.id) }))
}
