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
  property bool opened: true

  QtObject {
    id: fakeService
    property string launchError: ""
    property string activeThreadId: ""
    property string launchingThreadId: ""
    function openThread(thread, path) {
      testCase.openedThreadCount++
      testCase.openedThreadId = String(thread.id || "")
      launchingThreadId = testCase.openedThreadId
    }
    function openRemoteThread(remoteId, thread, path) {
      testCase.openedRemoteThreadCount++
      testCase.openedRemoteId = String(remoteId || "")
      testCase.openedThreadId = String(thread.id || "")
      launchingThreadId = testCase.openedThreadId
    }
    function openTerminal(mode, endpoint, path) {
      testCase.terminalCount++
      testCase.terminalMode = mode
      testCase.terminalEndpoint = endpoint
      testCase.terminalPath = path
      return true
    }
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

  function releaseSidebarFocus(force) { releaseCount++ }
  function rowKey(row) {
    return String(row.kind) + ":"
      + String(row.id || (row.thread ? row.thread.id : "") || row.path || "")
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
    fakeService.launchError = ""
    fakeService.activeThreadId = ""
    fakeService.launchingThreadId = ""
    fakeListView.positionedIndex = -1
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
    fakeService.launchingThreadId = "requested"
    compare(controller.followTargetThreadId(), "requested")

    fakeService.launchingThreadId = ""
    compare(controller.followTargetThreadId(), "old")
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
