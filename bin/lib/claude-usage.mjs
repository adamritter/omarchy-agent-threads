// Purpose: Provides reusable Claude usage helpers for command-line adapters.
import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { readJsonLimited, readResponseJsonLimited } from "./bounded-io.mjs"

const home = process.env.OMARCHY_AGENT_PROVIDER_HOME || os.homedir()
const stateHome = process.env.XDG_STATE_HOME || path.join(home, ".local", "state")
const claudeUsagePath = path.join(stateHome, "omarchy", "claude-usage.json")
const claudeUsageURL = "https://api.anthropic.com/api/oauth/usage"
const MAX_CLAUDE_STATE_BYTES = 2 * 1024 * 1024
const MAX_CLAUDE_USAGE_RESPONSE_BYTES = 1024 * 1024
function readJSON(filePath, fallback = null) {
  return readJsonLimited(filePath, MAX_CLAUDE_STATE_BYTES, "Claude usage state", fallback)
}
function writePrivateJSON(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true, mode: 0o700 })
  const temporary = `${filePath}.${process.pid}.tmp`
  fs.writeFileSync(temporary, JSON.stringify(value) + "\\n", { mode: 0o600, flag: "wx" })
  fs.renameSync(temporary, filePath)
}

function claudeRateLimits(runtimeValue) {
  const stored = runtimeValue && runtimeValue.rateLimits
  if (!stored || typeof stored !== "object") return {}
  const now = Date.now() / 1000
  const window = (value, duration) => {
    if (!value || typeof value !== "object") return null
    let usedPercent = Number(value.used_percentage)
    let resetsAt = Number(value.resets_at)
    if (!Number.isFinite(usedPercent)) return null
    if (Number.isFinite(resetsAt) && resetsAt > 0 && resetsAt <= now) {
      usedPercent = 0
      resetsAt = 0
    }
    return {
      usedPercent: Math.max(0, Math.min(100, usedPercent)),
      resetsAt: Number.isFinite(resetsAt) ? resetsAt : 0,
      windowDurationMins: duration
    }
  }
  const primary = window(stored.fiveHour, 300)
  const secondary = window(stored.sevenDay, 10080)
  return {
    ...(primary ? { primary } : {}),
    ...(secondary ? { secondary } : {}),
    updatedAt: Number(stored.updatedAt || 0)
  }
}

function normalizedClaudeUsage(usage) {
  if (!usage || typeof usage !== "object") return {}
  const window = (value, duration) => {
    if (!value || typeof value !== "object") return null
    const usedPercent = Number(value.utilization)
    const parsedReset = Date.parse(String(value.resets_at || ""))
    if (!Number.isFinite(usedPercent)) return null
    return {
      usedPercent: Math.max(0, Math.min(100, usedPercent)),
      resetsAt: Number.isFinite(parsedReset) ? parsedReset / 1000 : 0,
      windowDurationMins: duration
    }
  }
  const primary = window(usage.five_hour, 300)
  const secondary = window(usage.seven_day, 10080)
  return {
    ...(primary ? { primary } : {}),
    ...(secondary ? { secondary } : {}),
    updatedAt: Date.now()
  }
}

export async function claudeUsageRateLimits(configRoot, hookRuntime, authenticated) {
  const cached = readJSON(claudeUsagePath, null)
  try {
    const age = Date.now() - fs.statSync(claudeUsagePath).mtimeMs
    if (age < 60000 && cached && typeof cached === "object") return cached
  } catch { /* Fetch below. */ }

  if (authenticated) {
    const credentials = readJSON(path.join(configRoot, ".credentials.json"), {}) || {}
    const oauth = credentials.claudeAiOauth && typeof credentials.claudeAiOauth === "object"
      ? credentials.claudeAiOauth : {}
    const accessToken = String(oauth.accessToken || "")
    if (accessToken !== "") {
      try {
        const response = await fetch(claudeUsageURL, {
          signal: AbortSignal.timeout(5000),
          headers: {
            authorization: `Bearer ${accessToken}`,
            "anthropic-beta": "oauth-2025-04-20",
            "user-agent": "omarchy-codex-threads"
          }
        })
        if (!response.ok) throw new Error(`Claude usage HTTP ${response.status}`)
        const usage = await readResponseJsonLimited(
          response, MAX_CLAUDE_USAGE_RESPONSE_BYTES, "Claude usage response")
        const limits = normalizedClaudeUsage(usage)
        if (limits.primary || limits.secondary) {
          try { writePrivateJSON(claudeUsagePath, limits) } catch { /* Cache is best effort. */ }
          return limits
        }
      } catch { /* Use the last known or status-line value below. */ }
    }
  }

  if (cached && typeof cached === "object") return cached
  return claudeRateLimits(hookRuntime)
}
