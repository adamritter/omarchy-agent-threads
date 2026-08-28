import QtQuick
import QtTest
import "../logic" as Logic

TestCase {
  name: "ThreadLaunchCache"

  Logic.ThreadLaunchCache { id: coordinator }

  function init() {
    coordinator.entries = ({})
    coordinator.clearOpen()
    coordinator.clearPending()
  }

  function test_mapsWindowInMemory() {
    verify(coordinator.map(
      "session.v1", "0xAbC123", "local-opencode", "http://127.0.0.1:43123"))
    compare(coordinator.serverUrl("session.v1", "local-opencode"),
      "http://127.0.0.1:43123")
    compare(coordinator.entry("session.v1", "local-opencode").address, "0xAbC123")
  }

  function test_scopesSameSessionToHost() {
    verify(coordinator.map("shared", "0x1", "host-a", ""))
    verify(coordinator.map("shared", "0x2", "host-b", ""))
    compare(coordinator.entry("shared", "host-b").address, "0x2")
  }

  function test_forgetRemovesOnlyRequestedEntry() {
    verify(coordinator.map("closed", "0xdead", "", ""))
    coordinator.forget("closed", "")
    compare(coordinator.entries[coordinator.entryKey("closed", "")], undefined)
  }

  function test_liveEntryKeepsVerifiedWindowAndEvictsStaleMapping() {
    verify(coordinator.map("live", "0xAbC123", "host-a", ""))
    var entry = coordinator.liveEntry(
      "live", "host-a", ["0xother", "0xabc123"])
    verify(entry !== null)
    compare(entry.address, "0xAbC123")

    compare(coordinator.liveEntry("live", "host-a", ["0xother"]), null)
    compare(coordinator.entry("live", "host-a"), null)
  }

  function test_rejectsUntrustedMappingValues() {
    verify(!coordinator.map("", "0x1", "", ""))
    verify(!coordinator.map("session", "../../victim", "", ""))
    verify(!coordinator.map("session", "0x1", "", "http://example.com:1234"))
    verify(!coordinator.map("session", "0x1", "", "http://127.0.0.1:99999"))
    verify(coordinator.map("session", "0x1", "", "http://localhost:65535"))
  }

  function test_tracksOneOpenRequest() {
    coordinator.trackOpen(73, "thread-a", "remote-a")
    compare(coordinator.openRequestId, 73)
    compare(coordinator.openThreadId, "thread-a")
    compare(coordinator.openHostId, "remote-a")
    coordinator.clearOpen()
    compare(coordinator.openRequestId, 0)
    compare(coordinator.openThreadId, "")
    compare(coordinator.openHostId, "")
  }

  function test_discoversPendingThreadWithoutSelectingKnownThreads() {
    coordinator.beginPending(
      [{ id: "known" }], "/work/project", "remote-a", 2)
    verify(coordinator.pending)
    compare(coordinator.pendingHostId, "remote-a")
    compare(coordinator.discoverPendingThread([
      { id: "known", cwd: "/work/project" },
      { id: "wrong", cwd: "/work/other" },
      { id: "new", directory: "/work/project" }
    ], function(thread) { return thread.directory }), "new")
    compare(coordinator.pendingThreadId, "new")

    coordinator.recordPendingOutput(
      "0xabc", "", "http://127.0.0.1:43123")
    compare(coordinator.pendingWindowAddress, "0xabc")
    compare(coordinator.pendingServerUrl, "http://127.0.0.1:43123")
  }

  function test_boundsPendingRetriesAndClearsState() {
    coordinator.beginPending([], "/work", "", 1)
    compare(coordinator.tickPending(), 0)
    compare(coordinator.tickPending(), 0)
    coordinator.clearPending()
    verify(!coordinator.pending)
    compare(coordinator.pendingPath, "")
  }

}
