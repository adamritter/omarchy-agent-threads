import QtQuick
import Quickshell.Io

Item {
  id: root

  required property var controller
  required property string providerType
  required property string label
  readonly property bool enabled: String(controller.selectedProvider || "codex") === providerType
  property string serverUrl: "http://127.0.0.1:43962"
  readonly property string hostId: "provider-" + providerType
  property var host: ({
    id: hostId,
    label: label,
    providerType: providerType,
    type: "provider",
    home: controller.localHome,
    threads: [],
    projects: [],
    models: [],
    agents: [],
    loading: true,
    error: ""
  })
  property string actionHostId: ""
  property string actionKind: ""
  property string actionThreadId: ""
  property bool actionPinValue: false
  property bool openIsNew: false
  property string pendingPath: ""
  property var pendingKnownIds: ({})
  property string pendingWindowAddress: ""
  property string pendingServerUrl: ""
  property int pendingAttempts: 0
  property int serverRestartAttempts: 0
  property string lastSnapshotSignature: ""

  readonly property string queryHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-provider-query").toString().replace(/^file:\/\//, "")
  readonly property string openHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-thread-open").toString().replace(/^file:\/\//, "")
  readonly property string mapThreadWindowHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-map-thread-window").toString().replace(/^file:\/\//, "")

  function pathForThread(thread) {
    return String(thread && thread.cwd || host.home || controller.localHome)
  }

  function threadStatus(thread) {
    var status = thread ? thread.status : null
    var type = typeof status === "string" ? status : String(status && status.type || "")
    return type === "active" ? "busy" : "done"
  }

  function threadById(items, threadId) {
    var wanted = String(threadId || "")
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") === wanted) return items[i]
    }
    return null
  }

  function mergeUnread(nextThreads) {
    var previous = host.threads || []
    var merged = []
    for (var i = 0; i < nextThreads.length; i++) {
      var next = nextThreads[i]
      var id = String(next && next.id || "")
      var old = threadById(previous, id)
      var wasBusy = old && threadStatus(old) === "busy"
      var nowBusy = threadStatus(next) === "busy"
      var unread = next.attention === true || (old && old.unread === true)
      if (wasBusy && !nowBusy && id !== controller.activeThreadId) unread = true
      if (id === controller.activeThreadId) unread = false
      merged.push(Object.assign({}, next, { unread: unread }))
    }
    return merged
  }

  function markThreadSeen(threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return
    var threads = host.threads || []
    var changed = false
    var next = []
    for (var i = 0; i < threads.length; i++) {
      var thread = threads[i]
      if (String(thread && thread.id || "") === wanted && thread.unread === true) {
        next.push(Object.assign({}, thread, { unread: false }))
        changed = true
      } else next.push(thread)
    }
    if (changed) host = Object.assign({}, host, { threads: next })
  }

  function refresh() {
    if (!enabled || controller.shuttingDown || queryProcess.running) return
    queryProcess.command = [queryHelperPath, providerType, "snapshot"]
    queryProcess.running = true
  }

  function activate() {
    if (!enabled || controller.shuttingDown) return
    host = Object.assign({}, host, { loading: true, error: "" })
    serverRestartAttempts = 0
    if (providerType === "opencode") serverProcess.running = true
    initialRefreshTimer.restart()
  }

  function deactivate() {
    initialRefreshTimer.stop()
    serverRestartTimer.stop()
    queryProcess.running = false
    if (providerType === "opencode") serverProcess.running = false
    if (host.loading === true)
      host = Object.assign({}, host, { loading: false })
  }

  function applySnapshot(snapshot) {
    var nextThreads = Array.isArray(snapshot.threads) ? snapshot.threads : []
    var nextProjects = Array.isArray(snapshot.projects) ? snapshot.projects : []
    var nextModels = Array.isArray(snapshot.models) ? snapshot.models : []
    var nextAgents = Array.isArray(snapshot.agents) ? snapshot.agents : []
    var nextHome = String(snapshot.home || host.home || controller.localHome)
    var signature = JSON.stringify({
      home: nextHome,
      threads: nextThreads,
      projects: nextProjects,
      projectDefaults: snapshot.projectDefaults,
      projectAgents: snapshot.projectAgents,
      models: nextModels,
      agents: nextAgents,
      defaultModel: snapshot.defaultModel,
      defaultEffort: snapshot.defaultEffort,
      defaultAgent: snapshot.defaultAgent,
      available: snapshot.available,
      authenticated: snapshot.authenticated,
      version: snapshot.version,
      subscriptionType: snapshot.subscriptionType,
      error: snapshot.error
    })
    if (signature === lastSnapshotSignature) {
      if (host.loading === true)
        host = Object.assign({}, host, { loading: false })
      resolvePendingNew()
      return
    }
    lastSnapshotSignature = signature
    host = Object.assign({}, host, snapshot, {
      id: hostId,
      label: label,
      providerType: providerType,
      type: "provider",
      home: nextHome,
      threads: mergeUnread(nextThreads),
      projects: nextProjects,
      models: nextModels,
      agents: nextAgents,
      loading: false,
      error: String(snapshot.error || "")
    })
    resolvePendingNew()
  }

  function archiveThread(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running) return
    actionKind = "archive"
    actionThreadId = id
    actionHostId = hostId
    controller.archivingThreadId = id
    controller.launchError = ""
    actionProcess.command = [queryHelperPath, providerType, "archive", id, pathForThread(thread)]
    actionProcess.running = true
  }

  function toggleThreadPin(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running) return
    actionKind = "pin"
    actionThreadId = id
    actionPinValue = !(thread && thread.isPinned === true)
    actionHostId = hostId
    controller.pinningThreadId = id
    controller.launchError = ""
    controller.pendingPinValue = actionPinValue
    actionProcess.command = [
      queryHelperPath,
      providerType,
      "pin",
      id,
      pathForThread(thread),
      actionPinValue ? "true" : "false"
    ]
    actionProcess.running = true
  }

  function openThread(thread, directory) {
    if (!thread || !thread.id || openProcess.running) return
    openIsNew = false
    controller.launchingThreadId = String(thread.id)
    controller.launchError = ""
    openProcess.command = [
      openHelperPath,
      providerType,
      String(directory || pathForThread(thread)),
      controller.launchingThreadId,
      serverUrl,
      controller.selectedModelForProvider(providerType),
      controller.selectedEffortForProvider(providerType),
      controller.selectedAgentForProvider(providerType)
    ]
    openProcess.running = true
    controller.threadLaunchRequested(controller.launchingThreadId)
  }

  function newThread(directory) {
    if (openProcess.running) return
    var target = String(directory || host.home || controller.localHome)
    pendingPath = target
    pendingWindowAddress = ""
    pendingServerUrl = ""
    pendingAttempts = 60
    pendingKnownIds = ({})
    var threads = host.threads || []
    for (var i = 0; i < threads.length; i++) {
      if (threads[i] && threads[i].id) pendingKnownIds[String(threads[i].id)] = true
    }
    openIsNew = true
    controller.launchingProjectPath = target
    controller.launchError = ""
    openProcess.command = [
      openHelperPath,
      providerType,
      target,
      "",
      serverUrl,
      controller.selectedModelForProvider(providerType),
      controller.selectedEffortForProvider(providerType),
      controller.selectedAgentForProvider(providerType)
    ]
    openProcess.running = true
  }

  function clearPendingNew() {
    openIsNew = false
    pendingPath = ""
    pendingKnownIds = ({})
    pendingWindowAddress = ""
    pendingServerUrl = ""
    pendingAttempts = 0
    controller.launchingProjectPath = ""
    newResolveTimer.stop()
  }

  function resolvePendingNew() {
    if (pendingPath === "" || pendingWindowAddress === "") return
    var threads = host.threads || []
    for (var i = 0; i < threads.length; i++) {
      var thread = threads[i]
      var id = String(thread && thread.id || "")
      if (id === "" || pendingKnownIds[id] === true) continue
      if (pathForThread(thread) !== pendingPath) continue
      mapThreadWindowProcess.command = [
        mapThreadWindowHelperPath,
        id,
        pendingWindowAddress,
        hostId,
        pendingServerUrl
      ]
      mapThreadWindowProcess.running = true
      controller.activeThreadId = id
      clearPendingNew()
      return
    }
  }

  Process {
    id: queryProcess
    running: false

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.host = Object.assign({}, root.host, {
          loading: false,
          error: queryStderr.text.trim() || "Could not load " + root.label + " sessions"
        })
        return
      }
      try {
        root.applySnapshot(JSON.parse(String(queryStdout.text || "{}").trim()))
      } catch (error) {
        root.host = Object.assign({}, root.host, { loading: false, error: "Invalid provider response" })
      }
    }

    stdout: StdioCollector { id: queryStdout; waitForEnd: true }
    stderr: StdioCollector { id: queryStderr; waitForEnd: true }
  }

  Process {
    id: actionProcess
    running: false

    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.controller.launchError = actionStderr.text.trim() || root.label + " action failed"
      if (root.actionKind === "archive") root.controller.archivingThreadId = ""
      if (root.actionKind === "pin") {
        root.controller.pinningThreadId = ""
        root.controller.pendingPinValue = false
      }
      root.actionKind = ""
      root.actionThreadId = ""
      root.actionHostId = ""
      root.refresh()
    }

    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
  }

  Process {
    id: openProcess
    running: false

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.controller.launchError = openStderr.text.trim() || "Could not open " + root.label
        root.controller.launchingThreadId = ""
        if (root.openIsNew) root.clearPendingNew()
        return
      }
      var output = String(openStdout.text || "").trim()
      var address = output
      var runtimeServer = ""
      var runtimeSessionId = ""
      try {
        var result = JSON.parse(output)
        address = String(result.address || "")
        runtimeServer = String(result.serverUrl || "")
        runtimeSessionId = String(result.sessionId || "")
      } catch (error) {
        // Compatibility with the older helper which returned only the address.
      }
      if (root.openIsNew) {
        if (runtimeSessionId !== "" && address !== "") {
          mapThreadWindowProcess.command = [
            root.mapThreadWindowHelperPath,
            runtimeSessionId,
            address,
            root.hostId,
            runtimeServer
          ]
          mapThreadWindowProcess.running = true
          root.controller.activeThreadId = runtimeSessionId
          root.clearPendingNew()
        } else {
          root.pendingWindowAddress = address
          root.pendingServerUrl = runtimeServer
          newResolveTimer.restart()
        }
      } else {
        root.controller.activeThreadId = root.controller.launchingThreadId
        root.controller.launchingThreadId = ""
      }
      root.controller.refreshActiveThread()
      root.refresh()
    }

    stdout: StdioCollector { id: openStdout; waitForEnd: true }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }

  Process { id: mapThreadWindowProcess; running: false }

  Connections {
    target: root.controller
    function onActiveThreadIdChanged() {
      root.markThreadSeen(root.controller.activeThreadId)
    }
  }

  Process {
    id: serverProcess
    running: false
    command: ["opencode", "serve", "--hostname", "127.0.0.1", "--port", "43962"]
    onExited: {
      if (!root.enabled || root.controller.shuttingDown || root.providerType !== "opencode")
        return
      root.serverRestartAttempts++
      if (root.serverRestartAttempts < 3) serverRestartTimer.restart()
      else root.host = Object.assign({}, root.host, {
        loading: false,
        error: "OpenCode server could not start"
      })
    }
  }

  Timer {
    interval: 5000
    running: root.enabled
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: initialRefreshTimer
    interval: root.providerType === "opencode" ? 600 : 1
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: serverRestartTimer
    interval: 1500
    repeat: false
    onTriggered: if (root.enabled && !root.controller.shuttingDown
        && root.providerType === "opencode")
      serverProcess.running = true
  }

  Timer {
    id: newResolveTimer
    interval: 500
    repeat: true
    onTriggered: {
      root.pendingAttempts--
      root.refresh()
      root.resolvePendingNew()
      if (root.pendingPath === "") stop()
      else if (root.pendingAttempts <= 0) {
        root.controller.launchError = "The new " + root.label + " session did not appear in time"
        root.clearPendingNew()
      }
    }
  }

  onEnabledChanged: if (enabled) activate(); else deactivate()

  Component.onCompleted: if (enabled) activate()

  Component.onDestruction: {
    queryProcess.running = false
    actionProcess.running = false
    openProcess.running = false
    serverProcess.running = false
  }
}
