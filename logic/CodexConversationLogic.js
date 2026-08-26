.pragma library

var maxMessageCharacters = 200000
var maxToolCharacters = 30000

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
  for (var i = 0; i < entries.length; i++) {
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

function commandTitle(item) {
  var command = text(item && item.command).trim()
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
    for (var changeIndex = 0; changeIndex < changes.length; changeIndex++) {
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
  var paths = Object.keys(changes)
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
    var summary = Array.isArray(item.summary) ? item.summary.join("\n\n") : text(item.summary)
    var content = summary || (Array.isArray(item.content) ? item.content.join("\n\n") : text(item.content))
    if (content.trim() === "") return null
    return { id: id, role: "reasoning", content: bounded(content, maxToolCharacters),
      title: "Reasoning", status: status }
  }
  if (item.type === "commandExecution") {
    var output = item.aggregatedOutput === null || item.aggregatedOutput === undefined
      ? "" : text(item.aggregatedOutput)
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

function copyMessages(messages) {
  return Array.isArray(messages) ? messages.slice() : []
}

function upsertItem(messages, item) {
  var result = copyMessages(messages)
  var next = itemMessage(item)
  if (!next) return result
  if (next.id === "") next.id = "item-" + result.length + "-" + Date.now()
  for (var i = 0; i < result.length; i++) {
    if (text(result[i] && result[i].id) === next.id) {
      result[i] = Object.assign({}, result[i], next)
      return result
    }
  }
  if (next.role === "user" && result.length > 0) {
    var last = result[result.length - 1] || ({})
    if (text(last.id).indexOf("local-user-") === 0 && last.content === next.content) {
      result[result.length - 1] = next
      return result
    }
  }
  result.push(next)
  return result
}

function appendDelta(messages, itemId, delta, role, title) {
  var result = copyMessages(messages)
  var wanted = text(itemId)
  var addition = text(delta)
  if (addition === "") return result
  for (var i = 0; i < result.length; i++) {
    if (text(result[i] && result[i].id) !== wanted) continue
    result[i] = Object.assign({}, result[i], {
      content: bounded(text(result[i].content) + addition,
        role === "assistant" ? maxMessageCharacters : maxToolCharacters),
      status: "inProgress"
    })
    return result
  }
  result.push({
    id: wanted || "delta-" + result.length + "-" + Date.now(),
    role: role || "assistant",
    content: bounded(addition, role === "assistant" ? maxMessageCharacters : maxToolCharacters),
    title: title || (role === "reasoning" ? "Reasoning" : "Codex"),
    status: "inProgress"
  })
  return result
}

function normalizeThread(thread) {
  var result = []
  var turns = thread && Array.isArray(thread.turns) ? thread.turns : []
  for (var i = 0; i < turns.length; i++) {
    var items = turns[i] && Array.isArray(turns[i].items) ? turns[i].items : []
    for (var j = 0; j < items.length; j++) result = upsertItem(result, items[j])
  }
  return result
}

function optimisticUserMessage(messages, content) {
  var result = copyMessages(messages)
  result.push({ id: "local-user-" + Date.now(), role: "user",
    content: bounded(content, maxMessageCharacters), title: "You", status: "completed" })
  return result
}

function approvalSummary(method, params) {
  var values = params && typeof params === "object" ? params : ({})
  if (method === "item/commandExecution/requestApproval")
    return { title: "Run command?", detail: text(values.command || values.reason), kind: "command" }
  if (method === "item/fileChange/requestApproval") {
    var paths = Object.keys(values.fileChanges || values.changes || ({}))
    return { title: "Apply file changes?", detail: paths.join("\n") || text(values.reason), kind: "file" }
  }
  if (method === "item/permissions/requestApproval")
    return { title: "Grant additional permissions?", detail: text(values.reason), kind: "permissions" }
  return { title: "Codex needs input", detail: text(values.reason || method), kind: "unknown" }
}
