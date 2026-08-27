import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { openCodeCapabilities } from "./opencode-capabilities.mjs"

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
