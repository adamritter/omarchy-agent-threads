import QtQuick
import Quickshell.Io
import "../logic/ProviderSnapshotLogic.js" as Snap
import "../logic/ThreadStateLogic.js" as State
Item {
  id: root
  required property var controller
  required property string providerType
  required property string label
  readonly property bool enabled:
    String(controller.settings.selectedProvider || "codex") === providerType
  property string serverUrl: "http://127.0.0.1:43962"
  readonly property string hostId: "provider-" + providerType
  property var host: ({ id: hostId, label: label, providerType: providerType,
    type: "provider", home: controller.localHome, threads: [], projects: [],
    models: [], agents: [], loading: true, error: "" })
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
  property string openThreadId: ""
  function helperPath(name) { return Qt.resolvedUrl("../bin/" + name)
    .toString().replace(/^file:\/\//, "") }
  readonly property string queryHelperPath: helperPath("omarchy-agent-provider-query")
  readonly property string openHelperPath: helperPath("omarchy-agent-thread-open")
  readonly property string openCodeServerHelperPath: helperPath("omarchy-agent-opencode-server")
  readonly property string openCodeAuthFile: controller.stateHome
    + "/omarchy/opencode-server-auth.json"
  ThreadLaunchCoordinator { id: launchCoordinator }
  function pathForThread(thread) { return String(
    thread && thread.cwd || host.home || controller.localHome) }
  function threadStatus(thread) { return State.remoteStatusValue(
    thread ? thread.status : null) }
  function restoreSnapshot(snapshot) {
    if (!snapshot || String(snapshot.providerType || "") !== providerType) return
    host = Snap.hydratedHost(snapshot, {
      id: hostId, label: label, providerType: providerType, type: "provider",
      home: controller.localHome, threads: [], projects: [], models: [], agents: []
    })
    lastSnapshotSignature = ""
  }
  function mergeUnread(nextThreads) { return State.mergeProviderUnread(
    host.threads, nextThreads, controller.activeThreadId) }

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
    if (providerType === "opencode") serverProcess.start()
    initialRefreshTimer.restart()
  }
  function deactivate() {
    initialRefreshTimer.stop()
    processHost.stopQuery()
    if (providerType === "opencode") serverProcess.stop()
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
    var id = String(thread.id)
    var requestId = controller.mutations.beginThreadLaunch(
      id, source || (providerType + "-local"))
    if (requestId === 0) return false
    if (launchCoordinator.focusCachedThread(id, hostId)) {
      controller.mutations.observeActiveThread(
        id, "cached-local-" + providerType + "-window")
      return true
    }
    openIsNew = false
    openRequestId = requestId
    openThreadId = id
    processHost.runOpen([
      openHelperPath,
      providerType,
      String(directory || pathForThread(thread)),
      id,
      serverUrl,
      controller.settings.selectedModelForProvider(providerType),
      controller.settings.selectedEffortForProvider(providerType),
      controller.settings.selectedAgentForProvider(providerType)
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
      controller.settings.selectedModelForProvider(providerType),
      controller.settings.selectedEffortForProvider(providerType),
      controller.settings.selectedAgentForProvider(providerType)
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
  LocalOpenCodeServer {
    id: serverProcess
    provider: root
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
    serverProcess.stop()
  }
}
