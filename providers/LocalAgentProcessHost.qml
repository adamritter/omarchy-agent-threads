import QtQuick
import Quickshell.Io

Item {
  required property var provider
  required property var launches
  readonly property alias queryRunning: queryProcess.running
  readonly property alias actionRunning: actionProcess.running
  readonly property alias openRunning: openProcess.running

  function guarded(command) {
    var child = command
    if (provider.providerType === "opencode") child = [
      "env", "OMARCHY_OPENCODE_AUTH_FILE=" + provider.openCodeAuthFile
    ].concat(command)
    return [provider.controller.streamGuardPath, "--"].concat(child)
  }
  function runQuery(command) {
    queryProcess.command = guarded(command)
    queryProcess.running = true
  }
  function runAction(command) {
    actionProcess.command = guarded(command)
    actionProcess.running = true
  }
  function runOpen(command) {
    openProcess.command = guarded(command)
    openProcess.running = true
  }
  function stopQuery() { queryProcess.running = false }
  function stopAll() {
    queryProcess.running = false
    actionProcess.running = false
    openProcess.running = false
  }

  function archiveThread(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running
        || !provider.controller.mutations.beginThreadMutation("archive", id)) return false
    provider.actionKind = "archive"
    provider.actionHostId = provider.hostId
    runAction([provider.queryHelperPath, provider.providerType, "archive", id,
      provider.pathForThread(thread)])
    return true
  }
  
  function renameThread(thread, name) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running
        || !provider.controller.mutations.beginThreadMutation("rename", id)) return false
    provider.actionKind = "rename"
    provider.actionHostId = provider.hostId
    runAction([
      provider.queryHelperPath, provider.providerType, "rename", id, provider.pathForThread(thread), name
    ])
    return true
  }
  
  function toggleThreadPin(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running
        || !provider.controller.mutations.beginThreadMutation("pin", id)) return false
    provider.actionKind = "pin"
    provider.actionPinValue = !(thread && thread.isPinned === true)
    provider.actionHostId = provider.hostId
    provider.controller.mutations.setPendingPinValue(provider.actionPinValue)
    runAction([
      provider.queryHelperPath,
      provider.providerType,
      "pin",
      id,
      provider.pathForThread(thread),
      provider.actionPinValue ? "true" : "false"
    ])
    return true
  }

  Process {
    id: queryProcess
    running: false
  
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        provider.host = Object.assign({}, provider.host, {
          loading: false,
          error: queryStderr.text.trim() || "Could not load " + provider.label + " sessions"
        })
        return
      }
      try {
        provider.applySnapshot(JSON.parse(String(queryStdout.text || "{}").trim()))
      } catch (error) {
        provider.host = Object.assign({}, provider.host, { loading: false, error: "Invalid provider response" })
      }
    }
  
    stdout: StdioCollector { id: queryStdout; waitForEnd: true }
    stderr: StdioCollector { id: queryStderr; waitForEnd: true }
  }
  
  Process {
    id: actionProcess
    running: false
  
    onExited: function(exitCode) {
      var kind = provider.actionKind
      if (exitCode !== 0) provider.controller.mutations.failThreadMutation(
        kind, actionStderr.text.trim() || provider.label + " action failed")
      else provider.controller.mutations.finishThreadMutation(kind)
      provider.actionKind = ""
      provider.actionHostId = ""
      provider.refresh()
    }
  
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
  }
  
  Process {
    id: openProcess
    running: false
  
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (!provider.openIsNew) provider.controller.mutations.failThreadLaunch(
          launches.state.openRequestId,
          openStderr.text.trim() || "Could not open " + provider.label)
        launches.state.clearOpen()
        if (provider.openIsNew) provider.clearPendingNew()
        return
      }
      var result = launches.parseOutput(openStdout.text)
      var address = result.address
      var runtimeServer = result.serverUrl
      var runtimeSessionId = result.sessionId
      if (provider.openIsNew) {
        if (runtimeSessionId !== "" && address !== "") {
          launches.map(runtimeSessionId, address, provider.hostId, runtimeServer)
          provider.controller.mutations.observeActiveThread(
            runtimeSessionId, "new-local-provider-thread")
          provider.clearPendingNew()
        } else {
          launches.state.recordPendingOutput(address, runtimeSessionId, runtimeServer)
          provider.restartNewResolveTimer()
        }
      } else {
        launches.map(
          launches.state.openThreadId || runtimeSessionId,
          address,
          provider.hostId,
          runtimeServer)
        provider.controller.mutations.confirmThreadLaunch(
          launches.state.openRequestId, "")
        launches.state.clearOpen()
      }
      provider.controller.threadActions.refreshActiveThread()
      provider.refresh()
    }
  
    stdout: StdioCollector { id: openStdout; waitForEnd: true }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }

  Component.onDestruction: stopAll()
}
