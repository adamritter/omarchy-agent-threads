.pragma library
// Purpose: Provides deterministic Conversation Item behavior for Agent Chat.

var maxMessageCharacters = 200000
var maxToolCharacters = 30000
var maxRetainedMessages = 400
var maxRetainedCharacters = 8 * 1024 * 1024
var maxAggregateFileParts = 32
var maxPromptCharacters = 200000
var maxProtocolDepth = 48
var maxProtocolNodes = 50000
var maxProtocolArrayEntries = 5000
var maxProtocolObjectEntries = 5000
var maxProtocolStringCharacters = 2 * 1024 * 1024
var maxProtocolTextCharacters = 8 * 1024 * 1024
var maxThreadTurns = 200
var maxThreadItems = 1000
var maxItemParts = 128
var maxModelEntries = 200
var finiteRequestTimeoutMilliseconds = 15000

function text(value) {
  return String(value === undefined || value === null ? "" : value)
}

function bounded(value, limit) {
  var result = text(value)
  var cap = Math.max(0, Number(limit) || 0)
  if (cap === 0 || result.length <= cap) return result
  return result.slice(0, cap) + "\n\n[Output truncated]"
}
function inputText(inputs) {
  var entries = Array.isArray(inputs) ? inputs : []
  var parts = []
  for (var i = 0; i < entries.length && i < maxItemParts; i++) {
    var input = entries[i] || ({})
    if (input.type === "text") parts.push(text(input.text))
    else if (input.type === "localImage") parts.push("[Image: " + text(input.path) + "]")
    else if (input.type === "image") parts.push("[Image]")
    else if (input.type === "localAudio") parts.push("[Audio: " + text(input.path) + "]")
    else if (input.type === "audio") parts.push("[Audio]")
    else if (input.type === "skill") parts.push("[Skill: " + text(input.name) + "]")
    else if (input.type === "mention") parts.push("[Mention: " + text(input.name) + "]")
  }
  return parts.join("\n\n")
}

function commandText(command) {
  if (!Array.isArray(command)) return text(command)
  var parts = []
  for (var i = 0; i < command.length && i < maxItemParts; i++)
    parts.push(text(command[i]))
  return parts.join("\n")
}

