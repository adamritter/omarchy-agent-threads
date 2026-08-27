import QtQuick
import QtTest
import "../ui" as Ui

TestCase {
  id: testCase
  name: "SidebarController"

  property string activeProvider: "codex"
  property string homePath: "/home/test"
  property var activeProviderHost: null
  property var viewRows: []
  property int selectedIndex: -1
  property int releaseCount: 0
  property int terminalCount: 0
  property string terminalMode: ""
  property string terminalEndpoint: ""
  property string terminalPath: ""
  property int openedThreadCount: 0
  property int openedRemoteThreadCount: 0
  property string openedThreadId: ""
  property string openedRemoteId: ""
  property var activationEvents: []
  property bool opened: true
  property bool sidebarFocused: false
  property bool reloadSelectionPending: false
  property int archiveCount: 0
  property string createdPath: ""
  property string renamedThreadId: ""

  QtObject {
    id: fakeService
    property string launchError: ""
    property var threads: []
    property var remoteHosts: []
    property string activeThreadId: ""
    property string launchingThreadId: ""
    property string failedLaunchThreadId: ""
    property string remoteActionHostId: ""
    property string archivingThreadId: ""
    property string pinningThreadId: ""
    property string renamingThreadId: ""
    property string movingThreadId: ""
    property string launchingProjectPath: ""
    property string remoteClaudeLoginHostId: ""
    property bool remoteClaudeLoginRunning: false
    property bool acceptLaunch: true
    function openThread(thread, path, source) {
      testCase.activationEvents.push("open:" + String(thread.id || ""))
      testCase.openedThreadCount++
      testCase.openedThreadId = String(thread.id || "")
      if (!acceptLaunch) return false
      launchingThreadId = testCase.openedThreadId
      return true
    }
    function openRemoteThread(remoteId, thread, path, source) {
      testCase.activationEvents.push("open-remote:" + String(thread.id || ""))
      testCase.openedRemoteThreadCount++
      testCase.openedRemoteId = String(remoteId || "")
      testCase.openedThreadId = String(thread.id || "")
      if (!acceptLaunch) return false
      launchingThreadId = testCase.openedThreadId
      return true
    }
    function openTerminal(mode, endpoint, path) {
      testCase.terminalCount++
      testCase.terminalMode = mode
      testCase.terminalEndpoint = endpoint
      testCase.terminalPath = path
      return true
    }
    function threadStatus(threadId) { return threadId === "busy" ? "busy" : "done" }
    function remoteThreadStatus(thread) { return String(thread && thread.status || "done") }
    function threadUnread(threadId) { return threadId === "ready" }
    function archiveThread(thread) { testCase.archiveCount++; return true }
    function archiveRemoteThread(remoteId, thread) { testCase.archiveCount++; return true }
    function newProjectThread(path) { testCase.createdPath = path; return true }
    function newRemoteThread(remoteId, path) { testCase.createdPath = path; return true }
  }

  Item {
    id: fakeListView
    property int positionedIndex: -1
    function positionViewAtIndex(index, mode) { positionedIndex = index }
  }

  Ui.SidebarController {
    id: controller
    panel: testCase
    listView: fakeListView
  }

  property var service: fakeService

  function releaseSidebarFocus(force) {
    activationEvents.push("release")
    releaseCount++
  }
  function rowKey(row) {
    return String(row.kind) + ":"
      + String(row.id || (row.thread ? row.thread.id : "") || row.path || "")
  }
  function rowIndexForKey(key) {
    for (var index = 0; index < viewRows.length; index++) {
      var row = viewRows[index]
      if (rowKey(row) === key) return index
      if (row.kind === "thread"
          && String(key).endsWith(":" + String(row.thread && row.thread.id || row.id || "")))
        return index
    }
    return -1
  }
  function projectPath(thread) { return String(thread && thread.cwd || "") }
  function remoteCollapsed(remoteId) { return true }
  function projectCollapsed(path, remoteId) { return true }
  function sectionPinned(kind, path, remoteId) { return false }
  function threadTitle(thread) { return String(thread && thread.name || "Untitled") }
  function startRename(remoteId, thread) {
    renamedThreadId = String(thread && thread.id || "")
  }

  function init() {
    activeProvider = "codex"
    activeProviderHost = null
    viewRows = []
    selectedIndex = -1
    releaseCount = 0
    terminalCount = 0
    terminalMode = ""
    terminalEndpoint = ""
    terminalPath = ""
    openedThreadCount = 0
    openedRemoteThreadCount = 0
    openedThreadId = ""
    openedRemoteId = ""
    activationEvents = []
    fakeService.launchError = ""
    fakeService.threads = []
    fakeService.remoteHosts = []
    fakeService.activeThreadId = ""
    fakeService.launchingThreadId = ""
    fakeService.failedLaunchThreadId = ""
    fakeService.acceptLaunch = true
    archiveCount = 0
    createdPath = ""
    renamedThreadId = ""
    fakeListView.positionedIndex = -1
    controller.activationIntentThreadId = ""
  }

  function test_clickActivationReleasesFocusBeforeOpeningThread() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } }
    ]

    compare(controller.activateRow(1), "thread:alpha")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 1)
    compare(openedThreadId, "alpha")
    compare(activationEvents.join(","), "release,open:alpha")
  }

  function test_derivesRowPresentationAtControllerBoundary() {
    fakeService.activeThreadId = "busy"
    fakeService.threads = [{ id: "busy", name: "Busy", cwd: "/work" }]
    var state = controller.rowPresentation({
      kind: "thread", path: "/work", thread: fakeService.threads[0]
    }, 0, false)
    verify(state.threadRow)
    verify(state.activeThread)
    verify(state.busy)
    compare(state.threadTitle, "Busy")
  }

  function test_routesRowCommandsThroughController() {
    var threadRow = {
      kind: "thread", path: "/work/app", thread: { id: "thread-1" }
    }
    verify(controller.archiveRow(threadRow))
    compare(archiveCount, 1)
    verify(controller.renameRow(threadRow))
    compare(renamedThreadId, "thread-1")
    verify(controller.createThreadForRow({ kind: "project", path: "/work/new" }))
    compare(createdPath, "/work/new")
  }

  function test_selectsAdjacentThreadsAndSkipsStructuralRows() {
    viewRows = [
      { kind: "remote", id: "host" },
      { kind: "project", path: "/work/a" },
      { kind: "thread", id: "alpha" },
      { kind: "more", id: "more" },
      { kind: "project", path: "/work/b" },
      { kind: "thread", id: "beta" }
    ]
    selectedIndex = 0
    compare(controller.selectAdjacentThread(1), "thread:alpha")
    compare(selectedIndex, 2)
    compare(fakeListView.positionedIndex, 2)
    compare(controller.selectAdjacentThread(1), "thread:beta")
    compare(selectedIndex, 5)
    compare(controller.selectAdjacentThread(1), "thread:alpha")
    compare(selectedIndex, 2)
    compare(controller.selectAdjacentThread(-1), "thread:beta")
    compare(selectedIndex, 5)
  }

  function test_selectAdjacentThreadHandlesEmptyAndUnselectedLists() {
    compare(controller.selectAdjacentThread(1), "")
    viewRows = [{ kind: "project", path: "/work" }, { kind: "thread", id: "only" }]
    compare(controller.selectAdjacentThread(1), "thread:only")
    selectedIndex = -1
    compare(controller.selectAdjacentThread(-1), "thread:only")
  }

  function test_activatesFromActiveThreadInsteadOfUiSelection() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } },
      { kind: "project", path: "/work/b" },
      { kind: "thread", path: "/work/b", thread: { id: "beta" } }
    ]
    fakeService.activeThreadId = "alpha"
    selectedIndex = 3

    compare(controller.activateAdjacentThread(1), "thread:beta")
    compare(selectedIndex, 3)
    compare(openedThreadCount, 1)
    compare(openedThreadId, "beta")
    compare(controller.followTargetThreadId(), "beta")
    compare(releaseCount, 1)

    fakeService.activeThreadId = "beta"
    fakeService.launchingThreadId = ""
    compare(controller.activateAdjacentThread(-1), "thread:alpha")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 2)
    compare(openedThreadId, "alpha")
  }

  function test_previousActivationStopsAtFirstThread() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } },
      { kind: "project", path: "/work/b" },
      { kind: "thread", path: "/work/b", thread: { id: "beta" } }
    ]
    fakeService.activeThreadId = "alpha"
    selectedIndex = 1

    compare(controller.activateAdjacentThread(-1), "")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 0)
    compare(openedRemoteThreadCount, 0)
    compare(releaseCount, 0)
  }

  function test_followTargetPrefersPendingActivation() {
    fakeService.activeThreadId = "old"
    fakeService.threads = [
      { id: "old", cwd: "/work/a" },
      { id: "requested", cwd: "/work/b" }
    ]
    fakeService.launchingThreadId = "requested"
    compare(controller.followTargetThreadId(), "requested")

    fakeService.launchingThreadId = ""
    compare(controller.followTargetThreadId(), "old")
  }

  function test_failedActivationDoesNotSnapSelectionBackToActiveThread() {
    viewRows = [
      { kind: "thread", path: "/work/a", thread: { id: "old" } },
      { kind: "thread", path: "/work/b", thread: { id: "requested" } }
    ]
    fakeService.activeThreadId = "old"

    compare(controller.activateRow(1, "pointer"), "thread:requested")
    fakeService.launchingThreadId = ""
    fakeService.failedLaunchThreadId = "requested"

    compare(controller.followTargetThreadId(), "requested")
    controller.followActiveThread(true)
    compare(selectedIndex, 1)
  }

  function test_rejectedActivationDoesNotCreateAnIntent() {
    viewRows = [{
      kind: "thread", path: "/work/a", thread: { id: "requested" }
    }]
    fakeService.acceptLaunch = false

    compare(controller.activateRow(0, "keyboard"), "")
    compare(controller.activationIntentThreadId, "")
    compare(fakeService.launchingThreadId, "")
  }

  function test_activatesRemoteThreadThroughRemoteProvider() {
    viewRows = [
      { kind: "thread", path: "/work/local", thread: { id: "local" } },
      { kind: "remote", remoteId: "dev" },
      { kind: "project", remoteId: "dev", path: "/srv/app" },
      { kind: "thread", remoteId: "dev", path: "/srv/app",
        thread: { id: "remote" } }
    ]
    fakeService.activeThreadId = "local"

    compare(controller.activateAdjacentThread(1), "thread:remote")
    compare(openedRemoteThreadCount, 1)
    compare(openedRemoteId, "dev")
    compare(openedThreadId, "remote")
  }

  function test_opensLocalProjectTerminal() {
    viewRows = [{ kind: "project", path: "/work/app" }]
    selectedIndex = 0
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "local")
    compare(terminalPath, "/work/app")
    compare(releaseCount, 1)
  }

  function test_opensSshHostAndFolderTerminals() {
    var host = {
      id: "dev", type: "ssh", sshHost: "devbox", home: "/home/dev"
    }
    viewRows = [{
      kind: "remote", remoteId: "dev", path: "/home/dev", host: host
    }]
    selectedIndex = 0
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "ssh")
    compare(terminalEndpoint, "devbox")
    compare(terminalPath, "/home/dev")

    viewRows = [{
      kind: "project", remoteId: "dev", path: "/srv/app", host: host
    }]
    terminalCount = 0
    verify(controller.openSelectedTerminal())
    compare(terminalCount, 1)
    compare(terminalPath, "/srv/app")
  }

  function test_usesLocalProviderHomeWithoutSelection() {
    activeProvider = "claude"
    activeProviderHost = {
      id: "provider-claude", type: "provider", home: "/home/test"
    }
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "local")
    compare(terminalPath, "/home/test")
  }

  function test_rejectsAppServerWithoutSsh() {
    viewRows = [{
      kind: "remote", remoteId: "server", path: "/srv/app",
      host: { id: "server", type: "app-server", home: "/srv" }
    }]
    selectedIndex = 0
    verify(!controller.openSelectedTerminal())
    compare(terminalCount, 0)
    compare(releaseCount, 0)
    verify(fakeService.launchError.indexOf("requires an SSH connection") >= 0)
  }
}
