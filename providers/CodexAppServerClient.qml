import QtQuick
import Quickshell.Io

Item {
  id: root

  required property var controller

  property bool ready: false
  property bool loading: false
  property bool refreshQueued: false
  property double lastRefreshMs: 0

  property int nextRequestId: 1
  property int initializeRequestId: 0
  property int listRequestId: 0
  property int archiveRequestId: 0
  property int renameRequestId: 0
  property int pinRequestId: 0
  property int projectListRequestId: 0
  property int projectCreateRequestId: 0
  property int moveThreadRequestId: 0
  property int rateLimitsRequestId: 0
  property int modelListRequestId: 0
  property int configReadRequestId: 0
  property int pageCount: 0
  property int projectPageCount: 0
  property var pageBuffer: []
  property var projectPageBuffer: []

  function reset() {
    ready = false
    loading = false
    refreshQueued = false
    pageBuffer = []
    controller.threads = []
    controller.projects = []
    controller.rateLimits = ({})
    controller.rateLimitResetCredits = ({})
    controller.models = []
    controller.codexConfig = ({})
    controller.threadStatuses = ({})
    controller.unreadThreads = ({})
    controller.mutations.observeActiveThread("", "app-server-reset")
    controller.errorText = ""
    controller.mutations.resetThreadMutations()
  }

  function start() {
    if (controller.shuttingDown || appServer.running) return
    if (!controller.settings.loaded || !controller.providers.remoteConfigLoaded) return
    appServer.command = [controller.streamGuardPath, "--", "codex", "app-server"]
    appServer.running = true
  }

  function send(message) {
    if (!appServer.running) return false
    appServer.write(JSON.stringify(message) + "\n")
    return true
  }

  function beginInitialize() {
    ready = false
    loading = false
    controller.errorText = ""
    initializeRequestId = nextRequestId++
    send({
      method: "initialize",
      id: initializeRequestId,
      params: {
        clientInfo: {
          name: "omarchy_codex_threads",
          title: "Omarchy Codex Threads",
          version: "1.0.0"
        },
        capabilities: { experimentalApi: true }
      }
    })
  }

  function refreshThreads() {
    if (!ready) {
      refreshQueued = true
      if (!appServer.running && !restartTimer.running) restartTimer.start()
      return
    }
    if (loading) {
      refreshQueued = true
      return
    }
    loading = true
    refreshQueued = false
    controller.errorText = ""
    pageBuffer = []
    pageCount = 0
    requestThreadPage(null)
  }

  function requestThreadPage(cursor) {
    listRequestId = nextRequestId++
    var params = { limit: 100, sortKey: "updated_at", sortDirection: "desc" }
    if (cursor) params.cursor = cursor
    send({ method: "thread/list", id: listRequestId, params: params })
  }

  function finishRefresh() {
    controller.threads = controller.threadActions.threadsWithoutArchiveTombstones(
      controller.providers.normalizePinnedThreads(pageBuffer))
    loading = false
    lastRefreshMs = Date.now()
    if (controller.archiveConfirmationId !== "") {
      controller.threadActions.setArchiveTombstone(controller.archiveConfirmationId, false)
      controller.archiveConfirmationId = ""
    }
    controller.threadActions.refreshThreadStatuses()
    controller.threadActions.resolvePendingNewThread()
    if (refreshQueued) Qt.callLater(root.refreshThreads)
  }

  function refreshProjects() {
    if (!ready) return
    projectPageBuffer = []
    projectPageCount = 0
    requestProjectPage(null)
  }

  function requestProjectPage(cursor) {
    projectListRequestId = nextRequestId++
    var params = { limit: 100 }
    if (cursor) params.cursor = cursor
    send({ method: "project/list", id: projectListRequestId, params: params })
  }

  function refreshRateLimits() {
    if (!ready || rateLimitsRequestId !== 0) return
    rateLimitsRequestId = nextRequestId++
    if (!send({ method: "account/rateLimits/read", id: rateLimitsRequestId }))
      rateLimitsRequestId = 0
  }

  function refreshModels() {
    if (!ready || modelListRequestId !== 0) return
    modelListRequestId = nextRequestId++
    if (!send({
      method: "model/list",
      id: modelListRequestId,
      params: { limit: 100, includeHidden: false }
    })) modelListRequestId = 0
  }

  function refreshConfig() {
    if (!ready || configReadRequestId !== 0) return
    configReadRequestId = nextRequestId++
    if (!send({
      method: "config/read",
      id: configReadRequestId,
      params: { includeLayers: false }
    })) configReadRequestId = 0
  }

  function createProject(threadId, name, path) {
    projectCreateRequestId = nextRequestId++
    if (!send({
      method: "project/create",
      id: projectCreateRequestId,
      params: {
        idempotencyKey: "omarchy-move-" + threadId + "-" + Date.now(),
        name: name,
        roots: [{ path: path }]
      }
    })) {
      projectCreateRequestId = 0
      controller.threadActions.failThreadMove("Could not reach the Codex App Server")
    }
  }

  function moveThread(threadId, projectId) {
    moveThreadRequestId = nextRequestId++
    if (!send({
      method: "thread/metadata/update",
      id: moveThreadRequestId,
      params: { threadId: threadId, projectId: projectId }
    })) controller.threadActions.failThreadMove("Could not reach the Codex App Server")
  }

  function clearMoveRequests() {
    projectCreateRequestId = 0
    moveThreadRequestId = 0
  }

  function archiveThread(threadId) {
    archiveRequestId = nextRequestId++
    if (send({
      method: "thread/archive",
      id: archiveRequestId,
      params: { threadId: threadId }
    })) return true
    archiveRequestId = 0
    return false
  }

  function renameThread(threadId, name) {
    renameRequestId = nextRequestId++
    if (send({
      method: "thread/name/set",
      id: renameRequestId,
      params: { threadId: threadId, name: name }
    })) return true
    renameRequestId = 0
    return false
  }

  function setThreadPinned(threadId, pinned, sectionId) {
    pinRequestId = nextRequestId++
    if (send({
      method: "thread/section/move",
      id: pinRequestId,
      params: { threadId: threadId, sectionId: pinned ? sectionId : null }
    })) return true
    pinRequestId = 0
    return false
  }

  CodexAppServerResponseHandler {
    id: responseHandler
    client: root
  }

  function handleResponse(message) { responseHandler.handleResponse(message) }

  function handleLine(line) {
    var text = String(line || "").trim()
    if (text === "") return
    var message
    try {
      message = JSON.parse(text)
    } catch (error) {
      console.warn("Codex Threads: invalid app-server message:", text)
      return
    }
    if (message.id !== undefined && message.id !== null) {
      handleResponse(message)
      return
    }
    var method = String(message.method || "")
    if (method === "thread/status/changed")
      controller.threadActions.applyRemoteStatusNotification(message.params || {})
    if (method.indexOf("project/") === 0) refreshProjects()
    if (method === "turn/completed") refreshRateLimits()
    if (method.indexOf("thread/") === 0 || method === "turn/completed")
      controller.threadActions.scheduleEventRefresh()
  }

  Process {
    id: appServer
    running: false
    stdinEnabled: true

    onStarted: root.beginInitialize()
    onExited: {
      root.ready = false
      root.loading = false
      if (root.archiveRequestId !== 0) root.controller.threadActions.restoreArchivedThread()
      root.archiveRequestId = 0
      if (root.renameRequestId !== 0)
        root.controller.mutations.failThreadMutation("rename", "The Codex App Server stopped")
      root.renameRequestId = 0
      if (root.pinRequestId !== 0)
        root.controller.mutations.failThreadMutation("pin", "The Codex App Server stopped")
      root.pinRequestId = 0
      root.projectListRequestId = 0
      root.rateLimitsRequestId = 0
      root.modelListRequestId = 0
      root.configReadRequestId = 0
      root.controller.threadActions.failThreadMove("", true)
      if (!root.controller.shuttingDown) restartTimer.restart()
    }
    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        var text = String(line || "").trim()
        if (text !== "") console.warn("Codex App Server:", text)
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: root.start()
  }

  Component.onDestruction: appServer.running = false
}
