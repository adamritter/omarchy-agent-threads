import fs from "node:fs"
import os from "node:os"
import path from "node:path"
import { spawn } from "node:child_process"

const timeoutMs = 60000
const pinnedSectionId = "01984de2-8f74-7c91-a3b2-5c5e937cf318"
const SSH_STDOUT_LIMIT = 16 * 1024 * 1024
const SSH_STDERR_LIMIT = 256 * 1024
const CONFIG_FILE_LIMIT = 1024 * 1024
const TOKEN_FILE_LIMIT = 64 * 1024
let nextRequestId = 1

function expandHome(path) {
  return path === "~" ? os.homedir()
    : path.startsWith("~/") ? os.homedir() + path.slice(1)
      : path
}

function readFileLimited(filePath, limit, label) {
  const descriptor = fs.openSync(filePath, "r")
  try {
    const buffer = Buffer.allocUnsafe(limit + 1)
    const bytes = fs.readSync(descriptor, buffer, 0, buffer.length, 0)
    if (bytes > limit) throw new Error(`${label} exceeded its byte limit`)
    return buffer.subarray(0, bytes).toString("utf8")
  } finally {
    fs.closeSync(descriptor)
  }
}

export function loadHost(configPath, hostId) {
  let config
  try {
    config = JSON.parse(readFileLimited(configPath, CONFIG_FILE_LIMIT, "remotes config"))
  } catch (error) {
    throw new Error(`could not read remotes config: ${error.message}`)
  }
  const remotes = Array.isArray(config) ? config : (Array.isArray(config.remotes) ? config.remotes : [])
  const host = remotes.find(item => String(item && item.id || "") === hostId)
  if (!host) throw new Error("remote entry not found")
  return host
}

export function bearerToken(host) {
  const tokenEnv = String(host.authTokenEnv || "")
  let token = tokenEnv === "" ? "" : String(process.env[tokenEnv] || "").trim()
  const tokenFile = String(host.authTokenFile || "")
  if (token === "" && tokenFile !== "") {
    try {
      token = readFileLimited(
        expandHome(tokenFile), TOKEN_FILE_LIMIT, "token file").trim()
    } catch (error) {
      throw new Error(`could not read token file: ${error.message}`)
    }
  }
  if (tokenEnv !== "" && token === "" && tokenFile === "")
    throw new Error(`environment variable ${tokenEnv} is empty`)
  return token
}

export function createWebSocketTransport(host) {
  const remoteUrl = String(host.url || "")
  let endpoint
  try {
    endpoint = new URL(remoteUrl)
  } catch {
    throw new Error("invalid WebSocket URL")
  }
  if (endpoint.protocol !== "ws:" && endpoint.protocol !== "wss:")
    throw new Error("App Server URL must use ws:// or wss://")

  const token = bearerToken(host)
  const localHosts = new Set(["localhost", "127.0.0.1", "::1", "[::1]"])
  if (token !== "" && endpoint.protocol === "ws:" && !localHosts.has(endpoint.hostname))
    throw new Error("refusing to send a bearer token over non-local ws://; use wss://")

  const socket = new WebSocket(endpoint, token === "" ? {} : {
    headers: { Authorization: `Bearer ${token}` }
  })

  return new Promise((resolve, reject) => {
    socket.onopen = () => resolve({
      send(message) { socket.send(JSON.stringify(message)) },
      close() { socket.close(1000, "snapshot complete") },
      setMessageHandler(handler) {
        socket.onmessage = async event => {
          let value = event.data
          const bytes = typeof value === "string" ? Buffer.byteLength(value)
            : value instanceof Blob ? value.size
              : value instanceof ArrayBuffer ? value.byteLength : SSH_STDOUT_LIMIT + 1
          if (bytes > SSH_STDOUT_LIMIT) {
            socket.close(1009, "response too large")
            throw new Error("App Server response exceeded the 16 MiB limit")
          }
          if (value instanceof Blob) value = await value.text()
          else if (value instanceof ArrayBuffer) value = Buffer.from(value).toString("utf8")
          handler(String(value))
        }
      }
    })
    socket.onerror = event => reject(new Error(event && event.error && event.error.message
      ? event.error.message : "WebSocket connection failed"))
  })
}

export function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'"'"'`)}'`
}

