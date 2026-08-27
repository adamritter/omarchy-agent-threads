import fs from "node:fs"
import path from "node:path"
import { spawn } from "node:child_process"
import { fileURLToPath } from "node:url"
import { collectSshOutput, shellQuote } from "./remote-transport.mjs"

function sourceWithInlineImports(entryPath) {
  const moduleUrl = filePath => {
    let source = fs.readFileSync(filePath, "utf8")
    source = source.replace(/from\s+"(\.\/[^\"]+)"/g, (_match, relativePath) => {
      const dependency = path.resolve(path.dirname(filePath), relativePath)
      return `from "${moduleUrl(dependency)}"`
    })
    return `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`
  }
  let source = fs.readFileSync(entryPath, "utf8")
  return source.replace(/from\s+"(\.\/[^\"]+)"/g, (_match, relativePath) => {
    const dependency = path.resolve(path.dirname(entryPath), relativePath)
    return `from "${moduleUrl(dependency)}"`
  })
}

export function providerTypeForHost(host) {
  const value = String(host && host.providerType || "").toLowerCase()
  return value === "claude" || value === "opencode" ? value : "codex"
}

export async function runRemoteClaude(host, request) {
  const { hostId, action, actionValue, actionExtra, actionName } = request
  if (host.type !== "ssh") throw new Error("Claude remotes require SSH")
  const sshHost = String(host.sshHost || "").trim()
  if (!/^[A-Za-z0-9_.@:-]+$/.test(sshHost)) throw new Error("invalid SSH host or alias")
  const claudeCommand = String(host.claudeCommand || "claude").trim()
  if (!/^[A-Za-z0-9_./-]+$/.test(claudeCommand)) throw new Error("invalid remote Claude command")
  if (!["snapshot", "archive", "pin", "rename"].includes(action)) throw new Error("unsupported Claude action")
  if ((action === "archive" || action === "pin" || action === "rename")
      && !/^[A-Za-z0-9._-]+$/.test(actionValue)) throw new Error("invalid Claude session id")
  if (action === "pin" && actionExtra !== "true" && actionExtra !== "false")
    throw new Error("invalid pin value")

  const helperPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "..",
    "omarchy-agent-provider-query")
  const helperSource = sourceWithInlineImports(helperPath)
  const remoteCommand = `OMARCHY_CLAUDE_COMMAND=${shellQuote(claudeCommand)} `
    + `node --input-type=module - claude ${shellQuote(action)} `
    + `${shellQuote(actionValue)} '' ${shellQuote(action === "rename" ? actionName : actionExtra)}`
  const child = spawn("ssh", [
    "-T",
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=8",
    sshHost,
    remoteCommand
  ], { stdio: ["pipe", "pipe", "pipe"] })

  const outputPromise = collectSshOutput(child, "Claude")
  child.stdin.end(helperSource)
  const { code, stdout, stderr } = await outputPromise
  if (code !== 0)
    throw new Error(stderr.trim() || `remote Claude query exited with status ${code}`)
  const response = stdout.trim()
  if (response === "")
    throw new Error(stderr.trim() || "remote Claude helper returned no response")
  let result
  try { result = JSON.parse(response) } catch { throw new Error("invalid remote Claude response") }
  if (!result || typeof result !== "object" || Array.isArray(result))
    throw new Error("invalid remote Claude response")
  if (action === "snapshot") {
    const error = result.available === false
      ? "Install Claude Code on the remote machine, then test the connection again"
      : String(result.error || "")
    process.stdout.write(JSON.stringify({
      ...result,
      hostId,
      label: String(host.label || host.id || "Remote"),
      providerType: "claude",
      type: "ssh",
      error
    }) + "\n")
  } else {
    process.stdout.write(JSON.stringify({ ...result, hostId, action }) + "\n")
  }
}

