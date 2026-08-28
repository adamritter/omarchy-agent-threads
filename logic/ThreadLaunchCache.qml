import QtQuick

Item {
  property var entries: ({})

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
