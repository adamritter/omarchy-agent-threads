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
