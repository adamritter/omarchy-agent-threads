import QtQuick
import Quickshell.Io

Item {
  id: root

  property bool ready: false
  property var queuedRequests: []
  property int nextRequestId: 1
  readonly property string helperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-math-render").toString().replace(/^file:\/\//, "")

  signal documentReady(string requestId, string markdown)
  signal documentFailed(string requestId, string errorText)

  function render(content) {
    var requestId = "math-" + nextRequestId++
    var request = { requestId: requestId, content: String(content || "") }
    if (ready) send(request)
    else queuedRequests = queuedRequests.concat([request])
    return requestId
  }

  function send(request) {
    renderer.write(JSON.stringify(request) + "\n")
  }

  function flushQueue() {
    var requests = queuedRequests
    queuedRequests = []
    for (var i = 0; i < requests.length; i++) send(requests[i])
  }

  function handleLine(line) {
    var value = String(line || "").trim()
    if (value === "") return
    try {
      var result = JSON.parse(value)
      if (result.error) documentFailed(String(result.requestId || ""), String(result.error))
      else documentReady(String(result.requestId || ""), String(result.markdown || ""))
    } catch (error) {
      console.warn("Agent Chat: invalid math renderer response")
    }
  }

  Process {
    id: renderer
    command: [root.helperPath]
    running: true
    stdinEnabled: true
    onStarted: {
      root.ready = true
      root.flushQueue()
    }
    onExited: root.ready = false
    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (value !== "") console.warn("Agent Chat math renderer:", value)
      }
    }
  }
}
