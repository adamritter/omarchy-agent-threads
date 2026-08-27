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

function notificationEvents(previousStates, nextStates) {
  var events = []
  var previous = previousStates && typeof previousStates === "object"
    ? previousStates : ({})
  var next = nextStates && typeof nextStates === "object" ? nextStates : ({})
  for (var key in next) {
    var before = previous[key]
    var after = next[key]
    if (!before || !after) continue
    if (before.status !== "blocked" && after.status === "blocked") {
      events.push({
        key: key,
        type: "blocked",
        title: String(after.title || "Untitled agent thread")
      })
    } else if (before.ready !== true && after.ready === true) {
      events.push({
        key: key,
        type: "ready",
        title: String(after.title || "Untitled agent thread")
      })
    }
  }
  return events
}

function notificationCommands(event) {
  var blocked = event && event.type === "blocked"
  var heading = blocked ? "Agent thread needs attention" : "Agent thread is ready"
  var title = String(event && event.title || "Untitled agent thread")
  return {
    desktop: [
      "notify-send", "-a", "Agent Threads", "-u", "normal",
      "-i", blocked ? "dialog-warning-symbolic" : "emblem-default-symbolic",
      heading, title
    ],
    sound: [
      "canberra-gtk-play", "-i", blocked ? "dialog-warning" : "complete",
      "-d", heading
    ]
  }
}

function readyThreadTargets(localThreads, unreadThreads, supplementalHosts) {
  var targets = []
  var order = 0

  function append(thread, host, providerType, scope) {
    var id = String(thread && thread.id || "")
    if (id === "") return
    targets.push({
      threadId: id,
      thread: thread,
      host: host,
      hostId: host ? String(host.id || "") : "provider-codex",
      providerType: String(providerType || "codex").toLowerCase(),
      scope: String(scope || "local"),
      updatedAt: Number(thread.updatedAt || 0),
      order: order++
    })
  }

  var locals = Array.isArray(localThreads) ? localThreads : []
  var unread = unreadThreads && typeof unreadThreads === "object"
    ? unreadThreads : ({})
  for (var localIndex = 0; localIndex < locals.length; localIndex++) {
    var local = locals[localIndex]
    if (unread[String(local && local.id || "")] === true)
      append(local, null, "codex", "local")
  }

  var hosts = Array.isArray(supplementalHosts) ? supplementalHosts : []
  for (var hostIndex = 0; hostIndex < hosts.length; hostIndex++) {
    var host = hosts[hostIndex] || ({})
    var threads = Array.isArray(host.threads) ? host.threads : []
    for (var threadIndex = 0; threadIndex < threads.length; threadIndex++) {
      var thread = threads[threadIndex]
      if (thread && thread.unread === true)
        append(thread, host, host.providerType || "codex", host.id)
    }
  }

  targets.sort(function(a, b) {
    var timestampDifference = b.updatedAt - a.updatedAt
    return timestampDifference !== 0 ? timestampDifference : a.order - b.order
  })
  return targets
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

function idleThreadLaunchState(sequence, failedThreadId, error) {
  return {
    sequence: Math.max(0, Number(sequence || 0)),
    phase: "idle",
    requestId: 0,
    targetThreadId: "",
    source: "",
    failedThreadId: String(failedThreadId || ""),
    error: String(error || "")
  }
}

function normalizedThreadLaunchState(state) {
  var source = state && typeof state === "object" ? state : ({})
  var phase = String(source.phase || "") === "launching" ? "launching" : "idle"
  return {
    sequence: Math.max(0, Number(source.sequence || 0)),
    phase: phase,
    requestId: phase === "launching" ? Math.max(0, Number(source.requestId || 0)) : 0,
    targetThreadId: phase === "launching" ? String(source.targetThreadId || "") : "",
    source: phase === "launching" ? String(source.source || "") : "",
    failedThreadId: String(source.failedThreadId || ""),
    error: String(source.error || "")
  }
}

function beginThreadLaunch(state, threadId, source) {
  var current = normalizedThreadLaunchState(state)
  var target = String(threadId || "")
  if (target === "")
    return { accepted: false, requestId: 0, state: current,
      error: "A thread is required" }
  if (current.phase === "launching")
    return { accepted: false, requestId: 0, state: current,
      error: "Wait for the current thread launch to finish" }

  var requestId = current.sequence + 1
  return {
    accepted: true,
    requestId: requestId,
    state: {
      sequence: requestId,
      phase: "launching",
      requestId: requestId,
      targetThreadId: target,
      source: String(source || "unknown"),
      failedThreadId: "",
      error: ""
    },
    error: ""
  }
}

function confirmThreadLaunch(state, requestId, threadId) {
  var current = normalizedThreadLaunchState(state)
  var wantedRequest = Number(requestId || 0)
  if (current.phase !== "launching" || current.requestId !== wantedRequest)
    return { applied: false, state: current, threadId: "" }
  var confirmed = String(threadId || current.targetThreadId)
  if (confirmed === "") return failThreadLaunch(
    current, wantedRequest, "The thread launch did not identify a thread")
  return {
    applied: true,
    state: idleThreadLaunchState(current.sequence, "", ""),
    threadId: confirmed
  }
}

function failThreadLaunch(state, requestId, message) {
  var current = normalizedThreadLaunchState(state)
  var wantedRequest = Number(requestId || 0)
  if (current.phase !== "launching" || current.requestId !== wantedRequest)
    return { applied: false, state: current, threadId: "", error: "" }
  var error = String(message || "Could not open the thread").trim()
    || "Could not open the thread"
  return {
    applied: true,
    state: idleThreadLaunchState(
      current.sequence, current.targetThreadId, error),
    threadId: current.targetThreadId,
    error: error
  }
}
