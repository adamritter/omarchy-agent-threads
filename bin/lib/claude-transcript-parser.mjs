// Purpose: Provides reusable Claude transcript parser helpers for command-line adapters.
import os from "node:os"
import path from "node:path"
import { readClaudeTranscript } from "./claude-transcript-files.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
function cleanText(value) { return String(value || "").replace(/\\s+/g, " ").trim() }
function textContent(content) {
  if (typeof content === "string") return cleanText(content)
  if (!Array.isArray(content)) return ""
  return cleanText(content.map(part => typeof part === "string"
    ? part : (part && (part.text || part.content)) || "").join(" "))
}
function timestampSeconds(value, fallback = 0) {
  if (typeof value === "number") return value > 100000000000 ? value / 1000 : value
  const parsed = Date.parse(String(value || ""))
  return Number.isFinite(parsed) ? parsed / 1000 : fallback
}

export function parseClaudeTranscript(candidate, jobs, runtimeStates, metadata, budget) {
  const fallbackID = path.basename(candidate.path, ".jsonl")
  let transcript
  try { transcript = readClaudeTranscript(candidate, budget) } catch { return null }
  if (!transcript) return null
  const { content, stat } = transcript

  let id = fallbackID
  let cwd = ""
  let title = ""
  let summary = ""
  let firstPrompt = ""
  let lastModel = ""
  let lastEffort = ""
  let inferredBusy = false
  let transcriptState = "idle"
  let terminalAt = 0
  let updatedAt = stat.mtimeMs / 1000
  for (const line of content.split(/\r?\n/)) {
    if (!line.trim()) continue
    let entry
    try { entry = JSON.parse(line) } catch { continue }
    id = String(entry.sessionId || entry.sessionID || id)
    if (entry.cwd) cwd = String(entry.cwd)
    const entryTimestamp = entry.timestamp
      ? timestampSeconds(entry.timestamp) : stat.mtimeMs / 1000
    updatedAt = Math.max(updatedAt, entryTimestamp)
    if (entry.type === "custom-title" && entry.customTitle) title = cleanText(entry.customTitle)
    if (entry.type === "summary" && entry.summary) summary = cleanText(entry.summary)
    const role = entry.message && entry.message.role
    if (!firstPrompt && (entry.type === "user" || role === "user"))
      firstPrompt = textContent(entry.message ? entry.message.content : entry.content)
    if (entry.isSidechain !== true && role === "user") {
      inferredBusy = true
      transcriptState = "busy"
    }
    if (entry.isSidechain !== true && role === "assistant") {
      if (entry.message.model) lastModel = String(entry.message.model)
      if (entry.effort) lastEffort = String(entry.effort)
      const stopReason = String(entry.message.stop_reason || "")
      inferredBusy = stopReason !== "end_turn" && stopReason !== "stop_sequence"
      if (!inferredBusy) {
        transcriptState = "done"
        terminalAt = Math.max(terminalAt, entryTimestamp)
      }
    }
    if (entry.isSidechain !== true && entry.type === "system"
        && ["turn_duration", "stop_failure", "api_error", "interrupted"]
          .includes(String(entry.subtype || ""))) {
      inferredBusy = false
      transcriptState = String(entry.subtype || "done")
      terminalAt = Math.max(terminalAt, entryTimestamp)
    }
    if (entry.isSidechain !== true
        && (entry.type === "last-prompt" || entry.type === "bridge-session")) {
      inferredBusy = false
      transcriptState = "idle"
      terminalAt = Math.max(terminalAt, entryTimestamp)
    }
  }

  const local = metadata[`claude:${id}`] || {}
  if (local.archived === true) return null
  const job = jobs.get(id)
  const runtime = runtimeStates.get(id) || null
  const runtimeUpdatedAt = Number(runtime && runtime.updatedAt || 0) / 1000
  const runtimeWins = runtime && runtimeUpdatedAt >= terminalAt
  const lifecycle = runtimeWins ? String(runtime.state || "idle") : transcriptState
  const busy = job && job.busy === true
    || (runtimeWins ? lifecycle === "busy" : inferredBusy)
  const completionToken = runtime && runtime.completionToken
    ? String(runtime.completionToken) : (terminalAt > 0 ? `transcript:${terminalAt}` : "")
  const attentionToken = runtime && runtime.attentionToken
    ? String(runtime.attentionToken)
    : (job && job.attention ? `job:${job.raw}` : "")
  const display = title || summary || firstPrompt || "Untitled Claude session"
  return {
    id,
    name: display,
    preview: firstPrompt || summary,
    cwd: cwd || home,
    projectId: cwd || home,
    updatedAt,
    status: { type: busy ? "active" : "idle" },
    lifecycle,
    completionToken,
    attentionToken,
    runtimeError: String(runtime && runtime.error || ""),
    providerType: "claude",
    isPinned: local.pinned === true,
    lastModel,
    lastEffort
  }
}
