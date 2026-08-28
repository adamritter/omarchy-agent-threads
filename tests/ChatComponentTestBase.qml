import QtQuick
import QtTest

TestCase {
  id: testCase
  when: windowShown
  visible: true
  width: 900
  height: 500

  property int newConversationCount: 0
  property int sendComposerCount: 0
  property int approvalChangeCount: 0
  property int interruptCount: 0
  property int approvalAnswerCount: 0
  property bool lastApprovalAccepted: false
  property bool lastApprovalRemembered: false

  readonly property alias windowApi: fakeWindow
  readonly property alias clientApi: fakeClient
  readonly property alias composerApi: fakeComposer

  QtObject {
    id: fakeWindow
    property color raised: "#222222"
    property color hover: "#2a2a2a"
    property color border: "#343434"
    property color foreground: "#ececec"
    property color muted: "#a2a2a2"
    property color accent: "#10a37f"
    property string workingDirectory: "/work/demo"
    property string remoteAddress: ""
    property string selectedModel: ""
    property string selectedEffort: ""
    property string serviceTier: "default"
    property string approvalPolicy: ""
    property string approvalsReviewer: "user"
    property string sandboxMode: ""

    function agentModelState(modelId) {
      return {
        defaultModel: "gpt-test",
        defaultEffort: "medium",
        effectiveModel: modelId || "gpt-test",
        effectiveEffort: selectedEffort || "medium",
        models: [
          { id: "gpt-test", displayName: "GPT Test" },
          { id: "gpt-next", displayName: "GPT Next" }
        ],
        efforts: ["low", "medium", "high"]
      }
    }
    function modelChoices() {
      return [
        { id: "", label: "Default" },
        { id: "gpt-next", label: "GPT Next" }
      ]
    }
    function effortChoices() {
      return [
        { id: "", label: "Default" },
        { id: "high", label: "high" }
      ]
    }
    function choiceIndex(entries, value) {
      for (var index = 0; index < entries.length; index++)
        if (entries[index].id === value) return index
      return 0
    }
    function approvalStatus() { return "Default approvals" }
    function newConversation() { testCase.newConversationCount++ }
    function sendComposer() { testCase.sendComposerCount++ }
    function applyApproval(policy, reviewer) {
      approvalPolicy = policy
      approvalsReviewer = reviewer
      if (reviewer === "auto_review" && sandboxMode === "")
        sandboxMode = "workspace-write"
      testCase.approvalChangeCount++
    }
  }

  QtObject {
    id: fakeClient
    property bool ready: true
    property bool loading: false
    property bool busy: false
    property string activeTurnId: ""
    property string activeThreadId: ""
    property var messages: []
    property var approvalRequest: null

    function interrupt() { testCase.interruptCount++ }
    function answerApproval(accepted, remembered) {
      testCase.approvalAnswerCount++
      testCase.lastApprovalAccepted = accepted
      testCase.lastApprovalRemembered = remembered
      approvalRequest = null
    }
  }

  QtObject {
    id: fakeComposer
    property string text: ""
  }

  function resetFakes() {
    newConversationCount = 0
    sendComposerCount = 0
    approvalChangeCount = 0
    interruptCount = 0
    approvalAnswerCount = 0
    lastApprovalAccepted = false
    lastApprovalRemembered = false
    fakeWindow.selectedModel = ""
    fakeWindow.selectedEffort = ""
    fakeWindow.serviceTier = "default"
    fakeWindow.approvalPolicy = ""
    fakeWindow.approvalsReviewer = "user"
    fakeWindow.sandboxMode = ""
    fakeClient.ready = true
    fakeClient.loading = false
    fakeClient.busy = false
    fakeClient.activeTurnId = ""
    fakeClient.approvalRequest = null
    fakeComposer.text = ""
  }
}
