import QtQuick
import QtTest
import "../logic/PanelReloadStateLogic.js" as PanelReloadStateLogic

TestCase {
  name: "PanelReloadStateLogic"

  function sampleState() {
    return {
      selectedRowKey: "thread:local:abc",
      keyboardFocusRequested: true,
      focusTarget: "search",
      searchText: "demo",
      searchOpen: true,
      expandedGroups: { "project:local:/tmp/demo": true },
      cursorReturnX: 0,
      cursorReturnY: 456
    }
  }

  function test_roundTripsCurrentProcessState() {
    var encoded = PanelReloadStateLogic.encode(sampleState(), 42, "shell-a", 1000)
    var decoded = PanelReloadStateLogic.decode(encoded, 42, "shell-a", 1200, 5000)

    verify(decoded !== null)
    compare(decoded.selectedRowKey, "thread:local:abc")
    compare(decoded.keyboardFocusRequested, true)
    compare(decoded.focusTarget, "search")
    compare(decoded.searchText, "demo")
    compare(decoded.searchOpen, true)
    compare(decoded.expandedGroups["project:local:/tmp/demo"], true)
    compare(decoded.cursorReturnX, 0)
    compare(decoded.cursorReturnY, 456)
  }

  function test_rejectsRestartAndStaleState() {
    var encoded = PanelReloadStateLogic.encode(sampleState(), 42, "shell-a", 1000)

    compare(PanelReloadStateLogic.decode(encoded, 43, "shell-a", 1200, 5000), null)
    compare(PanelReloadStateLogic.decode(encoded, 42, "shell-b", 1200, 5000), null)
    compare(PanelReloadStateLogic.decode(encoded, 42, "shell-a", 7000, 5000), null)
  }

  function test_normalizesOptionalState() {
    var encoded = PanelReloadStateLogic.encode({
      focusTarget: "rename",
      expandedGroups: []
    }, 42, "shell-a", 1000)
    var decoded = PanelReloadStateLogic.decode(encoded, 42, "shell-a", 1000, 5000)

    verify(decoded !== null)
    compare(decoded.focusTarget, "list")
    compare(JSON.stringify(decoded.expandedGroups), "{}")
  }
}
