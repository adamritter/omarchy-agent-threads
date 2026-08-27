.pragma library

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

function promptCharacterLimit() {
  return maxPromptCharacters
}

function boundedPromptInput(value) {
  return text(value).slice(0, maxPromptCharacters)
}

function promptValidationError(value) {
  return text(value).length > maxPromptCharacters
    ? "Prompt exceeds the 200,000 character limit" : ""
}

function protocolStructureError(value) {
  var stack = [{ value: value, depth: 0 }]
  var nodes = 1
  var textCharacters = 0
  while (stack.length > 0) {
    var current = stack.pop()
    var entry = current.value
    if (typeof entry === "string") {
      if (entry.length > maxProtocolStringCharacters)
        return "message contains an oversized string"
      textCharacters += entry.length
      if (textCharacters > maxProtocolTextCharacters)
        return "message contains too much text"
    }
    if (!entry || typeof entry !== "object") continue
    if (current.depth >= maxProtocolDepth) return "message nesting is too deep"
    if (Array.isArray(entry)) {
      if (entry.length > maxProtocolArrayEntries)
        return "message contains too many array entries"
      nodes += entry.length
      if (nodes > maxProtocolNodes) return "message contains too many values"
      for (var arrayIndex = 0; arrayIndex < entry.length; arrayIndex++) {
        var arrayValue = entry[arrayIndex]
        if (typeof arrayValue === "string"
            && arrayValue.length > maxProtocolStringCharacters)
          return "message contains an oversized string"
        if (typeof arrayValue === "string") {
          textCharacters += arrayValue.length
          if (textCharacters > maxProtocolTextCharacters)
            return "message contains too much text"
        }
        if (arrayValue && typeof arrayValue === "object")
          stack.push({ value: arrayValue, depth: current.depth + 1 })
      }
      continue
    }
    var properties = 0
    for (var key in entry) {
      if (!Object.prototype.hasOwnProperty.call(entry, key)) continue
      if (key.length > maxProtocolStringCharacters)
        return "message contains an oversized property name"
      textCharacters += key.length
      if (textCharacters > maxProtocolTextCharacters)
        return "message contains too much text"
      properties++
      nodes++
      if (properties > maxProtocolObjectEntries)
        return "message contains too many object properties"
      if (nodes > maxProtocolNodes) return "message contains too many values"
      var objectValue = entry[key]
      if (typeof objectValue === "string"
          && objectValue.length > maxProtocolStringCharacters)
        return "message contains an oversized string"
      if (typeof objectValue === "string") {
        textCharacters += objectValue.length
        if (textCharacters > maxProtocolTextCharacters)
          return "message contains too much text"
      }
      if (objectValue && typeof objectValue === "object")
        stack.push({ value: objectValue, depth: current.depth + 1 })
    }
  }
  return ""
}

function requestTimeoutMs() {
  return finiteRequestTimeoutMilliseconds
}

function trackRequestDeadline(deadlines, requestId, label, now, timeoutMs) {
  var result = Object.assign({}, deadlines || ({}))
  var duration = Math.max(1, Number(timeoutMs) || finiteRequestTimeoutMilliseconds)
  result[String(requestId)] = {
    id: Number(requestId),
    label: text(label),
    deadline: Number(now) + duration
  }
  return result
}

function clearRequestDeadline(deadlines, requestId) {
  var result = Object.assign({}, deadlines || ({}))
  delete result[String(requestId)]
  return result
}

