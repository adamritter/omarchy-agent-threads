.pragma library
// Purpose: Provides deterministic Thread Mutation decisions shared by QML adapters.

function plainObject(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? Object.assign({}, value) : ({})
}

function idleMutationState(tombstones) {
  return {
    kind: "",
    threadId: "",
    pinValue: false,
    movePath: "",
    moveName: "",
    archiveSnapshot: null,
    archiveIndex: -1,
    archiveTombstones: plainObject(tombstones)
  }
}

function normalizedState(state) {
  var source = state || ({})
  return {
    kind: String(source.kind || ""),
    threadId: String(source.threadId || ""),
    pinValue: source.pinValue === true,
    movePath: String(source.movePath || ""),
    moveName: String(source.moveName || ""),
    archiveSnapshot: source.archiveSnapshot || null,
    archiveIndex: Number(source.archiveIndex === undefined
      ? -1 : source.archiveIndex),
    archiveTombstones: plainObject(source.archiveTombstones)
  }
}

function mutationRunning(state) {
  var current = normalizedState(state)
  return current.kind !== "" && current.threadId !== ""
}

function archiveBlockedMessage(threadId, activeThreadId) {
  if (String(threadId || "") === ""
      || String(threadId || "") !== String(activeThreadId || "")) return ""
  return "Close the Codex session that is using this thread before archiving it"
}

function archiveErrorMessage(message) {
  var text = String(message || "").trim()
  if (/already has an active writer/i.test(text))
    return "Close the Codex session that is using this thread before archiving it"
  return text || "Could not archive the Codex thread"
}

function mutationBusyMessage(kind) {
  var action = String(kind || "thread action")
  return "Wait for the current thread action to finish before starting " + action
}

function mutationErrorMessage(kind, message) {
  if (String(kind || "") === "archive") return archiveErrorMessage(message)
  var text = String(message || "").trim()
  if (text !== "") return text
  if (String(kind || "") === "rename") return "Could not rename the thread"
  if (String(kind || "") === "pin") return "Could not update the thread pin"
  return "The thread action failed"
}

function beginMutation(state, kind, threadId, activeThreadId) {
  var current = normalizedState(state)
  var action = String(kind || "")
  var id = String(threadId || "")
  if (["archive", "rename", "pin"].indexOf(action) < 0 || id === "")
    return { accepted: false, state: current, error: "" }
  if (mutationRunning(current)) {
    return {
      accepted: false,
      state: current,
      error: mutationBusyMessage(action)
    }
  }
  var blockedMessage = action === "archive"
    ? archiveBlockedMessage(id, activeThreadId) : ""
  if (blockedMessage !== "") {
    return {
      accepted: false,
      state: current,
      error: blockedMessage
    }
  }
  var next = idleMutationState(current.archiveTombstones)
  next.kind = action
  next.threadId = id
  return { accepted: true, state: next, error: "" }
}

function beginMove(state, threadId, path, name) {
  var current = normalizedState(state)
  var id = String(threadId || "")
  var targetPath = String(path || "")
  if (id === "" || targetPath === "")
    return { accepted: false, state: current, error: "" }
  if (mutationRunning(current)) {
    return {
      accepted: false,
      state: current,
      error: mutationBusyMessage("move")
    }
  }
  var next = idleMutationState(current.archiveTombstones)
  next.kind = "move"
  next.threadId = id
  next.movePath = targetPath
  next.moveName = String(name || "") || targetPath
  return { accepted: true, state: next, error: "" }
}

function withPinValue(state, pinned) {
  var current = normalizedState(state)
  if (current.kind !== "pin") return current
  current.pinValue = pinned === true
  return current
}

function withArchiveSnapshot(state, thread, index) {
  var current = normalizedState(state)
  if (current.kind !== "archive") return current
  current.archiveSnapshot = thread || null
  current.archiveIndex = Number(index === undefined ? -1 : index)
  return current
}

function withArchiveTombstone(state, threadId, archived) {
  var current = normalizedState(state)
  var id = String(threadId || "")
  if (id === "") return current
  var tombstones = plainObject(current.archiveTombstones)
  if (archived) tombstones[id] = true
  else delete tombstones[id]
  current.archiveTombstones = tombstones
  return current
}

function completeMutation(state, kind) {
  var current = normalizedState(state)
  if (current.kind !== String(kind || ""))
    return { applied: false, state: current }
  return {
    applied: true,
    state: idleMutationState(current.archiveTombstones)
  }
}

function resetMutation(state) {
  return idleMutationState(normalizedState(state).archiveTombstones)
}

function restoreArchive(items, state) {
  var current = normalizedState(state)
  if (current.kind !== "archive")
    return { applied: false, items: items || [], state: current }

  var id = current.threadId
  current = withArchiveTombstone(current, id, false)
  var restored = Array.isArray(items) ? items.slice() : []
  var found = false
  for (var i = 0; i < restored.length; i++) {
    if (String(restored[i] && restored[i].id || "") === id) {
      found = true
      break
    }
  }
  if (!found && current.archiveSnapshot) {
    var index = Math.max(0, Math.min(current.archiveIndex, restored.length))
    restored.splice(index, 0, current.archiveSnapshot)
  }
  return {
    applied: true,
    items: restored,
    state: idleMutationState(current.archiveTombstones)
  }
}
