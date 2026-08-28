import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import "../logic" as Logic

Item {
  id: root

  property alias entries: cache.entries
  property var compositor: Hyprland
  property var toplevelManager: ToplevelManager

  Logic.ThreadLaunchCache { id: cache }

  function entryKey(sessionId, hostId) { return cache.entryKey(sessionId, hostId) }
  function parseOutput(output) { return cache.parseOutput(output) }
  function map(sessionId, address, hostId, serverUrl) {
    return cache.map(sessionId, address, hostId, serverUrl)
  }
  function forget(sessionId, hostId) { cache.forget(sessionId, hostId) }

  function liveAddresses() {
    var addresses = []
    var values = toplevelManager && toplevelManager.toplevels
      ? toplevelManager.toplevels.values : []
    for (var i = 0; i < values.length; i++) {
      var toplevel = values[i]
      var hyprland = toplevel ? toplevel.HyprlandToplevel : null
      if (!hyprland) continue
      var address = String(hyprland.address || "")
      if (address !== "" && address.toLowerCase().indexOf("0x") !== 0)
        address = "0x" + address
      if (address !== "") addresses.push(address)
    }
    return addresses
  }

  function focusCachedThread(sessionId, hostId) {
    var entry = cache.liveEntry(sessionId, hostId, liveAddresses())
    if (!entry) return false
    var address = String(entry.address || "")
    try {
      if (compositor.usingLua)
        compositor.dispatch("hl.dsp.focus({ window = 'address:" + address + "' })")
      else compositor.dispatch("focuswindow address:" + address)
    } catch (error) {
      forget(sessionId, hostId)
      return false
    }
    return true
  }

  function serverUrl(sessionId, hostId) {
    return cache.serverUrl(sessionId, hostId)
  }

}
