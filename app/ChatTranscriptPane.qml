import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions

Item {
  objectName: "chatTranscriptPane"
  required property var window
  required property var client

  function scrollPage(direction) { transcriptView.scrollPage(direction) }
  function scrollEdge(edge) { transcriptView.scrollEdge(edge) }
  Layout.fillWidth: true
  Layout.fillHeight: true

  WebTranscript {
    id: transcriptView
    objectName: "webTranscript"
    anchors.fill: parent
    messages: client.messages
    busy: client.busy
    loading: client.loading || !client.ready
    conversationTitle: client.activeThreadId === ""
      ? "New conversation" : "Thread " + client.activeThreadId.slice(0, 12)
    conversationDetail: window.workingDirectory + "  ·  "
      + ChatLaunchOptions.connectionLabel(window.remoteAddress)
  }

  BusyIndicator {
    anchors.centerIn: parent
    running: client.loading || !client.ready
    visible: running && client.messages.length === 0
  }
}
