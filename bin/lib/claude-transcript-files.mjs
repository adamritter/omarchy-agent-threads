// Purpose: Provides reusable Claude transcript files helpers for command-line adapters.
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { readJsonLimited } from "./bounded-io.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const MAX_CLAUDE_PROJECT_DIRECTORIES = 256
const MAX_CLAUDE_DIRECTORY_ENTRIES = 1024
const MAX_CLAUDE_DISCOVERED_TRANSCRIPTS = 2048
const MAX_CLAUDE_TRANSCRIPTS = 512
const MAX_CLAUDE_TRANSCRIPT_HEAD_BYTES = 64 * 1024
const MAX_CLAUDE_TRANSCRIPT_TAIL_BYTES = 256 * 1024
const MAX_CLAUDE_JOBS = 512
const MAX_CLAUDE_STATE_BYTES = 2 * 1024 * 1024

function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_CLAUDE_STATE_BYTES, "Claude state file", fallback)
}
function cleanText(value) { return String(value || "").replace(/\\s+/g, " ").trim() }

export function walkClaudeTranscripts(rootPath) {
  const files = []
  const projectDirectories = boundedDirectoryEntries(rootPath, MAX_CLAUDE_PROJECT_DIRECTORIES)
  for (const projectDirectory of projectDirectories) {
    if (!projectDirectory.isDirectory()) continue
    const directoryPath = path.join(rootPath, projectDirectory.name)
    const entries = boundedDirectoryEntries(directoryPath, MAX_CLAUDE_DIRECTORY_ENTRIES)
    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue
      const filePath = path.join(directoryPath, entry.name)
      let stat
      try { stat = fs.lstatSync(filePath) } catch { continue }
      if (!stat.isFile()) continue
      files.push({ path: filePath, size: stat.size, mtimeMs: stat.mtimeMs })
      if (files.length >= MAX_CLAUDE_DISCOVERED_TRANSCRIPTS) break
    }
    if (files.length >= MAX_CLAUDE_DISCOVERED_TRANSCRIPTS) break
  }
  return files.sort((a, b) => b.mtimeMs - a.mtimeMs).slice(0, MAX_CLAUDE_TRANSCRIPTS)
}

function boundedDirectoryEntries(directoryPath, limit) {
  const entries = []
  let directory
  try { directory = fs.opendirSync(directoryPath) } catch { return entries }
  try {
    while (entries.length < limit) {
      const entry = directory.readSync()
      if (!entry) break
      entries.push(entry)
    }
  } finally {
    try { directory.closeSync() } catch { /* Directory may already be closed. */ }
  }
  return entries
}

export function readClaudeTranscript(candidate, budget) {
  const descriptor = fs.openSync(candidate.path, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW)
  try {
    const stat = fs.fstatSync(descriptor)
    if (!stat.isFile()) return null
    const readRange = (position, length) => {
      const buffer = Buffer.alloc(length)
      let offset = 0
      while (offset < length) {
        const count = fs.readSync(descriptor, buffer, offset, length - offset, position + offset)
        if (count === 0) break
        offset += count
      }
      return buffer.subarray(0, offset).toString("utf8")
    }
    const combinedLimit = MAX_CLAUDE_TRANSCRIPT_HEAD_BYTES
      + MAX_CLAUDE_TRANSCRIPT_TAIL_BYTES
    const readCost = Math.min(stat.size, combinedLimit)
    if (readCost > budget.remaining) return null
    budget.remaining -= readCost
    if (stat.size <= combinedLimit) return { content: readRange(0, stat.size), stat }
    const head = readRange(0, MAX_CLAUDE_TRANSCRIPT_HEAD_BYTES)
    const tail = readRange(stat.size - MAX_CLAUDE_TRANSCRIPT_TAIL_BYTES,
      MAX_CLAUDE_TRANSCRIPT_TAIL_BYTES)
    return { content: `${head}\n${tail}`, stat }
  } finally {
    fs.closeSync(descriptor)
  }
}

export function renameClaudeThread(sessionID, title) {
  const name = cleanText(title).slice(0, 200)
  if (!sessionID) throw new Error("missing session id")
  if (!name) throw new Error("missing session name")
  const transcriptName = `${sessionID}.jsonl`
  const rootPath = path.join(process.env.CLAUDE_CONFIG_DIR || path.join(home, ".claude"), "projects")
  const candidate = walkClaudeTranscripts(rootPath)
    .find(item => path.basename(item.path) === transcriptName)
  if (!candidate) throw new Error("session transcript not found")

  const descriptor = fs.openSync(candidate.path,
    fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_NOFOLLOW)
  try {
    const stat = fs.fstatSync(descriptor)
    if (!stat.isFile()) throw new Error("session transcript is not a regular file")
    const record = JSON.stringify({
      type: "custom-title",
      customTitle: name,
      sessionId: sessionID,
      timestamp: new Date().toISOString()
    }) + "\n"
    fs.writeSync(descriptor, record)
    fs.fsyncSync(descriptor)
  } finally {
    fs.closeSync(descriptor)
  }
}

export function claudeJobStates() {
  const states = new Map()
  const jobsPath = path.join(process.env.CLAUDE_CONFIG_DIR || path.join(home, ".claude"), "jobs")
  const jobs = boundedDirectoryEntries(jobsPath, MAX_CLAUDE_JOBS)
  for (const job of jobs) {
    if (!job.isDirectory()) continue
    const value = readJSON(path.join(jobsPath, job.name, "state.json"), null)
    if (!value || typeof value !== "object") continue
    const id = String(value.sessionId || value.sessionID || value.session_id || value.id || "")
    if (!id) continue
    const raw = String(value.status || value.state || "").toLowerCase()
    const busy = ["working", "running", "active", "starting"].includes(raw)
    const attention = ["needs_input", "needs-input", "waiting", "blocked"].includes(raw)
    states.set(id, { busy, attention, raw, value })
  }
  return states
}
