import QtQuick
import QtTest
import "../logic/PanelHelpLogic.js" as PanelHelpLogic

TestCase {
  name: "PanelHelpLogic"

  function entry(items, keys) {
    for (var index = 0; index < items.length; index++)
      if (items[index].keys === keys) return items[index]
    return null
  }

  function test_describesDynamicFrontendFastAndEffortState() {
    var enabled = PanelHelpLogic.items("agent-chat", true, "high")
    verify(entry(enabled, "Super+Ctrl+A").description.indexOf("Agent Chat is on") >= 0)
    verify(entry(enabled, "Super+Ctrl+F").description.indexOf("Fast is on") >= 0)
    verify(entry(enabled, "Super+Ctrl+E").description.indexOf("high") >= 0)

    var disabled = PanelHelpLogic.items("terminal", false, "")
    verify(entry(disabled, "Super+Ctrl+A").description.indexOf("off (terminal)") >= 0)
    verify(entry(disabled, "Super+Ctrl+F").description.indexOf("Fast is off") >= 0)
    verify(entry(disabled, "Super+Ctrl+E").description.indexOf("default") >= 0)
  }

  function test_keepsCoreNavigationDiscoverable() {
    var items = PanelHelpLogic.items("terminal", false, "medium")
    verify(entry(items, "Enter / o") !== null)
    verify(entry(items, "/") !== null)
    verify(entry(items, "Esc / q") !== null)
  }
}