function takeExpiredRequestDeadlines(deadlines, now) {
  var source = deadlines || ({})
  var remaining = ({})
  var expired = []
  var currentTime = Number(now)
  for (var key in source) {
    if (!Object.prototype.hasOwnProperty.call(source, key)) continue
    var entry = source[key] || ({})
    if (Number(entry.deadline) <= currentTime) expired.push(entry)
    else remaining[key] = entry
  }
  return { remaining: remaining, expired: expired }
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

function aggregateFileParts(parts, turnId) {
  var sourceParts = Array.isArray(parts) ? parts.slice(-maxAggregateFileParts) : []
  var content = []
  var output = []
  var sourceIds = []
  var status = "completed"
  for (var i = 0; i < sourceParts.length; i++) {
    var part = sourceParts[i] || ({})
    if (text(part.content).trim() !== "") content.push(text(part.content))
    if (text(part.output).trim() !== "") output.push(text(part.output))
    sourceIds.push(text(part.id))
    if (part.status === "inProgress") status = "inProgress"
  }
  return {
    id: "turn-file-changes-" + text(turnId),
    role: "tool",
    content: bounded(content.join("\n\n"), maxToolCharacters),
    output: bounded(output.join("\n\n"), maxToolCharacters),
    title: "File changes",
    status: status,
    kind: "file",
    turnId: text(turnId),
    sourceIds: sourceIds,
    fileParts: sourceParts
  }
}

function retainedMessageSize(message) {
  var value = message || ({})
  var size = text(value.id).length + text(value.title).length
    + text(value.content).length + text(value.output).length
    + text(value.detail).length
  var parts = Array.isArray(value.fileParts) ? value.fileParts : []
  for (var i = 0; i < parts.length; i++)
    size += text(parts[i] && parts[i].content).length
      + text(parts[i] && parts[i].output).length
  return size
}

function retainRecentMessages(messages) {
  var entries = Array.isArray(messages) ? messages : []
  var result = []
  var characters = 0
  for (var i = entries.length - 1;
      i >= 0 && result.length < maxRetainedMessages; i--) {
    var size = retainedMessageSize(entries[i])
    if (result.length > 0 && characters + size > maxRetainedCharacters) break
    result.push(entries[i])
    characters += size
  }
  result.reverse()
  return result
}

function copyMessages(messages) {
  return retainRecentMessages(messages)
}

function upsertItem(messages, item, turnId) {
  var result = copyMessages(messages)
  var next = itemMessage(item)
  if (!next) return result
  if (next.id === "") next.id = "item-" + result.length + "-" + Date.now()
  var turn = text(turnId)
  if (next.kind === "file" && next.status !== "failed" && turn !== "") {
    var aggregateId = "turn-file-changes-" + turn
    for (var aggregateIndex = 0; aggregateIndex < result.length; aggregateIndex++) {
      if (text(result[aggregateIndex] && result[aggregateIndex].id) !== aggregateId) continue
      var existingParts = Array.isArray(result[aggregateIndex].fileParts)
        ? result[aggregateIndex].fileParts.slice() : []
      var replaced = false
      for (var partIndex = 0; partIndex < existingParts.length; partIndex++) {
        if (text(existingParts[partIndex] && existingParts[partIndex].id) !== next.id) continue
        existingParts[partIndex] = next
        replaced = true
        break
      }
      if (!replaced) existingParts.push(next)
      result[aggregateIndex] = aggregateFileParts(existingParts, turn)
      return result
    }
    result.push(aggregateFileParts([next], turn))
    return retainRecentMessages(result)
  }
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
  return retainRecentMessages(result)
}

function appendDelta(messages, itemId, delta, role, title) {
  var result = copyMessages(messages)
  var wanted = text(itemId)
  var addition = text(delta)
  if (addition === "") return result
  for (var i = 0; i < result.length; i++) {
    var sourceIds = Array.isArray(result[i] && result[i].sourceIds)
      ? result[i].sourceIds : []
    if (sourceIds.indexOf(wanted) >= 0) {
      var parts = Array.isArray(result[i].fileParts) ? result[i].fileParts.slice() : []
      for (var partIndex = 0; partIndex < parts.length; partIndex++) {
        if (text(parts[partIndex] && parts[partIndex].id) !== wanted) continue
        parts[partIndex] = Object.assign({}, parts[partIndex], {
          output: bounded(text(parts[partIndex].output) + addition, maxToolCharacters),
          status: "inProgress"
        })
        result[i] = aggregateFileParts(parts, result[i].turnId)
        return result
      }
    }
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
  return retainRecentMessages(result)
}

function normalizeThread(thread) {
  var result = []
  var turns = thread && Array.isArray(thread.turns) ? thread.turns : []
  var batches = []
  var remainingItems = maxThreadItems
  var firstTurn = Math.max(0, turns.length - maxThreadTurns)
  for (var turnIndex = turns.length - 1;
      turnIndex >= firstTurn && remainingItems > 0; turnIndex--) {
    var turn = turns[turnIndex] || ({})
    var items = Array.isArray(turn.items) ? turn.items : []
    var take = Math.min(items.length, remainingItems)
    if (take > 0) batches.unshift({
      turnId: text(turn.id),
      items: items.slice(items.length - take)
    })
    remainingItems -= take
  }
  for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
    var batch = batches[batchIndex]
    for (var itemIndex = 0; itemIndex < batch.items.length; itemIndex++)
      result = upsertItem(result, batch.items[itemIndex], batch.turnId)
  }
  return result
}

function completedTurnItems(turn) {
  var items = turn && Array.isArray(turn.items) ? turn.items : []
  return items.slice(-maxThreadItems)
}

function boundedModelEntries(entries) {
  return Array.isArray(entries) ? entries.slice(0, maxModelEntries) : []
}

function threadActivity(thread) {
  var turns = thread && Array.isArray(thread.turns) ? thread.turns : []
  if (turns.length === 0) return { busy: false, turnId: "" }
  var last = turns[turns.length - 1] || ({})
  var busy = text(last.status) === "inProgress"
  return { busy: busy, turnId: busy ? text(last.id) : "" }
}

function optimisticUserMessage(messages, content) {
  var result = copyMessages(messages)
  result.push({ id: "local-user-" + Date.now(), role: "user",
    content: bounded(content, maxMessageCharacters), title: "You", status: "completed" })
  return retainRecentMessages(result)
}

function approvalSummary(method, params) {
  var values = params && typeof params === "object" ? params : ({})
  if (method === "item/commandExecution/requestApproval")
    return { title: "Run command?",
      detail: bounded(values.command || values.reason, maxToolCharacters), kind: "command" }
  if (method === "item/fileChange/requestApproval") {
    var changes = values.fileChanges || values.changes || ({})
    var paths = []
    for (var path in changes) {
      if (!Object.prototype.hasOwnProperty.call(changes, path)) continue
      paths.push(path)
      if (paths.length >= maxItemParts) break
    }
    return { title: "Apply file changes?",
      detail: bounded(paths.join("\n") || values.reason, maxToolCharacters), kind: "file" }
  }
  if (method === "item/permissions/requestApproval")
    return { title: "Grant additional permissions?",
      detail: bounded(values.reason, maxToolCharacters), kind: "permissions" }
  return { title: "Codex needs input",
    detail: bounded(values.reason || method, maxToolCharacters), kind: "unknown" }
}
