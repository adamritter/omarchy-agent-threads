.pragma library

function threadIsPinned(thread, pinnedSectionId) {
  if (!thread) return false
  if (thread.isPinned === true) return true
  var section = thread.section
  return section !== null && section !== undefined
    && (String(section.id || "") === String(pinnedSectionId || "")
      || String(section.name || "").toLowerCase() === "pinned")
}

function normalizePinnedThreads(items, pinnedSectionId) {
  var normalized = []
  for (var i = 0; i < items.length; i++) {
    var thread = items[i]
    normalized.push(Object.assign({}, thread, {
      isPinned: threadIsPinned(thread, pinnedSectionId)
    }))
  }
  return normalized
}

function nextUnreadThreads(previousStatuses, unreadThreads, nextStatuses, activeThreadId) {
  var nextUnread = Object.assign({}, unreadThreads)
  for (var id in nextStatuses) {
    if ((previousStatuses[id] === "busy" || previousStatuses[id] === "blocked")
        && nextStatuses[id] === "done" && id !== activeThreadId)
      nextUnread[id] = true
    if (id === activeThreadId) delete nextUnread[id]
  }
  return nextUnread
}

function remoteStatusValue(status) {
  var flags = status && Array.isArray(status.activeFlags) ? status.activeFlags : []
  if (flags.indexOf("waitingOnApproval") >= 0
      || flags.indexOf("waitingOnUserInput") >= 0)
    return "blocked"
  var type = typeof status === "string" ? status : String(status && status.type || "")
  return type === "active" ? "busy" : "done"
}

function applyThreadPin(items, threadId, pinned, returnedThread) {
  var wanted = String(threadId || "")
  var next = []
  for (var i = 0; i < items.length; i++) {
    var thread = items[i]
    next.push(String(thread && thread.id || "") === wanted
      ? Object.assign({}, thread, returnedThread || ({}), { isPinned: !!pinned })
      : thread)
  }
  return next
}

function threadIndex(items, threadId) {
  var wanted = String(threadId || "")
  for (var i = 0; i < items.length; i++)
    if (String(items[i] && items[i].id || "") === wanted) return i
  return -1
}

function withoutArchiveTombstones(items, archiveTombstones) {
  var visible = []
  for (var i = 0; i < items.length; i++) {
    var thread = items[i]
    if (archiveTombstones[String(thread && thread.id || "")] !== true)
      visible.push(thread)
  }
  return visible
}
