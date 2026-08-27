import QtQuick
import Quickshell.Io
import "../logic/ProviderSnapshotLogic.js" as SnapshotLogic

Item {
  id: root

  required property string path
  property bool loaded: false
  property bool restored: false
  property bool hydrating: false
  property string encoded: ""
  property var pendingSnapshot: null

  signal restoreRequested(var snapshot)

  function attach(raw) {
    if (loaded) return
    encoded = String(raw || "")
    var snapshot = SnapshotLogic.decode(encoded)
    if (snapshot) {
      hydrating = true
      restoreRequested(snapshot)
      hydrating = false
      restored = true
    }
    loaded = true
    if (pendingSnapshot) schedule(pendingSnapshot)
  }

  function schedule(snapshot) {
    pendingSnapshot = snapshot
    if (!loaded || hydrating) return
    saveTimer.restart()
  }

  function flush(snapshot) {
    if (snapshot !== undefined) pendingSnapshot = snapshot
    if (!loaded || hydrating || !pendingSnapshot) return
    saveTimer.stop()
    var next = SnapshotLogic.encode(pendingSnapshot)
    if (next !== "" && next !== encoded) {
      encoded = next
      snapshotFile.setText(next)
    }
  }

  FileView {
    id: snapshotFile
    path: root.path
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.attach(text())
    onLoadFailed: root.attach("")
  }

  Timer {
    id: saveTimer
    interval: 100
    repeat: false
    onTriggered: root.flush()
  }
}
