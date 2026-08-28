// Purpose: Provides a controlled Panel Reload Boundary Probe harness for behavioral tests.
import QtQuick

QtObject {
  id: root

  required property var harness
  property var panel: null
  property var firstView: null
  property var firstContent: null
  property string instanceToken: ""

  function start(target) {
    panel = target
    if (!harness.check(panel.sidebarView.threadList !== null,
      "list ownership missing")) return
    if (!harness.check(panel.sidebarActions.listView === panel.sidebarView.threadList,
      "controller list mismatch")) return
    if (!harness.check(typeof panel.sidebarItemFocused === "boolean",
      "focus ownership missing")) return
    firstView = panel.sidebarView
    firstContent = panel.sidebarView.content
    instanceToken = panel.session.instanceToken
    panel.session.searchText = "Beta"
    panel.selectedIndex = 2
    if (!harness.check(panel.reloadEntryPoint("sidebarContent"),
      "content reload was not accepted")) return
    Qt.callLater(root.checkContentReload)
  }

  function checkContentReload() {
    if (!harness.check(panel.sidebarReload.contentRevision === 1,
      "content revision did not advance")) return
    if (!harness.check(panel.sidebarView === firstView,
      "content reload replaced the outer sidebar")) return
    if (!harness.check(panel.sidebarView.content !== firstContent,
      "content reload kept the old content instance")) return
    if (!harness.check(panel.session.searchText === "Beta" && panel.selectedIndex === 2,
      "content reload lost stable panel state")) return
    firstView = panel.sidebarView
    if (!harness.check(panel.reloadEntryPoint("sidebar"),
      "sidebar reload was not accepted")) return
    Qt.callLater(root.checkSidebarReload)
  }

  function checkSidebarReload() {
    if (!harness.check(panel.sidebarReload.sidebarRevision === 1,
      "sidebar revision did not advance")) return
    if (!harness.check(panel.sidebarView !== firstView,
      "sidebar reload kept the old sidebar instance")) return
    if (!harness.check(panel.session.instanceToken === instanceToken,
      "sidebar reload replaced the stable Panel instance")) return
    if (!harness.check(panel.sidebarActions.listView === panel.sidebarView.threadList,
      "controller did not follow the reloaded list")) return
    if (!harness.check(panel.session.searchText === "Beta" && panel.selectedIndex === 2,
      "sidebar reload lost stable panel state")) return
    console.log("PANEL_COMPONENT_PASS:hidden graph and reload boundary instantiated")
    panel.destroy()
    panel = null
    harness.panelInstance = null
    Qt.quit()
  }
}
