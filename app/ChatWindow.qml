import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../providers" as Providers
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions
import "../logic/CodexConversationLogic.js" as ConversationLogic

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
  property string workingDirectory: initialOptions.cwd || Quickshell.env("HOME") || "/tmp"
  property string selectedModel: initialOptions.model
  property string selectedEffort: initialOptions.effort
  property string serviceTier: initialOptions.serviceTier
  property string approvalPolicy: initialOptions.approvalPolicy
  property string approvalsReviewer: initialOptions.approvalsReviewer
  property string sandboxMode: initialOptions.sandbox
  property string remoteAddress: initialOptions.remote
  property string pendingLaunchPrompt: initialOptions.prompt
  property bool startupConfigured: false
  property bool rememberApproval: false

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
    workingDirectory = next.cwd || Quickshell.env("HOME") || "/tmp"
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
    onActivated: transcriptView.scrollPage(-1)
  }

  Shortcut {
    sequence: "PgDown"
    onActivated: transcriptView.scrollPage(1)
  }

  Shortcut {
    sequence: "Ctrl+Home"
    onActivated: transcriptView.scrollEdge(-1)
  }

  Shortcut {
    sequence: "Ctrl+End"
    onActivated: transcriptView.scrollEdge(1)
  }

  Shortcut {
    sequence: "Escape"
    onActivated: composer.forceActiveFocus()
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      WebTranscript {
        id: transcriptView
        anchors.fill: parent
        messages: conversation.messages
        busy: conversation.busy
        loading: conversation.loading || !conversation.ready
        conversationTitle: conversation.activeThreadId === ""
          ? "New conversation" : "Thread " + conversation.activeThreadId.slice(0, 12)
        conversationDetail: root.workingDirectory + "  ·  "
          + ChatLaunchOptions.connectionLabel(root.remoteAddress)
      }

      BusyIndicator {
        anchors.centerIn: parent
        running: conversation.loading || !conversation.ready
        visible: running && conversation.messages.length === 0
      }
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

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: composerFrame.height + 28

      Rectangle {
        id: composerFrame
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Math.max(22, (parent.width - 840) / 2)
        anchors.rightMargin: Math.max(22, (parent.width - 840) / 2)
        anchors.bottomMargin: 14
        height: Math.max(88, Math.min(204, composer.implicitHeight + 54))
        radius: 20
        color: root.raised
        border.color: composer.activeFocus ? "#555555" : root.border

        TextArea {
          id: composer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: composerToolbar.top
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          anchors.topMargin: 10
          anchors.bottomMargin: 4
          color: root.foreground
          placeholderText: conversation.ready ? "Message Codex" : "Connecting to Codex..."
          placeholderTextColor: root.muted
          wrapMode: TextEdit.Wrap
          maximumLength: ConversationLogic.promptCharacterLimit()
          enabled: conversation.ready && !conversation.loading
          background: Item {}
          font.pixelSize: 14
          Keys.onReturnPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
              event.accepted = false
              return
            }
            root.sendComposer()
            event.accepted = true
          }
        }

        RowLayout {
          id: composerToolbar
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          anchors.bottomMargin: 8
          height: 36
          spacing: 5

          Button {
            id: newChatButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            text: "+"
            font.pixelSize: 20
            ToolTip.visible: hovered
            ToolTip.text: "New conversation"
            onClicked: root.newConversation()
            background: Rectangle {
              radius: 10
              color: newChatButton.hovered ? root.hover : "transparent"
            }
            contentItem: Label {
              text: newChatButton.text
              color: root.muted
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font: newChatButton.font
            }
          }

          ComboBox {
            id: modelSelector
            Layout.fillWidth: true
            Layout.minimumWidth: 72
            Layout.preferredWidth: 150
            Layout.maximumWidth: 190
            Layout.preferredHeight: 34
            model: root.modelChoices()
            textRole: "label"
            currentIndex: root.choiceIndex(model, root.selectedModel)
            onActivated: function(index) { root.selectedModel = model[index].id }
            ToolTip.visible: hovered
            ToolTip.text: root.selectedModel !== "" ? root.selectedModel
              : "Default model · " + (root.agentModelState().defaultModel || "Codex")
            palette.text: root.foreground
            palette.buttonText: root.foreground
            palette.button: root.raised
            palette.window: root.raised
            palette.highlight: root.hover
            palette.highlightedText: root.foreground
            background: Rectangle {
              radius: 10
              color: modelSelector.hovered ? root.hover : "transparent"
            }
          }

          ComboBox {
            id: effortSelector
            Layout.preferredWidth: 78
            Layout.preferredHeight: 34
            model: root.effortChoices()
            textRole: "label"
            currentIndex: root.choiceIndex(model, root.selectedEffort)
            onActivated: function(index) { root.selectedEffort = model[index].id }
            ToolTip.visible: hovered
            ToolTip.text: (root.selectedEffort !== "" ? root.selectedEffort
              : "Default effort · " + (root.agentModelState(root.selectedModel).defaultEffort
                || "Codex")) + " · Super+Ctrl+E"
            palette.text: root.foreground
            palette.buttonText: root.foreground
            palette.button: root.raised
            palette.window: root.raised
            palette.highlight: root.hover
            palette.highlightedText: root.foreground
            background: Rectangle {
              radius: 10
              color: effortSelector.hovered ? root.hover : "transparent"
            }
          }

          Button {
            id: fastButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            text: "⚡︎"
            font.pixelSize: 16
            ToolTip.visible: hovered
            ToolTip.text: "Fast responses: "
              + (root.serviceTier === "fast" ? "On" : "Off")
              + " · Super+Ctrl+F"
            onClicked: root.serviceTier = root.serviceTier === "fast" ? "default" : "fast"
            background: Rectangle {
              radius: 10
              color: root.serviceTier === "fast" ? root.accent
                : (fastButton.hovered ? root.hover : "transparent")
            }
            contentItem: Label {
              text: fastButton.text
              color: root.serviceTier === "fast" ? "white" : root.muted
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font: fastButton.font
            }
          }

          Button {
            id: approveForMeButton
            Layout.preferredWidth: 122
            Layout.preferredHeight: 34
            text: "✓  Approve for me"
            font.pixelSize: 12
            ToolTip.visible: hovered
            ToolTip.text: "Approve for me: "
              + (root.approvalsReviewer === "auto_review" ? "On" : "Off")
            onClicked: root.approvalsReviewer === "auto_review"
              ? root.applyApproval("", "user")
              : root.applyApproval("on-request", "auto_review")
            background: Rectangle {
              radius: 10
              color: root.approvalsReviewer === "auto_review" ? root.accent
                : (approveForMeButton.hovered ? root.hover : "transparent")
            }
            contentItem: Label {
              text: approveForMeButton.text
              color: root.approvalsReviewer === "auto_review" ? "white" : root.muted
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font: approveForMeButton.font
            }
          }

          Button {
            id: optionsButton
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            text: "⋯"
            font.pixelSize: 20
            ToolTip.visible: hovered
            ToolTip.text: root.approvalStatus()
            onClicked: optionsMenu.open()
            background: Rectangle {
              radius: 10
              color: optionsButton.hovered || optionsMenu.visible ? root.hover : "transparent"
            }
            contentItem: Label {
              text: optionsButton.text
              color: root.muted
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font: optionsButton.font
            }

            Menu {
              id: optionsMenu
              y: -height - 6
              palette.window: root.raised
              palette.text: root.foreground
              palette.highlight: root.hover
              palette.highlightedText: root.foreground

              MenuItem {
                text: "Default approvals"
                checkable: true
                checked: root.approvalsReviewer !== "auto_review"
                  && root.approvalPolicy === ""
                onTriggered: root.applyApproval("", "user")
              }
              MenuItem {
                text: "Ask as needed"
                checkable: true
                checked: root.approvalsReviewer !== "auto_review"
                  && root.approvalPolicy === "on-request"
                onTriggered: root.applyApproval("on-request", "user")
              }
              MenuItem {
                text: "Untrusted only"
                checkable: true
                checked: root.approvalsReviewer !== "auto_review"
                  && root.approvalPolicy === "untrusted"
                onTriggered: root.applyApproval("untrusted", "user")
              }
              MenuItem {
                text: "Never ask"
                checkable: true
                checked: root.approvalsReviewer !== "auto_review"
                  && root.approvalPolicy === "never"
                onTriggered: root.applyApproval("never", "user")
              }
            }
          }

          Item { Layout.fillWidth: true }

          Button {
            id: sendButton
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            text: conversation.busy ? "■" : "↑"
            enabled: conversation.busy ? conversation.activeTurnId !== ""
              : (conversation.ready && composer.text.trim() !== "")
            onClicked: conversation.busy ? conversation.interrupt() : root.sendComposer()
            ToolTip.visible: hovered
            ToolTip.text: conversation.busy ? "Stop" : "Send"
            background: Rectangle {
              radius: 18
              color: sendButton.enabled ? root.accent : "#3a3a3a"
            }
            contentItem: Label {
              text: sendButton.text
              color: sendButton.enabled ? "white" : root.muted
              font.pixelSize: 19
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: conversation.approvalRequest !== null
    color: "#99000000"
    z: 20

    MouseArea { anchors.fill: parent }

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(560, parent.width - 60)
      height: approvalColumn.implicitHeight + 40
      radius: 16
      color: root.raised
      border.color: root.border

      ColumnLayout {
        id: approvalColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14

        Label {
          Layout.fillWidth: true
          text: conversation.approvalRequest
            ? String(conversation.approvalRequest.title || "Approval") : ""
          color: root.foreground
          font.pixelSize: 18
          font.weight: Font.DemiBold
        }

        ScrollView {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(220, approvalDetail.implicitHeight + 20)
          Label {
            id: approvalDetail
            width: parent.width
            text: conversation.approvalRequest
              ? String(conversation.approvalRequest.detail || "") : ""
            color: root.muted
            font.family: "monospace"
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
          }
        }

        CheckBox {
          visible: conversation.approvalRequest
            && conversation.approvalRequest.kind !== "unknown"
          text: "Remember for this session"
          checked: root.rememberApproval
          onToggled: root.rememberApproval = checked
          palette.text: root.foreground
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          Button {
            text: "Decline"
            onClicked: {
              conversation.answerApproval(false, false)
              root.rememberApproval = false
            }
          }
          Button {
            text: "Approve"
            highlighted: true
            onClicked: {
              conversation.answerApproval(true, root.rememberApproval)
              root.rememberApproval = false
            }
          }
        }
      }
    }
  }
}
