import QtQuick
import Quickshell.Io
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

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
  property bool actionPinValue: false
  property bool openIsNew: false
  property string pendingPath: ""
  property var pendingKnownIds: ({})
  property string pendingWindowAddress: ""
  property string pendingServerUrl: ""
  property int pendingAttempts: 0
  property int serverRestartAttempts: 0
  property string lastSnapshotSignature: ""
  property int openRequestId: 0

  readonly property string queryHelperPath:
    Qt.resolvedUrl("../bin/omarchy-agent-provider-query").toString().replace(/^file:\/\//, "")
  readonly property string openHelperPath:
    Qt.resolvedUrl("../bin/omarchy-agent-thread-open").toString().replace(/^file:\/\//, "")

  ThreadLaunchCoordinator { id: launchCoordinator }

  function pathForThread(thread) {
    return String(thread && thread.cwd || host.home || controller.localHome)
  }

  function threadStatus(thread) {
    return ThreadStateLogic.remoteStatusValue(thread ? thread.status : null)
  }

  function restoreSnapshot(snapshot) {
    if (!snapshot || String(snapshot.providerType || "") !== providerType) return
    host = ProviderSnapshotLogic.hydratedHost(snapshot, {
      id: hostId,
      label: label,
      providerType: providerType,
      type: "provider",
      home: controller.localHome,
      threads: [],
      projects: [],
      models: [],
      agents: []
    })
    lastSnapshotSignature = ""
  }

  function mergeUnread(nextThreads) {
    return ThreadStateLogic.mergeProviderUnread(
      host.threads, nextThreads, controller.activeThreadId)
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
    if (!enabled || controller.shuttingDown || processHost.queryRunning) return
    processHost.runQuery([queryHelperPath, providerType, "snapshot"])
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
    processHost.stopQuery()
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
      rateLimits: snapshot.rateLimits,
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

  LocalAgentProcessHost {
    id: processHost
    provider: root
    launches: launchCoordinator
  }

  function archiveThread(thread) { return processHost.archiveThread(thread) }
  function renameThread(thread, name) { return processHost.renameThread(thread, name) }
  function toggleThreadPin(thread) { return processHost.toggleThreadPin(thread) }
  function restartNewResolveTimer() { newResolveTimer.restart() }
  function openThread(thread, directory, source) {
    if (!thread || !thread.id || processHost.openRunning) return false
    var threadId = String(thread.id)
    var requestId = controller.mutations.beginThreadLaunch(
      threadId, source || (providerType + "-local"))
    if (requestId === 0) return false
    openIsNew = false
    openRequestId = requestId
    processHost.runOpen([
      openHelperPath,
      providerType,
      String(directory || pathForThread(thread)),
      threadId,
      serverUrl,
      controller.providers.selectedModelForProvider(providerType),
      controller.providers.selectedEffortForProvider(providerType),
      controller.providers.selectedAgentForProvider(providerType)
    ])
    return true
  }

  function newThread(directory) {
    if (processHost.openRunning) return
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
    processHost.runOpen([
      openHelperPath,
      providerType,
      target,
      "",
      serverUrl,
      controller.providers.selectedModelForProvider(providerType),
      controller.providers.selectedEffortForProvider(providerType),
      controller.providers.selectedAgentForProvider(providerType)
    ])
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
      launchCoordinator.map(id, pendingWindowAddress, hostId, pendingServerUrl)
      controller.mutations.observeActiveThread(id, "new-local-provider-thread")
      clearPendingNew()
      return
    }
  }


  Connections {
    target: root.controller
    function onActiveThreadIdChanged() {
      root.markThreadSeen(root.controller.activeThreadId)
    }
  }

  Process {
    id: serverProcess
    command: [
      "env", "-u", "OPENCODE_SERVER_PASSWORD", "-u", "OPENCODE_SERVER_USERNAME",
      "opencode", "serve", "--hostname", "127.0.0.1", "--port", "43962"
    ]
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
        root.clearPendingNew()
      }
    }
  }

  onEnabledChanged: if (enabled) activate(); else deactivate()

  Component.onCompleted: if (enabled) activate()

  Component.onDestruction: {
    processHost.queryRunning = false
    actionProcess.running = false
    processHost.openRunning = false
    serverProcess.running = false
  }
}
