import QtQuick
import QtTest
import "../logic/SidebarPreferencesLogic.js" as PreferencesLogic

TestCase {
  id: testCase
  name: "SidebarPreferences"

  function test_preservesVisibilityWhenChangingScope() {
    var opened = PreferencesLogic.setWorkspaceOpen(
      "workspace", false, {}, "3", true)
    verify(PreferencesLogic.workspaceOpen(
      "workspace", opened.globalOpen, opened.openWorkspaces, "3"))
    var global = PreferencesLogic.changeScope(
      "workspace", opened.globalOpen, opened.openWorkspaces, "global", "3")
    compare(global.scope, "global")
    verify(global.globalOpen)
    var workspace = PreferencesLogic.changeScope(
      global.scope, global.globalOpen, global.openWorkspaces, "workspace", "3")
    compare(workspace.scope, "workspace")
    verify(PreferencesLogic.workspaceOpen(
      workspace.scope, workspace.globalOpen, workspace.openWorkspaces, "3"))
  }

  function test_validatesProvider() {
    compare(PreferencesLogic.provider("CLAUDE", "codex"), "claude")
    compare(PreferencesLogic.provider("invalid", "opencode"), "opencode")
  }

  function test_copiesCollectionState() {
    var source = { project: true }
    var copied = PreferencesLogic.map(source)
    source.project = false
    verify(copied.project)
    compare(Object.keys(PreferencesLogic.map([])).length, 0)
  }
}
