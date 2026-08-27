.pragma library

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

function notificationThreadTitle(thread) {
  var name = String(thread && thread.name || "").replace(/\s+/g, " ").trim()
  if (name !== "") return name
  var preview = String(thread && thread.preview || "").replace(/\s+/g, " ").trim()
  return preview !== "" ? preview : "Untitled agent thread"
}

function statusMap(threads) {
  var result = ({})
  var items = Array.isArray(threads) ? threads : []
  for (var i = 0; i < items.length; i++) {
    var thread = items[i]
    var id = String(thread && thread.id || "")
    if (id !== "") result[id] = remoteStatusValue(thread.status)
  }
  return result
}

function notificationStateSnapshot(localThreads, localStatuses, unreadThreads, hosts) {
  var states = ({})
  var locals = Array.isArray(localThreads) ? localThreads : []
  var statuses = localStatuses && typeof localStatuses === "object"
    ? localStatuses : ({})
  var unread = unreadThreads && typeof unreadThreads === "object"
    ? unreadThreads : ({})
  for (var localIndex = 0; localIndex < locals.length; localIndex++) {
    var localThread = locals[localIndex]
    var localId = String(localThread && localThread.id || "")
    if (localId === "") continue
    states["local:" + localId] = {
      status: String(statuses[localId] || "done"),
      ready: unread[localId] === true,
      title: notificationThreadTitle(localThread)
    }
  }

  var remoteHosts = Array.isArray(hosts) ? hosts : []
  for (var hostIndex = 0; hostIndex < remoteHosts.length; hostIndex++) {
    var host = remoteHosts[hostIndex] || ({})
    var threads = Array.isArray(host.threads) ? host.threads : []
    for (var threadIndex = 0; threadIndex < threads.length; threadIndex++) {
      var thread = threads[threadIndex]
      var id = String(thread && thread.id || "")
      if (id === "") continue
      states[String(host.id || "remote") + ":" + id] = {
        status: remoteStatusValue(thread.status),
        ready: thread.unread === true,
        title: notificationThreadTitle(thread)
      }
    }
  }
  return states
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
