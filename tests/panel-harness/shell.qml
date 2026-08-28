import QtQuick
import Quickshell
import qs.AgentThreads as AgentThreads

ShellRoot {
  id: testRoot

  property var panelInstance: null
  property int phase: 0
  property bool failed: false
  readonly property bool liveLayerChecks:
    Quickshell.env("AGENT_THREADS_PANEL_TEST_LIVE") === "1"
  readonly property bool compileOnly:
    Quickshell.env("AGENT_THREADS_PANEL_TEST_COMPILE_ONLY") === "1"
  property int firstMainLayerCount: 0

  FakePanelService { id: fakeService }

  Component {
    id: panelComponent

    AgentThreads.Panel {
      service: fakeService
      layerNamespace: "agent-threads-panel-test"
      layerMappingEnabled: !testRoot.compileOnly
      fullscreenSuppressionEnabled: false
    }
  }

  function abort(message) {
    if (failed) return
    failed = true
    console.error("PANEL_RENDER_FAIL:" + message)
    if (panelInstance) panelInstance.destroy()
    panelInstance = null
    Qt.quit()
  }

  function check(condition, message) {
    if (!condition) abort(message)
    return condition
  }

  function createPanel() {
    panelInstance = panelComponent.createObject(testRoot)
    if (!check(panelInstance !== null, "panel creation failed")) return
    if (compileOnly) {
      Qt.callLater(function() { reloadBoundaryProbe.start(panelInstance) })
      return
    }
    panelInstance.open()
  }

  function primaryTexts(snapshot) {
    return snapshot.renderedRows.map(function(row) { return row.primaryText })
  }

  function probeLayers(purpose) {
    if (!liveLayerChecks) {
      abort("live layer probe was requested in offscreen mode")
      return
    }
    layerProbe.purpose = purpose
    layerProbe.running = true
  }

  function finishSuccessfully() {
    console.log("PANEL_RENDER_PASS:render and lifecycle contract verified")
    Qt.quit()
  }

  PanelLayerProbe {
    id: layerProbe
    harness: testRoot
  }

  PanelReloadBoundaryProbe {
    id: reloadBoundaryProbe
    harness: testRoot
  }

  Timer {
    interval: 250
    repeat: true
    running: true

    onTriggered: {
      if (testRoot.failed) return
      if (testRoot.phase === 3) {
        testRoot.createPanel()
        testRoot.phase++
        return
      }
      if (!testRoot.panelInstance) return
      var snapshot = testRoot.panelInstance.listActions.renderSnapshot()

      if (testRoot.phase === 0) {
        if (!testRoot.check(snapshot.opened, "panel did not open")) return
        if (!testRoot.check(snapshot.sidebarPresented, "sidebar was not presented")) return
        if (!testRoot.check(snapshot.panelVisible,
          "owned layer-shell window was not visible")) return
        if (!testRoot.check(snapshot.headerText === "CODEX  ▾",
          "unexpected header: " + snapshot.headerText)) return
        if (!testRoot.check(snapshot.statusText === "1 projects · 3 threads · newest first",
          "unexpected status: " + snapshot.statusText)) return
        if (!testRoot.check(snapshot.modelRowCount === 4,
          "expected four model rows, got " + snapshot.modelRowCount)) return
        if (!testRoot.check(snapshot.renderedRows.length === 4,
          "expected four rendered delegates, got " + snapshot.renderedRows.length)) return
        var initialTexts = testRoot.primaryTexts(snapshot)
        if (!testRoot.check(JSON.stringify(initialTexts)
            === JSON.stringify(["Home thread", "demo  ·  2", "Alpha", "Beta"]),
          "unexpected rendered rows: " + JSON.stringify(initialTexts))) return

        testRoot.panelInstance.selectedIndex = 0
        testRoot.panelInstance.listActions.dispatchTestInput("move", 0, 1)
        if (!testRoot.check(testRoot.panelInstance.selectedIndex === 1,
          "down movement did not select the project row")) return
        testRoot.panelInstance.listActions.dispatchTestInput("move", -1, 0)
        if (!testRoot.check(testRoot.panelInstance.viewRows.length === 2,
          "left movement did not collapse the selected project")) return
        testRoot.panelInstance.listActions.dispatchTestInput("move", 1, 0)
        if (!testRoot.check(testRoot.panelInstance.viewRows.length === 4,
          "right movement did not expand the selected project")) return
        testRoot.panelInstance.listActions.dispatchTestInput("move", 0, -1)
        if (!testRoot.check(testRoot.panelInstance.selectedIndex === 0,
          "up movement did not restore the first row")) return

        testRoot.panelInstance.listActions.dispatchTestInput("text", "?")
        if (!testRoot.check(testRoot.panelInstance.session.helpOpen,
          "help key did not open help")) return
        testRoot.panelInstance.listActions.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.session.helpOpen,
          "close input did not close help")) return
        testRoot.panelInstance.listActions.dispatchTestInput("frontend")
        if (!testRoot.check(fakeService.threadFrontend === "agent-chat",
          "the guarded shortcut did not enable the Agent Chat thread opener")) return
        if (!testRoot.check(testRoot.panelInstance.helpItems[13].description
            === "Toggle how Codex threads open · Agent Chat is on",
          "help did not show the enabled Agent Chat state")) return
        testRoot.panelInstance.listActions.dispatchTestInput("frontend")
        if (!testRoot.check(fakeService.threadFrontend === "terminal",
          "the guarded shortcut did not restore the terminal thread opener")) return
        if (!testRoot.check(testRoot.panelInstance.helpItems[13].description
            === "Toggle how Codex threads open · Agent Chat is off (terminal)",
          "help did not show the disabled Agent Chat state")) return
        testRoot.panelInstance.listActions.dispatchTestInput("text", "/")
        if (!testRoot.check(testRoot.panelInstance.session.searchOpen,
          "search key did not open search")) return
        testRoot.panelInstance.listActions.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.session.searchOpen,
          "close input did not close search")) return

        testRoot.panelInstance.listActions.dispatchTestInput("activate")
        testRoot.panelInstance.listActions.dispatchTestInput("text", "n")
        testRoot.panelInstance.listActions.dispatchTestInput("text", "p")
        testRoot.panelInstance.listActions.dispatchTestInput("text", "y")
        if (!testRoot.check(fakeService.openedThreadCount === 1,
          "activate did not open the selected thread")) return
        if (!testRoot.check(fakeService.newProjectThreadCount === 1,
          "n did not create a thread in the selected directory")) return
        if (!testRoot.check(fakeService.pinnedThreadCount === 1,
          "p did not pin the selected thread")) return
        if (!testRoot.check(fakeService.archivedThreadCount === 1,
          "y did not archive the selected thread")) return
        testRoot.panelInstance.listActions.dispatchTestInput("text", "r")
        if (!testRoot.check(testRoot.panelInstance.session.renameOpen,
          "r did not open rename")) return
        testRoot.panelInstance.listActions.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.session.renameOpen,
          "close input did not close rename")) return

        if (testRoot.liveLayerChecks) {
          testRoot.phase = 10
          testRoot.probeLayers("first-visible")
        } else {
          testRoot.panelInstance.overlayActions.setSearchText("Beta")
          testRoot.phase = 1
        }
        return
      }

      if (testRoot.phase === 1) {
        if (!testRoot.check(snapshot.searchVisible, "search field was not rendered")) return
        if (!testRoot.check(snapshot.statusText === "1 projects · 1 of 3 threads · newest first",
          "unexpected filtered status: " + snapshot.statusText)) return
        var filteredTexts = testRoot.primaryTexts(snapshot)
        if (!testRoot.check(JSON.stringify(filteredTexts)
            === JSON.stringify(["demo  ·  1", "Beta"]),
          "unexpected filtered rows: " + JSON.stringify(filteredTexts))) return
        testRoot.panelInstance.overlayActions.setSearchText("")
        testRoot.panelInstance.session.helpOpen = true
        testRoot.phase++
        return
      }

      if (testRoot.phase === 2) {
        if (!testRoot.check(snapshot.helpVisible && !snapshot.listVisible,
          "help overlay did not replace the thread list")) return
        if (!testRoot.check(snapshot.headerText === "CODEX · HELP",
          "unexpected help header: " + snapshot.headerText)) return
        testRoot.panelInstance.close()
        testRoot.panelInstance.destroy()
        testRoot.panelInstance = null
        if (testRoot.liveLayerChecks) {
          testRoot.phase = 20
          Qt.callLater(function() { testRoot.probeLayers("first-destroyed") })
        } else testRoot.phase = 3
        return
      }

      if (testRoot.phase === 4) {
        if (!testRoot.check(snapshot.panelVisible,
          "recreated panel did not own its visible window")) return
        if (!testRoot.check(snapshot.renderedRows.length === 4,
          "recreated panel did not render its fake rows")) return
        if (testRoot.liveLayerChecks) {
          testRoot.phase = 30
          testRoot.probeLayers("second-visible")
        } else {
          testRoot.panelInstance.close()
          testRoot.panelInstance.destroy()
          testRoot.panelInstance = null
          testRoot.phase = 40
          Qt.callLater(testRoot.finishSuccessfully)
        }
      }
    }
  }

  Component.onCompleted: createPanel()
}