export function collectSshOutput(child, providerName) {
  return new Promise((resolve, reject) => {
    const stdout = { chunks: [], bytes: 0, limit: SSH_STDOUT_LIMIT, label: "stdout", size: "16 MiB" }
    const stderr = { chunks: [], bytes: 0, limit: SSH_STDERR_LIMIT, label: "stderr", size: "256 KiB" }
    let finished = false

    function finishWithError(error) {
      if (finished) return
      finished = true
      child.stdout.destroy()
      child.stderr.destroy()
      child.stdin.destroy()
      child.kill("SIGTERM")
      reject(error)
    }

    function collect(stream, state) {
      stream.on("data", chunk => {
        if (finished) return
        const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
        if (state.bytes + buffer.length > state.limit) {
          finishWithError(new Error(
            `remote ${providerName} SSH ${state.label} exceeded the ${state.size} limit`))
          return
        }
        state.chunks.push(buffer)
        state.bytes += buffer.length
      })
    }

    collect(child.stdout, stdout)
    collect(child.stderr, stderr)
    child.on("error", finishWithError)
    child.on("close", code => {
      if (finished) return
      finished = true
      resolve({
        code,
        stdout: Buffer.concat(stdout.chunks, stdout.bytes).toString("utf8"),
        stderr: Buffer.concat(stderr.chunks, stderr.bytes).toString("utf8")
      })
    })
  })
}

export function createSshTransport(host) {
  const sshHost = String(host.sshHost || "").trim()
  if (!/^[A-Za-z0-9_.@:-]+$/.test(sshHost)) throw new Error("invalid SSH host or alias")
  const codexCommand = String(host.codexCommand || "codex").trim()
  if (!/^[A-Za-z0-9_./-]+$/.test(codexCommand)) throw new Error("invalid remote Codex command")

  const remoteCommand = `${shellQuote(codexCommand)} app-server`
  const child = spawn("ssh", [
    "-T",
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=8",
    sshHost,
    remoteCommand
  ], { stdio: ["pipe", "pipe", "pipe"] })

  return new Promise((resolve, reject) => {
    let settled = false
    let closedIntentionally = false
    let failure = null
    let errorHandler = () => {}
    let messageHandler = () => {}
    const stderr = { chunks: [], bytes: 0 }
    let lineChunks = []
    let lineBytes = 0

    function reportFailure(error) {
      if (failure) return
      failure = error
      child.stdout.destroy()
      child.stderr.destroy()
      child.stdin.destroy()
      child.kill("SIGTERM")
      if (settled) errorHandler(error)
      else reject(error)
    }

    function appendLinePart(buffer) {
      if (lineBytes + buffer.length > SSH_STDOUT_LIMIT) {
        reportFailure(new Error("remote Codex SSH response line exceeded the 16 MiB limit"))
        return false
      }
      if (buffer.length > 0) lineChunks.push(buffer)
      lineBytes += buffer.length
      return true
    }

    function emitLine() {
      let line = Buffer.concat(lineChunks, lineBytes).toString("utf8")
      if (line.endsWith("\r")) line = line.slice(0, -1)
      lineChunks = []
      lineBytes = 0
      messageHandler(line)
    }

    child.stdout.on("data", chunk => {
      if (failure) return
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
      let start = 0
      for (let index = 0; index < buffer.length; index++) {
        if (buffer[index] !== 0x0a) continue
        if (!appendLinePart(buffer.subarray(start, index))) return
        emitLine()
        start = index + 1
      }
      appendLinePart(buffer.subarray(start))
    })
    child.stdout.on("end", () => {
      if (!failure && lineBytes > 0) emitLine()
    })
    child.stderr.on("data", chunk => {
      if (failure) return
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
      if (stderr.bytes + buffer.length > SSH_STDERR_LIMIT) {
        reportFailure(new Error("remote Codex SSH stderr exceeded the 256 KiB limit"))
        return
      }
      stderr.chunks.push(buffer)
      stderr.bytes += buffer.length
    })
    child.on("spawn", () => {
      settled = true
      resolve({
        send(message) {
          if (failure) throw failure
          child.stdin.write(JSON.stringify(message) + "\n")
        },
        close() {
          closedIntentionally = true
          child.stdin.end()
          setTimeout(() => { if (!child.killed) child.kill("SIGTERM") }, 100)
        },
        setMessageHandler(nextHandler) { messageHandler = nextHandler },
        setErrorHandler(nextHandler) {
          errorHandler = nextHandler
          if (failure) errorHandler(failure)
        }
      })
    })
    child.on("error", reportFailure)
    child.on("exit", code => {
      if (closedIntentionally || failure) return
      const stderrText = Buffer.concat(stderr.chunks, stderr.bytes).toString("utf8").trim()
      reportFailure(new Error(stderrText || `ssh exited with status ${code}`))
    })
  })
}
