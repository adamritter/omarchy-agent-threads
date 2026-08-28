// Purpose: Provides reusable OpenCode provider helpers for command-line adapters.
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { openCodeCapabilities } from "./opencode-capabilities.mjs"
import {
  mapWithConcurrency, readDirectoryLimited, readJsonLimited, readResponseJsonLimited
} from "./bounded-io.mjs"
import { openCodeLoopbackUrl, openCodeRequestHeaders } from "./opencode-auth.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const stateHome = process.env.XDG_STATE_HOME || path.join(home, ".local", "state")
const metadataPath = path.join(stateHome, "omarchy", "codex-thread-providers.json")
const openCodeURL = openCodeLoopbackUrl(
  process.env.OMARCHY_OPENCODE_URL || "http://127.0.0.1:43962")
const procRoot = process.env.OMARCHY_AGENT_PROC_ROOT || "/proc"
const MAX_CMDLINE_BYTES = 64 * 1024
const MAX_PROVIDER_FILE_BYTES = 2 * 1024 * 1024
const MAX_OPENCODE_RESPONSE_BYTES = 8 * 1024 * 1024
const MAX_OPENCODE_SESSIONS = 1000
const MAX_OPENCODE_PROJECTS = 256
const MAX_OPENCODE_STATUS_ENTRIES = 5000

function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_PROVIDER_FILE_BYTES, "provider state", fallback)
}

function loadMetadata() {
  const value = readJSON(metadataPath, {})
  return value && typeof value === "object" ? value : {}
}

function cleanText(value) {
  return String(value || "").replace(/\s+/g, " ").trim().slice(0, 4096)
}

function cleanStatus(value) {
  return {
    type: cleanText(value && value.type).slice(0, 64) || "idle",
    message: cleanText(value && (value.message || value.error))
  }
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
    headers: {
      "content-type": "application/json",
      ...openCodeRequestHeaders(true),
      ...(options.headers || {})
    }
  })
  if (!response.ok) throw new Error(`OpenCode HTTP ${response.status}`)
  if (response.status === 204) return null
  return readResponseJsonLimited(response, MAX_OPENCODE_RESPONSE_BYTES, "OpenCode response")
}

async function requestOpenCode(endpoint, options = {}) {
  return requestOpenCodeAt(openCodeURL, endpoint, options)
}

function openCodeRuntimeServers() {
  let processEntries = []
  try { processEntries = readDirectoryLimited(procRoot, 32768, "process directory") }
  catch { return [] }
  return processEntries.flatMap(entry => {
    if (!entry.isDirectory() || !/^[0-9]+$/.test(entry.name)) return []
    const processDirectory = path.join(procRoot, entry.name)
    let processArguments = []
    try {
      if (fs.statSync(processDirectory).uid !== process.getuid()) return []
      const descriptor = fs.openSync(path.join(processDirectory, "cmdline"), "r")
      let bytes
      try {
        const buffer = Buffer.alloc(MAX_CMDLINE_BYTES + 1)
        bytes = fs.readSync(descriptor, buffer, 0, buffer.length, 0)
        if (bytes > MAX_CMDLINE_BYTES) return []
        processArguments = buffer.subarray(0, bytes).toString("utf8").split("\0").filter(Boolean)
      } finally { fs.closeSync(descriptor) }
    } catch { return [] }
    const sessionIndex = processArguments.indexOf("--session")
    const portIndex = processArguments.indexOf("--port")
    const hostnameIndex = processArguments.indexOf("--hostname")
    const id = sessionIndex >= 0 ? String(processArguments[sessionIndex + 1] || "") : ""
    const port = portIndex >= 0 ? Number(processArguments[portIndex + 1]) : 0
    const hostname = hostnameIndex >= 0 ? String(processArguments[hostnameIndex + 1] || "") : ""
    if (!/^[A-Za-z0-9._-]+$/.test(id)
        || hostname !== "127.0.0.1"
        || !Number.isInteger(port) || port < 1 || port > 65535) return []
    return [{ id, url: `http://127.0.0.1:${port}` }]
  }).slice(0, 256)
}

async function runtimeOpenCodeStatuses(sessions) {
  const directories = new Map(sessions.map(session => [String(session.id || ""), String(session.directory || home)]))
  const results = await mapWithConcurrency(openCodeRuntimeServers(), 8, async runtime => {
    try {
      const directory = directories.get(runtime.id) || home
      const status = await requestOpenCodeAt(
        runtime.url,
        `/session/status?directory=${encodeURIComponent(directory)}`,
        { timeout: 700 })
      return [runtime.id, status && cleanStatus(status[runtime.id])]
    } catch {
      return [runtime.id, null]
    }
  })
  return Object.fromEntries(results.filter(([, status]) => status))
}


export async function openCodeSnapshot() {
  const sessions = await requestOpenCode("/experimental/session?roots=true&limit=1000&archived=false")
  if (!Array.isArray(sessions)) throw new Error("OpenCode returned an invalid session list")
  if (sessions.length > MAX_OPENCODE_SESSIONS)
    throw new Error(`OpenCode returned more than ${MAX_OPENCODE_SESSIONS} sessions`)
  const directories = [...new Set(sessions.map(item => String(item.directory || "")).filter(Boolean))]
  if (directories.length > MAX_OPENCODE_PROJECTS)
    throw new Error(`OpenCode returned more than ${MAX_OPENCODE_PROJECTS} project directories`)
  const capabilities = await openCodeCapabilities(directories)
  const metadata = loadMetadata()
  const statuses = Object.create(null)
  let statusEntries = 0
  let statusLimitExceeded = false
  await mapWithConcurrency(directories, 8, async directory => {
    try {
      const scoped = await requestOpenCode(`/session/status?directory=${encodeURIComponent(directory)}`)
      for (const [id, value] of Object.entries(scoped || {})) {
        statusEntries++
        if (statusEntries > MAX_OPENCODE_STATUS_ENTRIES) {
          statusLimitExceeded = true
          break
        }
        statuses[String(id).slice(0, 256)] = cleanStatus(value)
      }
    } catch { /* A stale project directory should not hide the session history. */ }
  })
  if (statusLimitExceeded) throw new Error("OpenCode status entry limit exceeded")
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
