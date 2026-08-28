import QtQuick
import QtTest
import "../logic" as Logic

TestCase {
  name: "ThreadLaunchCache"

  Logic.ThreadLaunchCache { id: coordinator }

  function init() {
    coordinator.entries = ({})
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

}
