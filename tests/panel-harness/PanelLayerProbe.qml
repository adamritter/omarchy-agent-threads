// Purpose: Provides a controlled Panel Layer Probe harness for behavioral tests.
import QtQuick
import Quickshell.Io

Process {
  required property var harness
  property string purpose: ""
  running: false
  command: ["hyprctl", "layers", "-j"]

  function collectNamespaces(value, result) {
    if (Array.isArray(value)) {
      for (var index = 0; index < value.length; index++)
        collectNamespaces(value[index], result)
      return
    }
    if (!value || typeof value !== "object") return
    if (value.namespace !== undefined) result.push(String(value.namespace || ""))
    for (var key in value) collectNamespaces(value[key], result)
  }

  function layerCounts(text) {
    var parsed
    try { parsed = JSON.parse(String(text || "{}")) }
    catch (error) { return { valid: false, main: 0 } }
    var namespaces = []
    collectNamespaces(parsed, namespaces)
    var main = 0
    for (var index = 0; index < namespaces.length; index++) {
      if (namespaces[index] === "agent-threads-panel-test") main++
    }
    return { valid: true, main: main }
  }

  function handleResult(text) {
    var counts = layerCounts(text)
    if (!harness.check(counts.valid, "hyprctl returned invalid layer JSON")) return

    if (purpose === "first-visible") {
      if (!harness.check(counts.main > 0,
        "the first panel did not map its layer surface")) return
      harness.firstMainLayerCount = counts.main
      harness.panelInstance.overlayActions.setSearchText("Beta")
      harness.phase = 1
      return
    }

    if (purpose === "first-destroyed") {
      if (!harness.check(counts.main === 0,
        "destroyed panel left layer surfaces mapped")) return
      harness.phase = 3
      return
    }

    if (purpose === "second-visible") {
      if (!harness.check(counts.main === harness.firstMainLayerCount,
        "recreated panel mapped duplicate or missing layer surfaces")) return
      harness.panelInstance.close()
      harness.panelInstance.destroy()
      harness.panelInstance = null
      harness.phase = 40
      Qt.callLater(function() { harness.probeLayers("second-destroyed") })
      return
    }

    if (purpose === "second-destroyed") {
      if (!harness.check(counts.main === 0,
        "recreated panel left layer surfaces mapped")) return
      harness.finishSuccessfully()
    }
  }

  stdout: StdioCollector {
    waitForEnd: true
    onStreamFinished: handleResult(text)
  }

  onExited: function(exitCode) {
    if (exitCode !== 0) harness.abort("hyprctl layers failed with code " + exitCode)
  }
}
