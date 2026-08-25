import QtQuick

Item {
  id: root

  required property var renderer
  required property string content
  property color foreground: "#ececec"
  property string renderedContent: content
  property string renderRequestId: ""

  implicitHeight: markdown.implicitHeight

  function requestRender() {
    renderedContent = content
    renderRequestId = renderer.render(content)
  }

  Timer {
    id: renderDebounce
    interval: 120
    repeat: false
    onTriggered: root.requestRender()
  }

  Connections {
    target: root.renderer
    function onDocumentReady(requestId, value) {
      if (requestId === root.renderRequestId) root.renderedContent = value
    }
    function onDocumentFailed(requestId, errorText) {
      if (requestId === root.renderRequestId)
        console.warn("Agent Chat math document:", errorText)
    }
  }

  TextEdit {
    id: markdown
    width: parent.width
    height: implicitHeight
    readOnly: true
    selectByMouse: true
    persistentSelection: true
    textFormat: TextEdit.MarkdownText
    text: root.renderedContent
    color: root.foreground
    selectionColor: "#396b5f"
    selectedTextColor: "white"
    wrapMode: TextEdit.Wrap
    font.pixelSize: 15
    onLinkActivated: function(link) { Qt.openUrlExternally(link) }
  }

  onContentChanged: renderDebounce.restart()
  Component.onCompleted: requestRender()
}
