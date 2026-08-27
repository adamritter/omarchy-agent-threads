.pragma library
.import "ConversationItemLogic.js" as Items

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
  var next = Items.itemMessage(item)
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
