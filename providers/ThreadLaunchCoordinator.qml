import QtQuick
import Quickshell.Io

Item {
  id: root

  readonly property bool mapping: mapProcess.running
  readonly property string mapThreadWindowHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-map-thread-window").toString().replace(/^file:\/\//, "")

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
    if (id === "" || windowAddress === "" || mapProcess.running) return false
    var command = [mapThreadWindowHelperPath, id, windowAddress]
    var host = String(hostId || "")
    var server = String(serverUrl || "")
    if (host !== "" || server !== "") command.push(host)
    if (server !== "") command.push(server)
    mapProcess.command = command
    mapProcess.running = true
    return true
  }

  Process { id: mapProcess; running: false }
}
