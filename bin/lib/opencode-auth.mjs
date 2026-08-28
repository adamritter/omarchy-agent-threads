// Purpose: Provides reusable OpenCode auth helpers for command-line adapters.
import os from "node:os"
import path from "node:path"
import { readJsonLimited } from "./bounded-io.mjs"

const AUTH_FILE_LIMIT = 8 * 1024

export function openCodeLoopbackUrl(value) {
  let endpoint
  try { endpoint = new URL(String(value || "")) }
  catch { throw new Error("OpenCode server URL is invalid") }
  if (endpoint.protocol !== "http:"
      || (endpoint.hostname !== "127.0.0.1" && endpoint.hostname !== "localhost")
      || endpoint.username || endpoint.password
      || (endpoint.pathname !== "/" && endpoint.pathname !== "")
      || endpoint.search || endpoint.hash)
    throw new Error("OpenCode server URL must be a plain loopback HTTP origin")
  return endpoint.origin
}

export function openCodeAuthPath() {
  if (process.env.OMARCHY_OPENCODE_AUTH_FILE)
    return process.env.OMARCHY_OPENCODE_AUTH_FILE
  const stateHome = process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state")
  return path.join(stateHome, "omarchy", "opencode-server-auth.json")
}

export function openCodeCredentials(required = false) {
  const environmentUsername = String(process.env.OMARCHY_OPENCODE_USERNAME || "")
  const environmentPassword = String(process.env.OMARCHY_OPENCODE_PASSWORD || "")
  let value = null
  if (environmentUsername || environmentPassword) {
    value = { username: environmentUsername, password: environmentPassword }
  } else {
    try { value = readJsonLimited(openCodeAuthPath(), AUTH_FILE_LIMIT, "OpenCode auth file") }
    catch (error) {
      if (!required && error && error.code === "ENOENT") return null
      throw error
    }
  }
  const username = String(value && value.username || "")
  const password = String(value && value.password || "")
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(username)
      || !/^[A-Za-z0-9_-]{32,128}$/.test(password))
    throw new Error("OpenCode auth credentials are invalid")
  return { username, password }
}

export function openCodeRequestHeaders(required = false) {
  const credentials = openCodeCredentials(required)
  if (!credentials) return {}
  const basic = Buffer.from(`${credentials.username}:${credentials.password}`).toString("base64")
  return { Authorization: `Basic ${basic}` }
}
