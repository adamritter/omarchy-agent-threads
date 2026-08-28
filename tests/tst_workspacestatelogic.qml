import QtQuick
import QtTest
import "../logic/WorkspaceStateLogic.js" as WorkspaceStateLogic

TestCase {
  name: "WorkspaceStateLogic"

  readonly property var normalWorkspace: {
    "id": 1, "name": "1", "monitorID": 0, "hasfullscreen": false
  }
  readonly property var specialWorkspace: {
    "id": -98, "name": "special:scratchpad", "monitorID": 0,
    "hasfullscreen": true
  }

  function monitor(special) {
    return {
      id: 0, x: 0, y: 0, width: 1600, height: 900, scale: 1,
      specialWorkspace: special || { id: 0, name: "" }
    }
  }

  function test_derivesNormalAndSpecialWorkspace() {
    var normal = WorkspaceStateLogic.derive(
      normalWorkspace, monitor(null), [normalWorkspace, specialWorkspace], [])
    compare(normal.workspaceId, 1)
    compare(normal.workspaceKey, "1")
    compare(normal.workspaceName, "1")
    verify(!normal.specialWorkspace)
    verify(!normal.hasfullscreen)

    var special = WorkspaceStateLogic.derive(normalWorkspace, monitor({
      id: -98, name: "special:scratchpad"
    }), [normalWorkspace, specialWorkspace], [])
    compare(special.workspaceId, -98)
    compare(special.workspaceKey, "special:scratchpad")
    compare(special.workspaceName, "special:scratchpad")
    verify(special.specialWorkspace)
    verify(special.nativeFullscreen)
    verify(special.hasfullscreen)
  }

  function test_detectsGeometryFullscreenAtLogicalMonitorSize() {
    var state = WorkspaceStateLogic.derive(normalWorkspace, {
      id: 2, x: 1920, y: 100, width: 3000, height: 1800, scale: 2,
      specialWorkspace: { id: 0 }
    }, [normalWorkspace], [{
      workspace: { id: 1 }, monitor: 2, floating: true,
      at: [1922, 102], size: [1497, 897]
    }])
    verify(state.geometryFullscreen)
    verify(state.hasfullscreen)
  }

  function test_ignoresClientsOnAnotherWorkspaceOrMonitor() {
    var clients = [{
      workspace: { id: 2 }, monitor: 0, floating: true,
      at: [0, 0], size: [1600, 900]
    }, {
      workspace: { id: 1 }, monitor: 1, floating: true,
      at: [0, 0], size: [1600, 900]
    }]
    var state = WorkspaceStateLogic.derive(
      normalWorkspace, monitor(null), [normalWorkspace], clients)
    verify(!state.geometryFullscreen)
    verify(!state.hasfullscreen)
  }
}
