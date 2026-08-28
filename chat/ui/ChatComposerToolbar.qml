import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
  id: composerToolbar
  objectName: "chatComposerToolbar"
  required property var window
  required property var client
  required property var composer
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
    objectName: "newChatButton"
    Layout.preferredWidth: 34
    Layout.preferredHeight: 34
    text: "+"
    font.pixelSize: 20
    ToolTip.visible: hovered
    ToolTip.text: "New conversation"
    onClicked: window.newConversation()
    background: Rectangle {
      radius: 10
      color: newChatButton.hovered ? window.hover : "transparent"
    }
    contentItem: Label {
      text: newChatButton.text
      color: window.muted
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font: newChatButton.font
    }
  }

  ComboBox {
    id: modelSelector
    objectName: "modelSelector"
    Layout.fillWidth: true
    Layout.minimumWidth: 72
    Layout.preferredWidth: 150
    Layout.maximumWidth: 190
    Layout.preferredHeight: 34
    model: window.modelChoices()
    textRole: "label"
    currentIndex: window.choiceIndex(model, window.selectedModel)
    onActivated: function(index) { window.selectedModel = model[index].id }
    ToolTip.visible: hovered
    ToolTip.text: window.selectedModel !== "" ? window.selectedModel
      : "Default model · " + (window.agentModelState().defaultModel || "Codex")
    palette.text: window.foreground
    palette.buttonText: window.foreground
    palette.button: window.raised
    palette.window: window.raised
    palette.highlight: window.hover
    palette.highlightedText: window.foreground
    background: Rectangle {
      radius: 10
      color: modelSelector.hovered ? window.hover : "transparent"
    }
  }

  ComboBox {
    id: effortSelector
    objectName: "effortSelector"
    Layout.preferredWidth: 78
    Layout.preferredHeight: 34
    model: window.effortChoices()
    textRole: "label"
    currentIndex: window.choiceIndex(model, window.selectedEffort)
    onActivated: function(index) { window.selectedEffort = model[index].id }
    ToolTip.visible: hovered
    ToolTip.text: (window.selectedEffort !== "" ? window.selectedEffort
      : "Default effort · " + (window.agentModelState(window.selectedModel).defaultEffort
        || "Codex")) + " · Super+Ctrl+E"
    palette.text: window.foreground
    palette.buttonText: window.foreground
    palette.button: window.raised
    palette.window: window.raised
    palette.highlight: window.hover
    palette.highlightedText: window.foreground
    background: Rectangle {
      radius: 10
      color: effortSelector.hovered ? window.hover : "transparent"
    }
  }

  Button {
    id: fastButton
    objectName: "fastButton"
    Layout.preferredWidth: 34
    Layout.preferredHeight: 34
    text: "⚡︎"
    font.pixelSize: 16
    ToolTip.visible: hovered
    ToolTip.text: "Fast responses: "
      + (window.serviceTier === "fast" ? "On" : "Off")
      + " · Super+Ctrl+F"
    onClicked: window.serviceTier = window.serviceTier === "fast" ? "default" : "fast"
    background: Rectangle {
      radius: 10
      color: window.serviceTier === "fast" ? window.accent
        : (fastButton.hovered ? window.hover : "transparent")
    }
    contentItem: Label {
      text: fastButton.text
      color: window.serviceTier === "fast" ? "white" : window.muted
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font: fastButton.font
    }
  }

  Button {
    id: approveForMeButton
    objectName: "approveForMeButton"
    Layout.preferredWidth: 122
    Layout.preferredHeight: 34
    text: "✓  Approve for me"
    font.pixelSize: 12
    ToolTip.visible: hovered
    ToolTip.text: "Approve for me: "
      + (window.approvalsReviewer === "auto_review" ? "On" : "Off")
    onClicked: window.approvalsReviewer === "auto_review"
      ? window.applyApproval("", "user")
      : window.applyApproval("on-request", "auto_review")
    background: Rectangle {
      radius: 10
      color: window.approvalsReviewer === "auto_review" ? window.accent
        : (approveForMeButton.hovered ? window.hover : "transparent")
    }
    contentItem: Label {
      text: approveForMeButton.text
      color: window.approvalsReviewer === "auto_review" ? "white" : window.muted
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font: approveForMeButton.font
    }
  }

  Button {
    id: optionsButton
    objectName: "optionsButton"
    Layout.preferredWidth: 34
    Layout.preferredHeight: 34
    text: "⋯"
    font.pixelSize: 20
    ToolTip.visible: hovered
    ToolTip.text: window.approvalStatus()
    onClicked: optionsMenu.open()
    background: Rectangle {
      radius: 10
      color: optionsButton.hovered || optionsMenu.visible ? window.hover : "transparent"
    }
    contentItem: Label {
      text: optionsButton.text
      color: window.muted
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      font: optionsButton.font
    }

    Menu {
      id: optionsMenu
      objectName: "optionsMenu"
      y: -height - 6
      palette.window: window.raised
      palette.text: window.foreground
      palette.highlight: window.hover
      palette.highlightedText: window.foreground

      MenuItem {
        text: "Default approvals"
        checkable: true
        checked: window.approvalsReviewer !== "auto_review"
          && window.approvalPolicy === ""
        onTriggered: window.applyApproval("", "user")
      }
      MenuItem {
        text: "Ask as needed"
        checkable: true
        checked: window.approvalsReviewer !== "auto_review"
          && window.approvalPolicy === "on-request"
        onTriggered: window.applyApproval("on-request", "user")
      }
      MenuItem {
        text: "Untrusted only"
        checkable: true
        checked: window.approvalsReviewer !== "auto_review"
          && window.approvalPolicy === "untrusted"
        onTriggered: window.applyApproval("untrusted", "user")
      }
      MenuItem {
        text: "Never ask"
        checkable: true
        checked: window.approvalsReviewer !== "auto_review"
          && window.approvalPolicy === "never"
        onTriggered: window.applyApproval("never", "user")
      }
    }
  }

  Item { Layout.fillWidth: true }

  Button {
    id: sendButton
    objectName: "sendButton"
    Layout.preferredWidth: 36
    Layout.preferredHeight: 36
    text: client.busy ? "■" : "↑"
    enabled: client.busy ? client.activeTurnId !== ""
      : (client.ready && composer.text.trim() !== "")
    onClicked: client.busy ? client.interrupt() : window.sendComposer()
    ToolTip.visible: hovered
    ToolTip.text: client.busy ? "Stop" : "Send"
    background: Rectangle {
      radius: 18
      color: sendButton.enabled ? window.accent : "#3a3a3a"
    }
    contentItem: Label {
      text: sendButton.text
      color: sendButton.enabled ? "white" : window.muted
      font.pixelSize: 19
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
