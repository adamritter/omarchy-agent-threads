// Purpose: Hosts thread-launch focus behavior in a controlled test environment.
import QtQuick
import Quickshell
import qs.AgentThreads.providers as Providers

ShellRoot {
  id: root
  property bool failed: false

  QtObject {
    id: compositor
    property bool usingLua: true
    property bool throwOnDispatch: false
    property string lastCommand: ""
    function dispatch(command) {
      if (throwOnDispatch) throw new Error("dispatch failed")
      lastCommand = String(command || "")
    }
  }

  QtObject {
    id: toplevelManager
    property var toplevels: ({ values: [] })
  }

  Providers.ThreadLaunchCoordinator {
    id: coordinator
    compositor: compositor
    toplevelManager: toplevelManager
  }

  function check(condition, message) {
    if (condition) return true
    failed = true
    console.warn("THREAD_LAUNCH_FOCUS_FAIL: " + message)
    return false
  }

  Component.onCompleted: {
    toplevelManager.toplevels = { values: [
      { HyprlandToplevel: { address: "AbC123" } }
    ] }
    check(coordinator.map("live", "0xabc123", "host-a", ""),
      "live mapping was rejected")
    check(coordinator.focusCachedThread("live", "host-a"),
      "live mapping did not focus")
    check(compositor.lastCommand.indexOf("address:0xabc123") >= 0,
      "focus dispatch targeted the wrong address")

    check(coordinator.map("stale", "0xdead", "host-a", ""),
      "stale fixture mapping was rejected")
    check(!coordinator.focusCachedThread("stale", "host-a"),
      "stale mapping unexpectedly focused")
    check(coordinator.entries[coordinator.entryKey("stale", "host-a")]
      === undefined, "stale mapping was not evicted")

    check(coordinator.map("failed", "0xabc123", "host-a", ""),
      "dispatch-failure fixture mapping was rejected")
    compositor.throwOnDispatch = true
    check(!coordinator.focusCachedThread("failed", "host-a"),
      "failed dispatch unexpectedly succeeded")
    check(coordinator.entries[coordinator.entryKey("failed", "host-a")]
      === undefined, "failed dispatch mapping was not evicted")

    if (!failed) console.info("THREAD_LAUNCH_FOCUS_PASS")
    Qt.callLater(Qt.quit)
  }
}
