import QtQuick
import QtTest
import "../logic/PanelFocusLogic.js" as PanelFocusLogic

TestCase {
  name: "PanelFocusLogic"

  function test_calculatesSummonPointInsidePanelSurface() {
    var point = PanelFocusLogic.summonPoint(
      { x: 1920, y: 100 }, { top: 8 }, "top", 32, { x: 150, y: 2 }, 200)
    compare(point.x, 2070)
    compare(point.y, 142)

    var bottomBar = PanelFocusLogic.summonPoint(
      { x: 0, y: 0 }, { top: 4 }, "bottom", 32, {}, 200)
    compare(bottomBar.x, 200)
    compare(bottomBar.y, 5)
  }

  function test_normalizesFullscreenWorkspaceTransition() {
    var state = PanelFocusLogic.fullscreenState(JSON.stringify({
      workspaceId: 3,
      workspaceKey: "special:dev",
      hasfullscreen: true,
      geometryFullscreen: true
    }), "2", "2")
    verify(state.valid)
    verify(state.workspaceChanged)
    verify(state.cancelReloadFocus)
    verify(state.workspaceFullscreen)
    verify(state.geometryFullscreen)
    compare(state.internalState, 2)
  }

  function test_preservesReloadFocusWhenFirstProbeMatchesSnapshot() {
    var state = PanelFocusLogic.fullscreenState(
      { workspaceId: 3, hasfullscreen: false }, "", "3")
    verify(state.valid)
    verify(state.workspaceChanged)
    verify(!state.cancelReloadFocus)
    compare(state.workspaceKey, "3")
    compare(state.internalState, 0)
  }

  function test_rejectsMalformedProbeOutput() {
    verify(!PanelFocusLogic.fullscreenState("not-json", "1", "1").valid)
    verify(!PanelFocusLogic.fullscreenState(null, "1", "1").valid)
  }
}
