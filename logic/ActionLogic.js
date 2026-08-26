.pragma library

function selectedRow(rows, selectedIndex) {
  return selectedIndex >= 0 && selectedIndex < rows.length ? rows[selectedIndex] : null
}

function newThreadTarget(activeProvider, homePath, row, providerHost) {
  var path = String(row && (row.path || (row.host ? row.host.home : "")) || homePath || "")
  if (row && row.remoteId)
    return { remoteId: String(row.remoteId), path: path, error: "" }
  if (activeProvider !== "codex") {
    if (!providerHost) return { remoteId: "", path: path, error: "provider-not-ready" }
    return { remoteId: String(providerHost.id || ""), path: path, error: "" }
  }
  return { remoteId: "", path: path, error: "" }
}

function projectPickerTarget(activeProvider, homePath, row, selectedHost, providerHost) {
  var host = selectedHost || null
  var hostId = String(row && row.remoteId || "")
  var providerType = String(activeProvider || "codex")
  var path = String(row && (row.path || (row.host ? row.host.home : "")) || "")

  if (hostId === "" && activeProvider !== "codex") {
    host = providerHost || null
    if (!host) {
      return {
        hostId: "",
        providerType: providerType,
        path: path || String(homePath || ""),
        error: "provider-not-ready"
      }
    }
    hostId = String(host.id || "")
  }
  if (host) providerType = String(host.providerType || providerType || "codex")
  if (path === "") path = String(host && host.home || homePath || "")
  return { hostId: hostId, providerType: providerType, path: path, error: "" }
}

function terminalTarget(activeProvider, homePath, row, providerHost) {
  var host = row && row.host ? row.host : null
  var remoteId = String(row && row.remoteId || "")
  if (!row && activeProvider !== "codex") {
    host = providerHost || null
    remoteId = String(host && host.id || "")
  }

  var path = String(row && row.path || host && host.home || homePath || "")
  if (remoteId !== "" && !host)
    return { mode: "", endpoint: "", path: path, error: "remote-not-ready" }

  var connectionType = String(host && host.type || "")
  if (connectionType === "app-server")
    return { mode: "", endpoint: "", path: path, error: "ssh-required" }
  if (connectionType === "ssh") {
    var endpoint = String(host.sshHost || host.address || "")
    if (endpoint === "")
      return { mode: "", endpoint: "", path: path, error: "ssh-host-missing" }
    return { mode: "ssh", endpoint: endpoint, path: path, error: "" }
  }
  return { mode: "local", endpoint: "-", path: path, error: "" }
}

function normalizeThreadFrontend(value) {
  return String(value || "").toLowerCase() === "agent-chat"
    ? "agent-chat" : "terminal"
}

function agentChatCommand(helperPath, threadId, cwd, model, effort) {
  var command = [String(helperPath || "")]
  var id = String(threadId || "").trim()
  if (id !== "") command.push("resume", id)
  command.push("-C", String(cwd || ""))
  var selectedModel = String(model || "").trim()
  var selectedEffort = String(effort || "").trim()
  if (selectedModel !== "") command.push("--model", selectedModel)
  if (selectedEffort !== "") command.push("--effort", selectedEffort)
  return command
}