function embeddedGitPatches(command) {
  var source = commandText(command).replace(/'\\''/g, "'")
  var pattern = /(?:^|\n)[^\n]*\bgit\s+apply\b[^\n]*<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*\n([\s\S]*?)\n\2['"]*[ \t]*(?=\n|$)/g
  var patches = []
  var match
  while ((match = pattern.exec(source)) !== null) {
    var patch = text(match[3]).trim()
    if (/^(?:diff --git |--- )/m.test(patch)) patches.push(patch)
  }
  if (patches.length === 0 && /\bgit\s+apply\b/.test(source)) {
    var lines = source.split("\n")
    var collected = []
    for (var i = 0; i < lines.length; i++) {
      if (collected.length === 0 && /^diff --git /.test(lines[i])) collected.push(lines[i])
      else if (collected.length > 0 && /^[A-Z_][A-Z0-9_]*['"]*$/.test(lines[i])) break
      else if (collected.length > 0) collected.push(lines[i])
    }
    if (collected.length > 0) patches.push(collected.join("\n").trim())
  }
  return patches.join("\n\n")
}

function outputGitPatch(output) {
  var value = text(output).replace(/\r/g, "").trim()
  return /^(?:diff --git |--- )/m.test(value) && /^\+\+\+ /m.test(value) ? value : ""
}

function opaqueGitPatchSummary(command, output) {
  var source = commandText(command)
  if (!/\bgit\s+apply\b/.test(source)) return ""
  var paths = []
  var seen = ({})
  var addPath = function(value) {
    var path = text(value).trim()
    if (path === "" || seen[path]) return
    seen[path] = true
    paths.push(path)
  }
  var labelPattern = /--label\s+[ab]\/([^\s'";]+)/g
  var labelMatch
  while ((labelMatch = labelPattern.exec(source)) !== null) addPath(labelMatch[1])
  var statLines = text(output).replace(/\r/g, "").split("\n")
  for (var i = 0; i < statLines.length; i++) {
    var statMatch = statLines[i].match(/^\s*(.+?)\s+\|\s+\d+/)
    if (statMatch) addPath(statMatch[1])
  }
  var summaries = []
  for (var pathIndex = 0; pathIndex < paths.length; pathIndex++)
    summaries.push("UPDATE  " + paths[pathIndex]
      + "\n[Diff unavailable: applied from a temporary patch file]")
  return summaries.join("\n\n")
}

function commandTitle(item) {
  var command = commandText(item && item.command).trim()
  if (command === "") return "Command"
  var firstLine = command.split("\n")[0]
  return firstLine.length > 96 ? firstLine.slice(0, 93) + "..." : firstLine
}

function fileChangeText(item) {
  var changes = item && item.changes && typeof item.changes === "object"
    ? item.changes : (item && item.fileChanges && typeof item.fileChanges === "object"
      ? item.fileChanges : ({}))
  if (Array.isArray(changes)) {
    var rendered = []
    for (var changeIndex = 0;
        changeIndex < changes.length && changeIndex < maxItemParts; changeIndex++) {
      var entry = changes[changeIndex] || ({})
      var kindValue = entry.kind && typeof entry.kind === "object"
        ? entry.kind.type : (entry.kind || entry.type)
      var kind = text(kindValue || "update").toUpperCase()
      var path = text(entry.path || entry.move_path)
      var diff = text(entry.diff || entry.unified_diff || entry.content)
      var section = (kind + "  " + path).trim()
      if (diff !== "") section += "\n" + diff
      if (section !== "") rendered.push(section)
    }
    if (rendered.length > 0) return rendered.join("\n\n")
    return text(item && (item.diff || item.output))
  }
  var paths = []
  for (var changePath in changes) {
    if (!Object.prototype.hasOwnProperty.call(changes, changePath)) continue
    paths.push(changePath)
    if (paths.length >= maxItemParts) break
  }
  if (paths.length === 0) return text(item && (item.diff || item.output))
  var lines = []
  for (var i = 0; i < paths.length; i++) {
    var change = changes[paths[i]] || ({})
    var type = text(change.type || "update").toUpperCase()
    var header = type + "  " + paths[i]
    var patch = text(change.diff || change.unified_diff || change.content)
    lines.push(patch !== "" ? header + "\n" + patch : header)
  }
  return lines.join("\n")
}

function itemMessage(item) {
  if (!item || typeof item !== "object") return null
  var id = text(item.id)
  var status = text(item.status || "completed")
  if (item.type === "userMessage") {
    return { id: id, role: "user", content: bounded(inputText(item.content), maxMessageCharacters),
      title: "You", status: status }
  }
  if (item.type === "agentMessage") {
    return { id: id, role: "assistant", content: bounded(item.text, maxMessageCharacters),
      title: "Codex", status: status }
  }
  if (item.type === "reasoning") {
    var summary = Array.isArray(item.summary)
      ? item.summary.slice(-maxItemParts).join("\n\n") : text(item.summary)
    var content = summary || (Array.isArray(item.content)
      ? item.content.slice(-maxItemParts).join("\n\n") : text(item.content))
    if (content.trim() === "") return null
    return { id: id, role: "reasoning", content: bounded(content, maxToolCharacters),
      title: "Reasoning", status: status }
  }
  if (item.type === "commandExecution") {
    var output = item.aggregatedOutput === null || item.aggregatedOutput === undefined
      ? "" : text(item.aggregatedOutput)
    var patches = embeddedGitPatches(item.command)
    if (patches === "" && /\bgit\s+apply\b/.test(commandText(item.command))) {
      patches = outputGitPatch(output)
      if (patches !== "") output = ""
      else patches = opaqueGitPatchSummary(item.command, output)
    }
    if (patches !== "") {
      return { id: id, role: "tool", content: bounded(patches, maxToolCharacters),
        output: bounded(output, maxToolCharacters),
        title: status === "failed" ? "Patch failed" : "File changes",
        status: status, kind: "file" }
    }
    return { id: id, role: "tool", content: bounded(output, maxToolCharacters),
      title: commandTitle(item), status: status, detail: text(item.command), kind: "command" }
  }
  if (item.type === "fileChange") {
    var fileContent = fileChangeText(item)
    if (fileContent.trim() === "") return null
    return { id: id, role: "tool", content: bounded(fileContent, maxToolCharacters),
      title: "File changes", status: status, kind: "file" }
  }
  if (item.type === "mcpToolCall") {
    var mcpName = text(item.server) + (item.tool ? " · " + text(item.tool) : "")
    var mcpContent = item.result === undefined ? text(item.arguments)
      : (typeof item.result === "string" ? item.result : JSON.stringify(item.result, null, 2))
    return { id: id, role: "tool", content: bounded(mcpContent, maxToolCharacters),
      title: mcpName || "MCP tool", status: status, kind: "mcp" }
  }
  if (item.type === "webSearch") {
    return { id: id, role: "tool", content: bounded(item.query || item.action, maxToolCharacters),
      title: "Web search", status: status, kind: "web" }
  }
  if (item.type === "plan") {
    return { id: id, role: "tool", content: bounded(item.text, maxToolCharacters),
      title: "Plan", status: status, kind: "plan" }
  }
  if (item.type === "error") {
    return { id: id, role: "error", content: bounded(item.message || item.text, maxToolCharacters),
      title: "Error", status: "failed" }
  }
  return null
}
