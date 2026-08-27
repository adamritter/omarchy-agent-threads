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

function mergeProviderUnread(previousThreads, nextThreads, activeThreadId) {
  var previous = Array.isArray(previousThreads) ? previousThreads : []
  var incoming = Array.isArray(nextThreads) ? nextThreads : []
  var byId = ({})
  for (var previousIndex = 0; previousIndex < previous.length; previousIndex++) {
    var previousThread = previous[previousIndex]
    var previousId = String(previousThread && previousThread.id || "")
    if (previousId !== "") byId[previousId] = previousThread
  }

  var activeId = String(activeThreadId || "")
  var merged = []
  for (var nextIndex = 0; nextIndex < incoming.length; nextIndex++) {
    var next = incoming[nextIndex]
    var id = String(next && next.id || "")
    var old = byId[id]
    var wasActive = old && remoteStatusValue(old.status) !== "done"
    var nowActive = remoteStatusValue(next && next.status) !== "done"
    var unread = next && next.attention === true || (old && old.unread === true)
    if (wasActive && !nowActive && id !== activeId) unread = true
    if (old && String(next && next.completionToken || "") !== ""
        && String(next.completionToken) !== String(old.completionToken || "")
        && id !== activeId) unread = true
    if (old && String(next && next.attentionToken || "") !== ""
        && String(next.attentionToken) !== String(old.attentionToken || "")
        && id !== activeId) unread = true
    if (id === activeId) unread = false
    merged.push(Object.assign({}, next, { unread: unread === true }))
  }
  return merged
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
