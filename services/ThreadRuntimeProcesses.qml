import QtQuick
import Quickshell.Io

Item {
  id: root

  required property var controller

  readonly property bool threadStatusesRunning: threadStatusesProcess.running
  readonly property bool agentChatRunning: agentChatProcess.running
  readonly property bool terminalRunning: terminalOpenProcess.running

  property string agentChatLaunchKind: ""
  property string agentChatPendingThreadId: ""
  property int agentChatLaunchRequestId: 0
  property string agentChatErrorOutput: ""
  property string terminalErrorOutput: ""

  function startThreadStatuses(command) {
    if (threadStatusesProcess.running) return false
    threadStatusesProcess.command = command
    threadStatusesProcess.running = true
    return true
  }

  function startAgentChat(command, kind, threadId, requestId) {
    if (agentChatProcess.running) return false
    agentChatErrorOutput = ""
    agentChatLaunchKind = String(kind || "")
    agentChatPendingThreadId = String(threadId || "")
    agentChatLaunchRequestId = Number(requestId || 0)
    agentChatProcess.command = command
    agentChatProcess.running = true
    return true
  }

  function startTerminal(command) {
    if (terminalOpenProcess.running) return false
    terminalErrorOutput = ""
    terminalOpenProcess.command = command
    terminalOpenProcess.running = true
    return true
  }

  function scheduleEventRefresh() {
    eventRefresh.restart()
  }

  function shutdown() {
    eventRefresh.stop()
    rolloutStatusDebounce.stop()
    rolloutStructureDebounce.stop()
    rolloutSettleDebounce.stop()
    threadEventsRestart.stop()
    threadEventsProcess.running = false
  }

  Process {
    id: threadStatusesProcess
    running: false

    stdout: SplitParser {
      onRead: function(line) {
        try {
          root.controller.threadActions.applyThreadStatuses(JSON.parse(String(line || "{}")))
        } catch (error) {
          console.warn("Codex Threads: invalid thread statuses:", error)
        }
      }
    }
  }

  Process {
    id: agentChatProcess
    running: false
    stderr: SplitParser {
      onRead: function(line) {
        root.agentChatErrorOutput = (root.agentChatErrorOutput
          + String(line || "") + "\n").slice(-30000)
      }
    }
    onExited: function(exitCode) {
      var kind = root.agentChatLaunchKind
      var threadId = root.agentChatPendingThreadId
      var requestId = root.agentChatLaunchRequestId
      if (exitCode !== 0) {
        var message = root.agentChatErrorOutput.trim()
          || (kind === "thread"
            ? "Could not open the thread in Agent Chat"
            : "Could not open Agent Chat in the project")
        if (kind === "thread") root.controller.mutations.failThreadLaunch(requestId, message)
        else root.controller.launchError = message
      } else if (kind === "thread") {
        root.controller.mutations.confirmThreadLaunch(requestId, threadId)
      }

      if (kind === "project") root.controller.launchingProjectPath = ""
      root.agentChatLaunchKind = ""
      root.agentChatPendingThreadId = ""
      root.agentChatLaunchRequestId = 0
      root.scheduleEventRefresh()
    }
  }

  Process {
    id: terminalOpenProcess
    running: false
    stderr: SplitParser {
      onRead: function(line) {
        root.terminalErrorOutput = (root.terminalErrorOutput
          + String(line || "") + "\n").slice(-30000)
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.controller.launchError = root.terminalErrorOutput.trim()
          || "Could not open the terminal"
    }
  }

  Process {
    id: threadEventsProcess
    command: [root.controller.threadEventsHelperPath]
    running: true

    stdout: SplitParser {
      onRead: function(line) {
        var event = String(line || "")
        if (event.indexOf("rollout-") < 0) return

        // A rollout can receive many writes per second. Status stays live, but
        // the heavier list refresh waits until the burst settles. New files
        // are listed immediately so externally-created threads appear quickly.
        rolloutStatusDebounce.restart()
        rolloutSettleDebounce.restart()
        if (event.indexOf("CREATE") >= 0 || event.indexOf("MOVED_TO") >= 0)
          rolloutStructureDebounce.restart()
      }
    }

    onExited: if (!root.controller.shuttingDown)
      threadEventsRestart.restart()
  }

  Timer {
    // App Server events normally refresh immediately; polling is the fallback
    // if inotify or an App Server event is ever missed.
    interval: 60000
    running: root.controller.providers.ready
    repeat: true
    onTriggered: {
      root.controller.providers.refreshThreads()
      root.controller.threadActions.refreshThreadStatuses()
      root.controller.threadActions.refreshActiveThread()
    }
  }

  Timer {
    interval: 900000
    running: root.controller.providers.ready
    repeat: true
    onTriggered: root.controller.providers.refreshRateLimits()
  }

  Timer {
    id: eventRefresh
    interval: 350
    repeat: false
    onTriggered: root.controller.providers.refreshThreads()
  }

  Timer {
    id: rolloutStatusDebounce
    interval: 750
    repeat: false
    onTriggered: root.controller.threadActions.refreshThreadStatuses()
  }

  Timer {
    id: rolloutStructureDebounce
    interval: 200
    repeat: false
    onTriggered: {
      root.controller.threadActions.refreshActiveThread()
      eventRefresh.restart()
    }
  }

  Timer {
    id: rolloutSettleDebounce
    interval: 2000
    repeat: false
    onTriggered: eventRefresh.restart()
  }

  Timer {
    id: threadEventsRestart
    interval: 1500
    repeat: false
    onTriggered: if (!root.controller.shuttingDown && !threadEventsProcess.running)
      threadEventsProcess.running = true
  }
}
