import QtQuick

Item {
  property var entries: ({})
  property int openRequestId: 0
  property string openThreadId: ""
  property string openHostId: ""
  property var pendingLaunch: idlePending()
  readonly property bool pending: pendingLaunch.active === true
  readonly property string pendingHostId: String(pendingLaunch.hostId || "")
  readonly property string pendingPath: String(pendingLaunch.path || "")
  readonly property string pendingThreadId: String(pendingLaunch.threadId || "")
  readonly property string pendingWindowAddress: String(pendingLaunch.windowAddress || "")
  readonly property string pendingServerUrl: String(pendingLaunch.serverUrl || "")
  readonly property int pendingAttempts: Number(pendingLaunch.attempts || 0)

  function idlePending() {
    return { active: false, hostId: "", path: "", knownIds: ({}),
      threadId: "", windowAddress: "", serverUrl: "", attempts: 0 }
  }

  function trackOpen(requestId, threadId, hostId) {
    openRequestId = Number(requestId || 0)
    openThreadId = String(threadId || "")
    openHostId = String(hostId || "")
  }

  function clearOpen() { trackOpen(0, "", "") }

  function beginPending(threads, path, hostId, attempts) {
    var known = ({})
    var values = Array.isArray(threads) ? threads : []
    for (var i = 0; i < values.length; i++) {
      var id = String(values[i] && values[i].id || "")
      if (id !== "") known[id] = true
    }
    pendingLaunch = { active: true, hostId: String(hostId || ""),
      path: String(path || ""), knownIds: known, threadId: "",
      windowAddress: "", serverUrl: "",
      attempts: Math.max(0, Number(attempts || 0)) }
  }

  function recordPendingOutput(address, sessionId, serverUrl) {
    if (!pending) return
    pendingLaunch = Object.assign({}, pendingLaunch, {
      threadId: String(sessionId || pendingThreadId),
      windowAddress: String(address || ""), serverUrl: String(serverUrl || "") })
  }

  function discoverPendingThread(threads, pathForThread) {
    if (!pending || pendingThreadId !== "") return pendingThreadId
    var values = Array.isArray(threads) ? threads : []
    for (var i = 0; i < values.length; i++) {
      var thread = values[i]
      var id = String(thread && thread.id || "")
      if (id === "" || pendingLaunch.knownIds[id] === true) continue
      var path = typeof pathForThread === "function"
        ? String(pathForThread(thread) || "") : String(thread && thread.cwd || "")
      if (path !== pendingPath && String(thread && thread.cwd || "") !== pendingPath)
        continue
      pendingLaunch = Object.assign({}, pendingLaunch, { threadId: id })
      return id
    }
    return ""
  }

  function tickPending() {
    if (pending) pendingLaunch = Object.assign({}, pendingLaunch,
      { attempts: Math.max(0, pendingAttempts - 1) })
    return pendingAttempts
  }

  function clearPending() { pendingLaunch = idlePending() }

  function entryKey(sessionId, hostId) {
    return String(hostId || "") + "\u001f" + String(sessionId || "")
  }

  function parseOutput(output) {
    var text = String(output || "").trim()
    var result = { address: text, serverUrl: "", sessionId: "" }
    try {
      var parsed = JSON.parse(text)
      result.address = String(parsed.address || "")
      result.serverUrl = String(parsed.serverUrl || "")
      result.sessionId = String(parsed.sessionId || "")
    } catch (error) {
      // Backward compatibility with helpers that returned only an address.
    }
    return result
  }

  function map(sessionId, address, hostId, serverUrl) {
    var id = String(sessionId || "")
    var windowAddress = String(address || "")
    if (id === "" || !/^0x[0-9a-fA-F]{1,32}$/.test(windowAddress)) return false
    var server = String(serverUrl || "")
    if (server !== "") {
      var match = server.match(/^http:\/\/(127\.0\.0\.1|localhost):([0-9]{1,5})$/)
      if (!match || Number(match[2]) < 1 || Number(match[2]) > 65535) return false
    }
    var next = Object.assign({}, entries)
    next[entryKey(id, hostId)] = { address: windowAddress, serverUrl: server }
    entries = next
    return true
  }

  function entry(sessionId, hostId) {
    return entries[entryKey(sessionId, hostId)] || null
  }

  function liveEntry(sessionId, hostId, liveAddresses) {
    var value = entry(sessionId, hostId)
    if (!value) return null
    var wanted = String(value.address || "").toLowerCase()
    var addresses = Array.isArray(liveAddresses) ? liveAddresses : []
    for (var i = 0; i < addresses.length; i++) {
      if (String(addresses[i] || "").toLowerCase() === wanted) return value
    }
    forget(sessionId, hostId)
    return null
  }

  function forget(sessionId, hostId) {
    var key = entryKey(sessionId, hostId)
    if (entries[key] === undefined) return
    var next = Object.assign({}, entries)
    delete next[key]
    entries = next
  }

  function serverUrl(sessionId, hostId) {
    var value = entry(sessionId, hostId)
    return String(value && value.serverUrl || "")
  }
}