export async function runRemoteOpenCode(host, request) {
  const { hostId, action, actionValue, actionExtra, actionName } = request
  if (host.type !== "ssh") throw new Error("OpenCode remotes require SSH")
  const sshHost = String(host.sshHost || "").trim()
  if (!/^[A-Za-z0-9_.@:-]+$/.test(sshHost)) throw new Error("invalid SSH host or alias")
  const openCodeCommand = String(host.opencodeCommand || "opencode").trim()
  if (!/^[A-Za-z0-9_./-]+$/.test(openCodeCommand)) throw new Error("invalid remote OpenCode command")
  const openCodePort = Number(host.opencodePort || 43962)
  if (!Number.isInteger(openCodePort) || openCodePort < 1024 || openCodePort > 65535)
    throw new Error("invalid remote OpenCode port")
  if (!["snapshot", "archive", "pin", "rename"].includes(action)) throw new Error("unsupported OpenCode action")
  if ((action === "archive" || action === "pin" || action === "rename")
      && !/^[A-Za-z0-9._-]+$/.test(actionValue)) throw new Error("invalid OpenCode session id")
  if (action === "pin" && actionExtra !== "true" && actionExtra !== "false")
    throw new Error("invalid pin value")

  const helperPath = path.join(path.dirname(fileURLToPath(import.meta.url)),
    "opencode-provider.mjs")
  const providerSource = sourceWithInlineImports(helperPath).replace(/^export /gm, "")
  const launcherSource = `
const [, requestedAction = "snapshot", sessionID = "", sessionPath = "", pinValue = "", renameValue = ""] = process.argv.slice(2)
async function runRemoteOpenCodeHelper() {
  if (requestedAction === "snapshot") {
    process.stdout.write(JSON.stringify(await openCodeSnapshot()) + "\\n")
    return
  }
  if (requestedAction === "archive") {
    await archiveOpenCode(sessionID, sessionPath)
    process.stdout.write(JSON.stringify({ ok: true }) + "\\n")
    return
  }
  if (requestedAction === "rename") {
    await renameOpenCode(sessionID, sessionPath, renameValue)
    process.stdout.write(JSON.stringify({ ok: true }) + "\\n")
    return
  }
  if (requestedAction === "pin") {
    if (!sessionID) throw new Error("missing session id")
    const metadata = loadMetadata()
    const key = \`opencode:\${sessionID}\`
    const entry = metadata[key] && typeof metadata[key] === "object" ? metadata[key] : {}
    entry.pinned = pinValue === "true"
    metadata[key] = entry
    fs.mkdirSync(path.dirname(metadataPath), { recursive: true, mode: 0o700 })
    const temporary = \`\${metadataPath}.\${process.pid}.tmp\`
    fs.writeFileSync(temporary, JSON.stringify(metadata) + "\\n", { mode: 0o600 })
    fs.renameSync(temporary, metadataPath)
    process.stdout.write(JSON.stringify({ ok: true }) + "\\n")
    return
  }
  throw new Error("unsupported action")
}
runRemoteOpenCodeHelper().catch(error => {
  process.stderr.write(String(error && error.message || error) + "\\n")
  process.exit(2)
})
`
  const helperSource = providerSource + launcherSource

  const serverURL = `http://127.0.0.1:${openCodePort}`
  const stateDirectory = '"$HOME/.local/state/omarchy/codex-threads"'
  const logPath = '"$HOME/.local/state/omarchy/codex-threads/opencode-remote-server.log"'
  const ensureServer = `set -eu; mkdir -p ${stateDirectory}; `
    + `if ! curl -fsS --max-time 2 ${shellQuote(serverURL + "/global/health")} >/dev/null 2>&1; then `
    + `nohup env -u OPENCODE_SERVER_PASSWORD -u OPENCODE_SERVER_USERNAME `
    + `${shellQuote(openCodeCommand)} serve --hostname 127.0.0.1 --port ${openCodePort} `
    + `</dev/null >>${logPath} 2>&1 & `
    + `i=0; while [ "$i" -lt 120 ]; do `
    + `curl -fsS --max-time 2 ${shellQuote(serverURL + "/global/health")} >/dev/null 2>&1 && break; `
    + `i=$((i + 1)); sleep 0.25; done; fi; `
    + `curl -fsS --max-time 2 ${shellQuote(serverURL + "/global/health")} >/dev/null 2>&1 `
    + `|| { echo 'OpenCode API did not become ready within 30 seconds' >&2; exit 70; }; `
  const threadPath = action === "archive" || action === "rename" ? actionExtra : ""
  const pinValue = action === "pin" ? actionExtra : ""
  const renameValue = action === "rename" ? actionName : ""
  const remoteCommand = ensureServer
    + `XDG_RUNTIME_DIR="$HOME/.cache/omarchy-codex-threads-runtime" `
    + `OMARCHY_OPENCODE_URL=${shellQuote(serverURL)} node --input-type=module - opencode `
    + `${shellQuote(action)} ${shellQuote(actionValue)} ${shellQuote(threadPath)} ${shellQuote(pinValue)} `
    + shellQuote(renameValue)
  const child = spawn("ssh", [
    "-T",
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=8",
    sshHost,
    remoteCommand
  ], { stdio: ["pipe", "pipe", "pipe"] })

  const outputPromise = collectSshOutput(child, "OpenCode")
  child.stdin.end(helperSource)
  const { code, stdout, stderr } = await outputPromise
  if (code !== 0)
    throw new Error(stderr.trim() || `remote OpenCode query exited with status ${code}`)
  let result
  try { result = JSON.parse(stdout.trim() || "{}") } catch {
    throw new Error(stderr.trim() || "invalid remote OpenCode response")
  }
  if (!result || typeof result !== "object" || Array.isArray(result))
    throw new Error(stderr.trim() || "invalid remote OpenCode response")
  const envelope = action === "snapshot" ? {
    ...result,
    hostId,
    label: String(host.label || host.id || "Remote"),
    providerType: "opencode",
    type: "ssh"
  } : { ...result, hostId, action }
  process.stdout.write(JSON.stringify(envelope) + "\n")
}
