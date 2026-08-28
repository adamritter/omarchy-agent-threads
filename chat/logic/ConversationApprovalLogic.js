.pragma library
// Purpose: Provides deterministic Conversation Approval behavior for Agent Chat.

var maxToolCharacters = 30000
var maxItemParts = 128

function text(value) {
  return String(value === undefined || value === null ? "" : value)
}

function bounded(value, limit) {
  var result = text(value)
  var cap = Math.max(0, Number(limit) || 0)
  if (cap === 0 || result.length <= cap) return result
  return result.slice(0, cap) + "\n\n[Output truncated]"
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
