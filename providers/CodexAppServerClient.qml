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
    controller.activeThreadId = ""
    controller.errorText = ""
    controller.movingThreadId = ""
    controller.renamingThreadId = ""
    controller.pinningThreadId = ""
    controller.pendingPinValue = false
    controller.pendingMovePath = ""
    controller.pendingMoveName = ""
  }

  function start() {
    if (controller.shuttingDown || appServer.running) return
    if (!controller.sidebarSettingsLoaded || !controller.remoteConfigLoaded) return
    appServer.command = ["codex", "app-server"]
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
    controller.threads = controller.threadsWithoutArchiveTombstones(
      controller.normalizePinnedThreads(pageBuffer))
    loading = false
    lastRefreshMs = Date.now()
    if (controller.archiveConfirmationId !== "") {
      controller.setArchiveTombstone(controller.archiveConfirmationId, false)
      controller.archiveConfirmationId = ""
    }
    controller.refreshThreadStatuses()
    controller.resolvePendingNewThread()
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
      controller.failThreadMove("Could not reach the Codex App Server")
    }
  }

  function moveThread(threadId, projectId) {
    moveThreadRequestId = nextRequestId++
    if (!send({
      method: "thread/metadata/update",
      id: moveThreadRequestId,
      params: { threadId: threadId, projectId: projectId }
    })) controller.failThreadMove("Could not reach the Codex App Server")
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

  function handleResponse(message) {
    if (message.id === initializeRequestId) {
      if (message.error) {
        controller.errorText = String(message.error.message
          || "Codex App Server initialization failed")
        return
      }
      send({ method: "initialized" })
      ready = true
      refreshProjects()
      refreshThreads()
      refreshRateLimits()
      refreshModels()
      refreshConfig()
      return
    }

    if (message.id === rateLimitsRequestId && rateLimitsRequestId !== 0) {
      rateLimitsRequestId = 0
      if (!message.error) {
        var limitResult = message.result || {}
        controller.rateLimits = limitResult.rateLimits || ({})
        controller.rateLimitResetCredits = limitResult.rateLimitResetCredits || ({})
      }
      return
    }
    if (message.id === modelListRequestId && modelListRequestId !== 0) {
      modelListRequestId = 0
      if (!message.error) controller.models = (message.result || {}).data || []
      return
    }
    if (message.id === configReadRequestId && configReadRequestId !== 0) {
      configReadRequestId = 0
      if (!message.error) controller.codexConfig = (message.result || {}).config || ({})
      return
    }
    if (message.id === projectListRequestId && projectListRequestId !== 0) {
      if (message.error) {
        projectListRequestId = 0
        controller.errorText = String(message.error.message || "Could not list Codex projects")
        return
      }
      var projectResult = message.result || {}
      projectPageBuffer = projectPageBuffer.concat(projectResult.data || [])
      projectPageCount++
      if (projectResult.nextCursor && projectPageCount < 20)
        requestProjectPage(projectResult.nextCursor)
      else {
        projectListRequestId = 0
        controller.projects = projectPageBuffer
      }
      return
    }
    if (message.id === projectCreateRequestId && projectCreateRequestId !== 0) {
      projectCreateRequestId = 0
      if (message.error) {
        controller.failThreadMove(message.error.message || "Could not create the Codex project")
        return
      }
      var createdProject = message.result ? message.result.project : null
      if (createdProject) controller.projects = controller.projects.concat([createdProject])
      controller.assignMovingThreadToProject(String(createdProject && createdProject.id || ""))
      return
    }
    if (message.id === moveThreadRequestId && moveThreadRequestId !== 0) {
      if (message.error) {
        controller.failThreadMove(message.error.message || "Could not move the Codex thread")
        return
      }
      controller.finishThreadMove()
      return
    }
    if (message.id === archiveRequestId && archiveRequestId !== 0) {
      archiveRequestId = 0
      if (message.error) {
        controller.restoreArchivedThread()
        controller.errorText = String(message.error.message || "Could not archive the Codex thread")
      } else {
        controller.archiveConfirmationId = controller.archivingThreadId
        controller.archivedThreadSnapshot = null
        controller.archivedThreadIndex = -1
        controller.archivingThreadId = ""
        controller.scheduleEventRefresh()
      }
      return
    }
    if (message.id === renameRequestId && renameRequestId !== 0) {
      renameRequestId = 0
      controller.renamingThreadId = ""
      if (message.error)
        controller.errorText = String(message.error.message || "Could not rename the Codex thread")
      else controller.scheduleEventRefresh()
      return
    }
    if (message.id === pinRequestId && pinRequestId !== 0) {
      var pinnedThreadId = controller.pinningThreadId
      var pinnedValue = controller.pendingPinValue
      pinRequestId = 0
      controller.pinningThreadId = ""
      controller.pendingPinValue = false
      if (message.error) {
        controller.errorText = String(message.error.message || "Could not update the Codex pin")
      } else {
        var returnedThread = message.result ? message.result.thread : null
        controller.threads = controller.applyThreadPin(
          controller.threads, pinnedThreadId, pinnedValue, returnedThread)
        controller.scheduleEventRefresh()
      }
      return
    }
    if (message.id !== listRequestId) return
    if (message.error) {
      loading = false
      controller.errorText = String(message.error.message || "Could not list Codex threads")
      return
    }
    var result = message.result || {}
    pageBuffer = pageBuffer.concat(result.data || [])
    pageCount++
    if (result.nextCursor && pageCount < 20) requestThreadPage(result.nextCursor)
    else finishRefresh()
  }

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
      controller.applyRemoteStatusNotification(message.params || {})
    if (method.indexOf("project/") === 0) refreshProjects()
    if (method === "turn/completed") refreshRateLimits()
    if (method.indexOf("thread/") === 0 || method === "turn/completed")
      controller.scheduleEventRefresh()
  }

  Process {
    id: appServer
    running: false
    stdinEnabled: true

    onStarted: root.beginInitialize()
    onExited: {
      root.ready = false
      root.loading = false
      if (root.archiveRequestId !== 0) root.controller.restoreArchivedThread()
      root.archiveRequestId = 0
      root.renameRequestId = 0
      root.controller.renamingThreadId = ""
      root.pinRequestId = 0
      root.controller.pinningThreadId = ""
      root.controller.pendingPinValue = false
      root.projectListRequestId = 0
      root.rateLimitsRequestId = 0
      root.modelListRequestId = 0
      root.configReadRequestId = 0
      root.controller.failThreadMove("", true)
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
