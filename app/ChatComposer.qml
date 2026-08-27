import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../logic/CodexConversationLogic.js" as ConversationLogic

Item {
  id: root
  required property var window
  required property var client
  property alias text: editor.text
  function forceActiveFocus() { editor.forceActiveFocus() }
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
    height: Math.max(88, Math.min(204, editor.implicitHeight + 54))
    radius: 20
    color: window.raised
    border.color: editor.activeFocus ? "#555555" : window.border

    TextArea {
      id: editor
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: composerToolbar.top
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.topMargin: 10
      anchors.bottomMargin: 4
      color: window.foreground
      placeholderText: client.ready ? "Message Codex" : "Connecting to Codex..."
      placeholderTextColor: window.muted
      wrapMode: TextEdit.Wrap
      onTextChanged: {
        var bounded = ConversationLogic.boundedPromptInput(text)
        if (bounded === text) return
        var position = cursorPosition
        text = bounded
        cursorPosition = Math.min(position, text.length)
      }
      enabled: client.ready && !client.loading
      background: Item {}
      font.pixelSize: 14
      Keys.onReturnPressed: function(event) {
        if (event.modifiers & Qt.ShiftModifier) {
          event.accepted = false
          return
        }
        window.sendComposer()
        event.accepted = true
      }
    }

    ChatComposerToolbar {
      id: composerToolbar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      anchors.bottomMargin: 8
      window: root.window
      client: root.client
      composer: root
    }
  }
}
