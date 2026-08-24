import QtQuick
import Quickshell
import Quickshell.Io
import qs.AgentThreads as AgentThreads

ShellRoot {
  id: testRoot

  property var panelInstance: null
  property int phase: 0
  property bool failed: false
  readonly property bool liveLayerChecks:
    Quickshell.env("AGENT_THREADS_PANEL_TEST_LIVE") === "1"
  property int firstMainLayerCount: 0
  property int firstReservationLayerCount: 0

  QtObject {
    id: fakeService

    property string selectedProvider: "codex"
    property var threads: [
      { id: "home", name: "Home thread", cwd: Quickshell.env("HOME"), updatedAt: 30 },
      { id: "alpha", name: "Alpha", cwd: "/work/demo", updatedAt: 20 },
      { id: "beta", name: "Beta", cwd: "/work/demo", updatedAt: 10 }
    ]
    property var projects: []
    property var remoteHosts: []
    property var collapsedProjects: ({ "local:/work/demo": false })
    property var collapsedRemotes: ({})
    property var pinnedSections: ({})
    property var sshHosts: []
    property string sshHostsError: ""
    property bool sshHostsLoading: false
    property bool ready: true
    property bool loading: false
    property string errorText: ""
    property string launchError: ""
    property string launchingThreadId: ""
    property string launchingProjectPath: ""
    property string archivingThreadId: ""
    property string pinningThreadId: ""
    property string renamingThreadId: ""
    property string movingThreadId: ""
    property string remoteActionHostId: ""
    property string activeThreadId: "beta"
    property string remoteAddError: ""
    property string remoteClaudeInstallHostId: ""
    property bool remoteClaudeInstallRunning: false
    property string remoteClaudeLoginHostId: ""
    property bool remoteClaudeLoginRunning: false
    property string remoteTestHostId: ""
    property bool remoteTestRunning: false
    property bool remoteTestSucceeded: false
    property string remoteTestMessage: ""
    property var rateLimits: ({})
    property var rateLimitResetCredits: ({ availableCount: 0 })
    property bool sidebarSettingsLoaded: false
    property bool sidebarOpen: false
    property string sidebarScope: "global"
    property int openedThreadCount: 0
    property int newProjectThreadCount: 0
    property int pinnedThreadCount: 0
    property int archivedThreadCount: 0
    property int openedTerminalCount: 0

    function projectPathForThread(thread) { return String(thread && thread.cwd || "") }
    function projectRootPath(project) { return String(project && project.path || "") }
    function remotePathForThread(host, thread) { return String(thread && thread.cwd || "") }
    function remoteThreadStatus(thread) { return String(thread && thread.status || "done") }
    function threadStatus(threadId) { return threadId === "alpha" ? "busy" : "done" }
    function threadUnread(threadId) { return false }
    function modelsForProvider(provider) { return [] }
    function agentsForProvider(provider) { return [] }
    function modelEffortsForProvider(provider, model) { return [] }
    function selectedModelForProvider(provider) { return "" }
    function selectedEffortForProvider(provider) { return "" }
    function selectedAgentForProvider(provider) { return "" }
    function defaultModelForProvider(provider) { return "" }
    function defaultEffortForProvider(provider) { return "" }
    function effectiveModel() { return "gpt-test" }
    function effectiveEffort() { return "medium" }
    function effectiveModelForProvider(provider) { return "gpt-test" }
    function effectiveEffortForProvider(provider) { return "medium" }
    function effectiveAgentForProvider(provider) { return "" }
    function sidebarOpenOnWorkspace(workspaceId) { return false }
    function migrateSidebarOpenState(workspaceId) {}
    function refreshThreads() {}
    function refreshActiveThread() {}
    function refreshRemotes(remoteId) {}
    function refreshSshHosts() {}
    function setCollapsedProjects(value) { collapsedProjects = value }
    function setCollapsedRemotes(value) { collapsedRemotes = value }
    function setPinnedSections(value) { pinnedSections = value }
    function setSelectedProvider(value) { selectedProvider = value }
    function setSidebarOpenOnWorkspace(workspaceId, opened) {}
    function setSidebarScope(scope, workspaceId, opened) { sidebarScope = scope }
    function openThread(thread, path) { openedThreadCount++ }
    function newProjectThread(path) { newProjectThreadCount++ }
    function toggleThreadPin(thread) { pinnedThreadCount++ }
    function archiveThread(thread) { archivedThreadCount++ }
    function openTerminal(mode, endpoint, path) { openedTerminalCount++; return true }
  }

  Component {
    id: panelComponent

    AgentThreads.Panel {
      service: fakeService
      layerNamespace: "agent-threads-panel-test"
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
    if (!check(panelInstance !== null, "Panel.qml could not be instantiated")) return
    panelInstance.open()
  }

  function primaryTexts(snapshot) {
    return snapshot.renderedRows.map(function(row) { return row.primaryText })
  }

  function collectLayerNamespaces(value, result) {
    if (Array.isArray(value)) {
      for (var arrayIndex = 0; arrayIndex < value.length; arrayIndex++)
        collectLayerNamespaces(value[arrayIndex], result)
      return
    }
    if (!value || typeof value !== "object") return
    if (value.namespace !== undefined) result.push(String(value.namespace || ""))
    for (var key in value) collectLayerNamespaces(value[key], result)
  }

  function layerCounts(text) {
    var parsed
    try { parsed = JSON.parse(String(text || "{}")) }
    catch (error) { return { valid: false, main: 0, reservation: 0 } }
    var namespaces = []
    collectLayerNamespaces(parsed, namespaces)
    var main = 0
    var reservation = 0
    for (var index = 0; index < namespaces.length; index++) {
      if (namespaces[index] === "agent-threads-panel-test") main++
      else if (namespaces[index] === "agent-threads-panel-test-reservation") reservation++
    }
    return { valid: true, main: main, reservation: reservation }
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

  function handleLayerProbe(text) {
    var counts = layerCounts(text)
    if (!check(counts.valid, "hyprctl returned invalid layer JSON")) return

    if (layerProbe.purpose === "first-visible") {
      if (!check(counts.main > 0 && counts.reservation > 0,
        "the first panel did not map both layer roles")) return
      if (!check(counts.main === counts.reservation,
        "the first panel mapped mismatched layer roles")) return
      firstMainLayerCount = counts.main
      firstReservationLayerCount = counts.reservation
      panelInstance.setSearchText("Beta")
      phase = 1
      return
    }

    if (layerProbe.purpose === "first-destroyed") {
      if (!check(counts.main === 0 && counts.reservation === 0,
        "destroyed panel left layer surfaces mapped")) return
      phase = 3
      return
    }

    if (layerProbe.purpose === "second-visible") {
      if (!check(counts.main === firstMainLayerCount
          && counts.reservation === firstReservationLayerCount,
        "recreated panel mapped duplicate or missing layer surfaces")) return
      panelInstance.close()
      panelInstance.destroy()
      panelInstance = null
      phase = 40
      Qt.callLater(function() { testRoot.probeLayers("second-destroyed") })
      return
    }

    if (layerProbe.purpose === "second-destroyed") {
      if (!check(counts.main === 0 && counts.reservation === 0,
        "recreated panel left layer surfaces mapped")) return
      finishSuccessfully()
    }
  }

  Process {
    id: layerProbe
    property string purpose: ""
    running: false
    command: ["hyprctl", "layers", "-j"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: testRoot.handleLayerProbe(text)
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) testRoot.abort("hyprctl layers failed with code " + exitCode)
    }
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
      var snapshot = testRoot.panelInstance.renderSnapshot()

      if (testRoot.phase === 0) {
        if (!testRoot.check(snapshot.opened, "panel did not open")) return
        if (!testRoot.check(snapshot.sidebarPresented, "sidebar was not presented")) return
        if (!testRoot.check(snapshot.reservationVisible && snapshot.panelVisible,
          "owned layer-shell windows were not both visible")) return
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
        testRoot.panelInstance.dispatchTestInput("move", 0, 1)
        if (!testRoot.check(testRoot.panelInstance.selectedIndex === 1,
          "down movement did not select the project row")) return
        testRoot.panelInstance.dispatchTestInput("move", -1, 0)
        if (!testRoot.check(testRoot.panelInstance.viewRows.length === 2,
          "left movement did not collapse the selected project")) return
        testRoot.panelInstance.dispatchTestInput("move", 1, 0)
        if (!testRoot.check(testRoot.panelInstance.viewRows.length === 4,
          "right movement did not expand the selected project")) return
        testRoot.panelInstance.dispatchTestInput("move", 0, -1)
        if (!testRoot.check(testRoot.panelInstance.selectedIndex === 0,
          "up movement did not restore the first row")) return

        testRoot.panelInstance.dispatchTestInput("text", "?")
        if (!testRoot.check(testRoot.panelInstance.helpOpen,
          "help key did not open help")) return
        testRoot.panelInstance.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.helpOpen,
          "close input did not close help")) return
        testRoot.panelInstance.dispatchTestInput("text", "/")
        if (!testRoot.check(testRoot.panelInstance.searchOpen,
          "search key did not open search")) return
        testRoot.panelInstance.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.searchOpen,
          "close input did not close search")) return

        testRoot.panelInstance.dispatchTestInput("activate")
        testRoot.panelInstance.dispatchTestInput("text", "n")
        testRoot.panelInstance.dispatchTestInput("text", "p")
        testRoot.panelInstance.dispatchTestInput("text", "y")
        if (!testRoot.check(fakeService.openedThreadCount === 1,
          "activate did not open the selected thread")) return
        if (!testRoot.check(fakeService.newProjectThreadCount === 1,
          "n did not create a thread in the selected directory")) return
        if (!testRoot.check(fakeService.pinnedThreadCount === 1,
          "p did not pin the selected thread")) return
        if (!testRoot.check(fakeService.archivedThreadCount === 1,
          "y did not archive the selected thread")) return
        testRoot.panelInstance.dispatchTestInput("text", "r")
        if (!testRoot.check(testRoot.panelInstance.renameOpen,
          "r did not open rename")) return
        testRoot.panelInstance.dispatchTestInput("close")
        if (!testRoot.check(!testRoot.panelInstance.renameOpen,
          "close input did not close rename")) return

        if (testRoot.liveLayerChecks) {
          testRoot.phase = 10
          testRoot.probeLayers("first-visible")
        } else {
          testRoot.panelInstance.setSearchText("Beta")
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
        testRoot.panelInstance.setSearchText("")
        testRoot.panelInstance.helpOpen = true
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
        if (!testRoot.check(snapshot.panelVisible && snapshot.reservationVisible,
          "recreated panel did not own both visible windows")) return
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
