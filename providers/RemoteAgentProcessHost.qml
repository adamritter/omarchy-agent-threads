import QtQuick
import Quickshell.Io

Item {
  required property var provider
  required property var launches
  readonly property alias queryRunning: queryProcess.running
  readonly property alias actionRunning: actionProcess.running
  readonly property alias testRunning: managementTestProcess.running
  readonly property alias openRunning: openProcess.running
  readonly property alias sshHostsRunning: sshHostsProcess.running

  function guarded(command) {
    return [provider.controller.streamGuardPath, "--"].concat(command)
  }
  function runQuery(command) { queryProcess.command = guarded(command); queryProcess.running = true }
  function runAction(command) { actionProcess.command = guarded(command); actionProcess.running = true }
  function runTest(command) { managementTestProcess.command = guarded(command); managementTestProcess.running = true }
  function runOpen(command) { openProcess.command = guarded(command); openProcess.running = true }
  function runSshHosts(command) { sshHostsProcess.command = guarded(command); sshHostsProcess.running = true }
  function stopAll() {
    queryProcess.running = false
    actionProcess.running = false
    managementTestProcess.running = false
    openProcess.running = false
    sshHostsProcess.running = false
  }

  Process {
    id: queryProcess
    running: false
  
    onExited: function(exitCode) {
      var hostId = provider.queryHostId
      if (exitCode !== 0) {
        var failedHost = provider.hostById(hostId)
        provider.updateHost(hostId, {
          loading: false,
          error: queryStderr.text.trim()
            || "Could not load remote " + provider.providerLabel(failedHost) + " threads"
        })
      } else {
        try {
          provider.applySnapshot(JSON.parse(String(queryStdout.text || "{}").trim()))
        } catch (error) {
          provider.updateHost(hostId, { loading: false, error: "Invalid remote response" })
        }
      }
      provider.queryHostId = ""
      Qt.callLater(provider.startNextQuery)
    }
  
    stdout: StdioCollector { id: queryStdout; waitForEnd: true }
    stderr: StdioCollector { id: queryStderr; waitForEnd: true }
  }
  
  Process {
    id: actionProcess
    running: false
  
    onExited: function(exitCode) {
      var hostId = provider.actionHostId
      var kind = provider.actionKind
      if (exitCode !== 0) {
        var failedHost = provider.hostById(hostId)
        var message = actionStderr.text.trim()
          || "Remote " + provider.providerLabel(failedHost) + " action failed"
        if (kind === "archive") provider.restoreArchivedThread(hostId)
        provider.controller.mutations.failThreadMutation(kind, message)
      } else if (kind === "archive") {
        provider.archiveConfirmationHostId = hostId
        provider.archiveConfirmationThreadId = provider.archivedThreadId
        provider.archivedThreadId = ""
        provider.archivedThreadSnapshot = null
        provider.archivedThreadIndex = -1
      } else if (kind === "pin") {
        var response = null
        try {
          response = JSON.parse(String(actionStdout.text || "{}").trim())
        } catch (error) {
          response = null
        }
        provider.applyThreadPin(hostId, provider.actionThreadId, provider.actionPinValue,
          response ? response.thread : null)
      }
      if (exitCode === 0) provider.controller.mutations.finishThreadMutation(kind)
      provider.actionHostId = ""
      provider.actionKind = ""
      provider.actionThreadId = ""
      provider.actionPinValue = false
      if (exitCode === 0) provider.refresh(hostId)
    }
  
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
  }
  
  Process {
    id: managementTestProcess
    running: false
  
    onExited: function(exitCode) {
      provider.managementTestRunning = false
      if (exitCode !== 0) {
        provider.managementTestSucceeded = false
        provider.managementTestMessage = managementTestStderr.text.trim()
          || "Connection failed"
        provider.updateHost(provider.managementTestHostId, {
          error: provider.managementTestMessage,
          loading: false
        })
        return
      }
      try {
        var snapshot = JSON.parse(String(managementTestStdout.text || "{}").trim())
        provider.applySnapshot(snapshot)
        var readinessError = String(snapshot.error || "").trim()
        if (snapshot.available === false || snapshot.authenticated === false
            || readinessError !== "") {
          provider.managementTestSucceeded = false
          provider.managementTestMessage = "Connected · "
            + (readinessError !== "" ? readinessError
              : (snapshot.authenticated === false
                ? "The provider is not authenticated" : "The provider is unavailable"))
          return
        }
        var count = Array.isArray(snapshot.threads) ? snapshot.threads.length : 0
        var version = String(snapshot.version || "")
        provider.managementTestSucceeded = true
        provider.managementTestMessage = "Connection healthy · " + count + " threads"
          + (version !== "" ? " · " + version : "")
      } catch (error) {
        provider.managementTestSucceeded = false
        provider.managementTestMessage = "Invalid remote response"
      }
    }
  
    stdout: StdioCollector { id: managementTestStdout; waitForEnd: true }
    stderr: StdioCollector { id: managementTestStderr; waitForEnd: true }
  }
  
  Process {
    id: openProcess
    running: false
  
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var failedHost = provider.hostById(provider.openHostId)
        var message = openStderr.text.trim()
          || "Could not open remote " + provider.providerLabel(failedHost)
        if (!provider.openIsNew)
          provider.controller.mutations.failThreadLaunch(provider.openRequestId, message)
        else provider.controller.launchError = message
        provider.openRequestId = 0
        provider.openThreadId = ""
        if (provider.openIsNew) provider.clearPendingNew()
        else provider.openHostId = ""
        return
      }
      var result = launches.parseOutput(openStdout.text)
      var address = result.address
      var runtimeSessionId = result.sessionId
      if (provider.openIsNew) {
        if (runtimeSessionId !== "" && address !== "") {
          launches.map(runtimeSessionId, address, provider.pendingHostId, "")
          provider.controller.mutations.observeActiveThread(runtimeSessionId, "new-remote-thread")
          provider.clearPendingNew()
        } else {
          provider.pendingWindowAddress = address
          provider.refresh(provider.pendingHostId)
          provider.restartNewResolveTimer()
        }
      } else {
        launches.map(
          provider.openThreadId || runtimeSessionId,
          address,
          provider.openHostId,
          result.serverUrl)
        provider.controller.mutations.confirmThreadLaunch(provider.openRequestId, "")
        provider.openRequestId = 0
        provider.openThreadId = ""
        provider.openHostId = ""
      }
      provider.controller.threadActions.refreshActiveThread()
    }
  
    stdout: StdioCollector { id: openStdout; waitForEnd: true }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }
  Process {
    id: sshHostsProcess
    running: false
  
    onExited: function(exitCode) {
      provider.sshHostsLoading = false
      if (exitCode !== 0) {
        provider.sshHosts = []
        provider.sshHostsError = sshHostsStderr.text.trim() || "Could not read SSH hosts"
        return
      }
      try {
        var parsed = JSON.parse(String(sshHostsStdout.text || "[]").trim())
        provider.sshHosts = Array.isArray(parsed) ? parsed : []
        provider.sshHostsError = ""
      } catch (error) {
        provider.sshHosts = []
        provider.sshHostsError = "Invalid SSH config response"
      }
    }
  
    stdout: StdioCollector { id: sshHostsStdout; waitForEnd: true }
    stderr: StdioCollector { id: sshHostsStderr; waitForEnd: true }
  }

  Component.onDestruction: stopAll()
}
