import QtQuick
import QtTest
import "../ui" as Ui

TestCase {
  id: testCase
  name: "PanelFocusController"
  when: windowShown
  width: 640
  height: 480

  property int followCount: 0
  property int clearPrefixCount: 0

  QtObject {
    id: sessionState
    property bool keyboardFocusRequested: false
    property bool focusPrimed: false
    property int focusAttemptsRemaining: 0
    property bool focusWorkflowPending: false
    property bool pointerHoverSuppressed: false
    property int cursorReturnX: -1
    property int cursorReturnY: -1
    property bool fullscreenProbeQueued: false
    property string activeWorkspaceKey: "1"
    property string pendingReloadWorkspaceKey: ""
    property bool applyingWorkspaceSidebarState: false
    property bool activeWorkspaceHasFullscreen: false
    property bool activeWorkspaceGeometryFullscreen: false
    property int fullscreenInternalState: 0
    property int fullscreenClientState: 0
    property int activeWorkspaceId: 1
    property string searchText: ""
    property bool searchOpen: false
  }

  QtObject {
    id: fakeTimer
    property bool running: false
    property int restartCount: 0
    property int stopCount: 0
    function restart() { running = true; restartCount++ }
    function stop() { running = false; stopCount++ }
  }
  QtObject {
    id: focusPrimeTimer
    property bool running: false
    property int restartCount: 0
    function restart() { running = true; restartCount++ }
    function stop() { running = false }
  }
  QtObject {
    id: focusAcquireTimer
    property bool running: false
    property int restartCount: 0
    property int stopCount: 0
    function restart() { running = true; restartCount++ }
    function stop() { running = false; stopCount++ }
  }
  QtObject { id: cursorProbe; property bool running: false }
  QtObject { id: fullscreenProbe; property bool running: false }
  QtObject {
    id: runtimeApi
    readonly property var focusReleaseGuard: fakeTimer
    readonly property var focusPrimeTimer: focusPrimeTimer
    readonly property var focusAcquireTimer: focusAcquireTimer
    readonly property var pointerWarpGuard: pointerWarpGuard
    readonly property var cursorPositionProbe: cursorProbe
    readonly property var fullscreenProbe: fullscreenProbe
  }
  QtObject {
    id: pointerWarpGuard
    property bool running: false
    property int restartCount: 0
    function restart() { running = true; restartCount++ }
  }
  QtObject {
    id: navigationApi
    function activeThreadCursorPoint() { return '{"x":120,"y":5}' }
    function followActiveThread(force) { testCase.followCount++ }
  }
  QtObject {
    id: sidebarActionsApi
    readonly property var navigation: navigationApi
  }
  QtObject {
    id: reloadApi
    function clearNavigationPrefix() { testCase.clearPrefixCount++ }
    function cancelPanelReloadFocus() {}
    function tryRestorePanelReloadFocus() {}
  }
  QtObject {
    id: settingsApi
    property bool loaded: true
    property string scope: "workspace"
    function migrateSidebarOpenState(key) {}
    function sidebarOpenOnWorkspace(key) { return true }
    function setSidebarScope(scope, key, opened) { settingsApi.scope = scope }
  }
  QtObject { id: serviceApi; readonly property var settings: settingsApi }
  QtObject { id: appearanceApi; property int sidebarContentWidth: 380 }
  QtObject { id: barApi; property string position: "top"; property int barSize: 32 }
  QtObject {
    id: searchFieldApi
    property bool focus: false
    function forceActiveFocus() { focus = true }
  }
  Item {
    id: sidebarViewApi
    width: 380
    height: 400
    property var searchField: searchFieldApi
    function forceActiveFocus() { focus = true }
  }
  QtObject {
    id: compositorApi
    property string lastCommand: ""
    property bool shouldFail: false
    function dispatch(command) {
      if (shouldFail) throw new Error("dispatch failed")
      lastCommand = command
    }
  }

  Item {
    id: panelApi
    width: 380
    height: 400
    property bool opened: false
    property bool fullscreenSuppressed: false
    property bool sidebarFocused: sessionState.keyboardFocusRequested
      && sidebarViewApi.activeFocus
    property var screen: ({ x: 100, y: 50 })
    property var margins: ({ top: 8 })
    readonly property var session: sessionState
    readonly property var runtime: runtimeApi
    readonly property var sidebarView: sidebarViewApi
    readonly property var sidebarActions: sidebarActionsApi
    readonly property var reloadActions: reloadApi
    readonly property var service: serviceApi
    readonly property var appearance: appearanceApi
    readonly property var bar: barApi
    function open() { opened = true }
    function close() { opened = false }
  }

  Ui.PanelFocusController {
    id: controller
    panel: panelApi
    compositor: compositorApi
  }

  function init() {
    panelApi.opened = false
    panelApi.fullscreenSuppressed = false
    sessionState.keyboardFocusRequested = false
    sessionState.focusPrimed = false
    sessionState.focusAttemptsRemaining = 0
    sessionState.focusWorkflowPending = false
    sessionState.cursorReturnX = -1
    sessionState.cursorReturnY = -1
    sidebarViewApi.focus = false
    searchFieldApi.focus = false
    cursorProbe.running = false
    fullscreenProbe.running = false
    fakeTimer.running = false
    compositorApi.lastCommand = ""
    compositorApi.shouldFail = false
    followCount = 0
    clearPrefixCount = 0
  }

  function test_summonCompletesFocusAndCursorWorkflow() {
    controller.summonSidebarFocus()
    verify(panelApi.opened)
    verify(sessionState.focusWorkflowPending)
    verify(cursorProbe.running)

    controller.completeSidebarSummon('{"x":400,"y":300}')
    verify(!sessionState.focusWorkflowPending)
    compare(sessionState.cursorReturnX, 400)
    compare(sessionState.cursorReturnY, 300)
    verify(compositorApi.lastCommand.indexOf("x = 220") >= 0)
    verify(compositorApi.lastCommand.indexOf("y = 95") >= 0)
    wait(0)
    verify(sessionState.keyboardFocusRequested)
  }

  function test_dispatchFailureStillFocusesAndClearsPendingState() {
    compositorApi.shouldFail = true
    controller.summonSidebarFocus()
    controller.completeSidebarSummon('{"x":4,"y":8}')
    verify(!sessionState.focusWorkflowPending)
    verify(sessionState.keyboardFocusRequested)
  }

  function test_timeoutRecoversAProbeThatNeverCompletes() {
    controller.summonSidebarFocus()
    verify(sessionState.focusWorkflowPending)
    tryCompare(sessionState, "focusWorkflowPending", false, 1300)
    verify(sessionState.keyboardFocusRequested)
  }

  function test_releaseAlwaysClearsWorkflowAndFocusState() {
    panelApi.opened = true
    sessionState.focusWorkflowPending = true
    sessionState.keyboardFocusRequested = true
    searchFieldApi.focus = true
    sidebarViewApi.focus = true
    controller.releaseSidebarFocus(true)
    verify(!sessionState.focusWorkflowPending)
    verify(!sessionState.keyboardFocusRequested)
    verify(!searchFieldApi.focus)
    verify(!sidebarViewApi.focus)
    compare(clearPrefixCount, 1)
    wait(0)
    compare(followCount, 1)
  }
}
