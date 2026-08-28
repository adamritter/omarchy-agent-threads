// Purpose: Implements the Chat Window component for Agent Chat.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../providers" as Providers
import "../../logic/ActionLogic.js" as ActionLogic
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions

FloatingWindow {
  id: root

  visible: true
  title: conversation.activeThreadId === ""
    ? "Agent Chat" : "Agent Chat · " + conversation.activeThreadId.slice(0, 8)
  color: "#171717"
  implicitWidth: 1080
  implicitHeight: 800
  minimumSize: Qt.size(760, 560)

  readonly property var initialOptions: ChatLaunchOptions.parseJson(
    Quickshell.env("AGENT_CHAT_OPTIONS"))
  property string workingDirectory: initialOptions.cwd || Quickshell.env("HOME")
  property string selectedModel: initialOptions.model
  property string selectedEffort: initialOptions.effort
  property string serviceTier: initialOptions.serviceTier
  property string approvalPolicy: initialOptions.approvalPolicy
  property string approvalsReviewer: initialOptions.approvalsReviewer
  property string sandboxMode: initialOptions.sandbox
  property string remoteAddress: initialOptions.remote
  property string pendingLaunchPrompt: initialOptions.prompt
  property bool startupConfigured: false

  readonly property color background: "#171717"
  readonly property color raised: "#222222"
  readonly property color hover: "#2a2a2a"
  readonly property color border: "#343434"
  readonly property color foreground: "#ececec"
  readonly property color muted: "#a2a2a2"
  readonly property color accent: "#10a37f"

  function agentModelState(modelId) {
    return conversation.modelState(modelId, selectedModel, selectedEffort)
  }

  function modelStateLabel(state) {
    var value = state || ({})
    var entry = value.model || ({})
    return String(entry.displayName || entry.name || value.effectiveModel
      || value.defaultModel || "Default")
  }

  function effortStateLabel(state) {
    var effort = String((state || {}).effectiveEffort
      || (state || {}).defaultEffort || "")
    return effort === "" ? "Default" : effort.charAt(0).toUpperCase() + effort.slice(1)
  }

  function modelChoices() {
    var state = agentModelState()
    var result = [{ id: "", label: modelStateLabel(state) }]
    var foundSelected = selectedModel === ""
    var entries = state.models
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i] || ({})
      var id = String(entry.model || entry.id || "")
      if (id === "") continue
      if (id === selectedModel) foundSelected = true
      result.push({ id: id, label: String(entry.displayName || entry.name || id) })
    }
    if (!foundSelected) result.push({ id: selectedModel, label: selectedModel })
    return result
  }

  function effortChoices() {
    var state = agentModelState(selectedModel)
    var result = [{ id: "", label: effortStateLabel(state) }]
    var entries = state.efforts
    var foundSelected = selectedEffort === ""
    for (var i = 0; i < entries.length; i++) {
      var id = String(entries[i] || "")
      if (id === "") continue
      if (id === selectedEffort) foundSelected = true
      result.push({ id: id, label: id })
    }
    if (!foundSelected) result.push({ id: selectedEffort, label: selectedEffort })
    return result
  }

  function choiceIndex(entries, value) {
    var wanted = String(value || "")
    for (var i = 0; i < entries.length; i++)
      if (String(entries[i].id || "") === wanted) return i
    return 0
  }

  function cycleEffort() {
    selectedEffort = ActionLogic.nextChoiceId(selectedEffort, effortChoices())
    return selectedEffort || "default"
  }

  function applyApproval(policy, reviewer) {
    approvalPolicy = policy
    approvalsReviewer = reviewer
    if (reviewer === "auto_review" && sandboxMode === "")
      sandboxMode = "workspace-write"
  }

  function approvalStatus() {
    if (approvalsReviewer === "auto_review") return "Auto review"
    if (approvalPolicy === "never") return "Never ask"
    if (approvalPolicy === "untrusted") return "Untrusted only"
    if (approvalPolicy === "on-request") return "Ask as needed"
    return "Default approvals"
  }

  function syncRuntimeOptions() {
    conversation.configuredCwd = workingDirectory
    conversation.configuredModel = selectedModel
    conversation.configuredEffort = selectedEffort
    conversation.configuredServiceTier = serviceTier
    conversation.configuredApprovalPolicy = approvalPolicy
    conversation.configuredApprovalsReviewer = approvalsReviewer
    conversation.configuredSandbox = sandboxMode
  }

  function newConversation() {
    if (conversation.busy) return
    syncRuntimeOptions()
    conversation.newChat(workingDirectory, selectedModel, selectedEffort)
    composer.text = ""
    composer.forceActiveFocus()
  }

  function sendComposer() {
    if (conversation.busy) return
    var prompt = composer.text.trim()
    if (prompt === "") return
    syncRuntimeOptions()
    if (conversation.sendPrompt(prompt, workingDirectory, selectedModel, selectedEffort))
      composer.text = ""
  }

  function deliverPendingPrompt() {
    var prompt = pendingLaunchPrompt
    pendingLaunchPrompt = ""
    if (prompt !== "") {
      syncRuntimeOptions()
      conversation.sendPrompt(prompt, workingDirectory, selectedModel, selectedEffort)
    } else composer.forceActiveFocus()
  }

  function applyLaunchOptions(options) {
    if (conversation.busy) return false
    var next = ChatLaunchOptions.normalize(options)
    workingDirectory = next.cwd || Quickshell.env("HOME")
    selectedModel = next.model
    selectedEffort = next.effort
    serviceTier = next.serviceTier
    approvalPolicy = next.approvalPolicy
    approvalsReviewer = next.approvalsReviewer
    sandboxMode = next.sandbox
    remoteAddress = next.remote
    pendingLaunchPrompt = next.prompt
    startupConfigured = true
    return conversation.configure(next)
  }

  function applyLaunchOptionsJson(optionsJson) {
    var options
    try {
      options = JSON.parse(String(optionsJson || "{}"))
    } catch (error) {
      return false
    }
    return applyLaunchOptions(options)
  }

  onVisibleChanged: if (!visible) Qt.quit()

  IpcHandler {
    target: "agentChat"

    function open(optionsJson: string): string {
      return root.applyLaunchOptionsJson(optionsJson) ? "ok" : "busy"
    }

    function fast(mode: string): string {
      var wanted = String(mode || "").toLowerCase()
      if (wanted === "toggle")
        root.serviceTier = root.serviceTier === "fast" ? "default" : "fast"
      else if (wanted === "on" || wanted === "fast") root.serviceTier = "fast"
      else if (wanted === "off" || wanted === "default") root.serviceTier = "default"
      return root.serviceTier === "fast" ? "on" : "off"
    }

    function effort(mode: string): string {
      if (String(mode || "").toLowerCase() === "cycle") return root.cycleEffort()
      return root.selectedEffort || "default"
    }
  }

  Providers.CodexConversationClient {
    id: conversation
    onActiveCwdChanged: if (activeCwd !== "") root.workingDirectory = activeCwd
    onSessionReady: root.deliverPendingPrompt()
  }

  Component.onCompleted: applyLaunchOptions(initialOptions)

  Shortcut {
    sequence: "Meta+Ctrl+F"
    onActivated: root.serviceTier = root.serviceTier === "fast" ? "default" : "fast"
  }

  Shortcut {
    sequence: "Meta+Ctrl+E"
    onActivated: root.cycleEffort()
  }

  Shortcut {
    sequence: "PgUp"
    onActivated: transcriptPane.scrollPage(-1)
  }

  Shortcut {
    sequence: "PgDown"
    onActivated: transcriptPane.scrollPage(1)
  }

  Shortcut {
    sequence: "Ctrl+Home"
    onActivated: transcriptPane.scrollEdge(-1)
  }

  Shortcut {
    sequence: "Ctrl+End"
    onActivated: transcriptPane.scrollEdge(1)
  }

  Shortcut {
    sequence: "Escape"
    onActivated: composer.forceActiveFocus()
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    ChatTranscriptPane {
      id: transcriptPane
      Layout.fillWidth: true
      Layout.fillHeight: true
      window: root
      client: conversation
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? 38 : 0
      visible: conversation.errorText !== ""
      color: "#4a2424"
      Label {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        text: conversation.errorText
        color: root.foreground
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
    }

    ChatComposer {
      id: composer
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
      window: root
      client: conversation
    }
  }

  ChatApprovalOverlay {
    anchors.fill: parent
    window: root
    client: conversation
  }
}
