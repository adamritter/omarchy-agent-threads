// Purpose: Provides shared fixtures and assertions for Sidebar Controller tests.
import QtQuick
import QtTest
import "../ui" as Ui

TestCase {
  id: testCase

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

  property alias controller: controllerObject
  property alias listView: fakeListView
  readonly property var listActions: testCase
  readonly property var overlayActions: testCase
  readonly property var providerActions: testCase
  readonly property var focusActions: testCase
  QtObject {
    id: fakeService
    readonly property var mutations: fakeService
    readonly property var providers: fakeService
    readonly property var threadActions: fakeService
    readonly property var settings: fakeService
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
    id: controllerObject
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
    controllerObject.activationIntentThreadId = ""
  }

}
