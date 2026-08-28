// Purpose: Verifies chattoolbar behavior with Qt Quick Test.
import QtQuick
import "../ui" as App

ChatComponentTestBase {
  name: "ChatToolbarAndApproval"

  App.ChatComposerToolbar {
    id: toolbar
    width: parent.width
    window: windowApi
    client: clientApi
    composer: composerApi
  }

  App.ChatApprovalOverlay {
    id: approvalOverlay
    anchors.fill: parent
    window: windowApi
    client: clientApi
  }

  function init() {
    resetFakes()
    approvalOverlay.rememberApproval = false
    wait(0)
  }

  function test_primaryButtonsDelegateToWindowState() {
    mouseClick(findChild(toolbar, "newChatButton"))
    compare(newConversationCount, 1)

    mouseClick(findChild(toolbar, "fastButton"))
    compare(windowApi.serviceTier, "fast")
    mouseClick(findChild(toolbar, "fastButton"))
    compare(windowApi.serviceTier, "default")

    mouseClick(findChild(toolbar, "approveForMeButton"))
    compare(windowApi.approvalsReviewer, "auto_review")
    compare(windowApi.sandboxMode, "workspace-write")
    mouseClick(findChild(toolbar, "approveForMeButton"))
    compare(windowApi.approvalsReviewer, "user")
  }

  function test_selectorsUpdateRuntimeOptions() {
    var modelSelector = findChild(toolbar, "modelSelector")
    var effortSelector = findChild(toolbar, "effortSelector")
    modelSelector.activated(1)
    effortSelector.activated(1)
    compare(windowApi.selectedModel, "gpt-next")
    compare(windowApi.selectedEffort, "high")
  }

  function test_sendButtonSwitchesBetweenSendAndInterrupt() {
    var sendButton = findChild(toolbar, "sendButton")
    composerApi.text = "hello"
    tryCompare(sendButton, "enabled", true)
    mouseClick(sendButton)
    compare(sendComposerCount, 1)

    clientApi.busy = true
    clientApi.activeTurnId = "turn-1"
    tryCompare(sendButton, "enabled", true)
    mouseClick(sendButton)
    compare(interruptCount, 1)
  }

  function test_approvalOverlayAnswersAndClearsRememberState() {
    clientApi.approvalRequest = {
      kind: "command", title: "Run command", detail: "make test"
    }
    tryCompare(approvalOverlay, "visible", true)
    approvalOverlay.rememberApproval = true
    mouseClick(findChild(approvalOverlay, "approveRequest"))
    compare(approvalAnswerCount, 1)
    verify(lastApprovalAccepted)
    verify(lastApprovalRemembered)
    verify(!approvalOverlay.rememberApproval)

    clientApi.approvalRequest = {
      kind: "command", title: "Run command", detail: "make test"
    }
    mouseClick(findChild(approvalOverlay, "declineApproval"))
    compare(approvalAnswerCount, 2)
    verify(!lastApprovalAccepted)
    verify(!lastApprovalRemembered)
  }
}
