import QtQuick
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/ThreadListLogic.js" as ThreadListLogic
import "../logic/ThreadMutationLogic.js" as ThreadMutationLogic
import "../logic/ThreadNotificationLogic.js" as ThreadNotificationLogic
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

QtObject {
  required property var store
  required property var providerLibrary

  function projectForId(projectId) {
    return ThreadListLogic.projectForId(store.projects, projectId)
  }
  
  function projectRootPath(project) {
    return ThreadListLogic.projectRoot(project)
  }
  
  function projectPathForThread(thread) {
    return ThreadListLogic.pathForThread(store.projects, thread, "", false)
  }
  
  function projectForRoot(path) {
    return ThreadListLogic.projectForRoot(store.projects, path)
  }
  
  function moveThreadToProject(thread, targetPath, targetName) {
    var threadId = String(thread && thread.id || "")
    var path = String(targetPath || "")
    var result = ThreadMutationLogic.beginMove(
      store.threadMutationState, threadId, path, targetName)
    if (!result.accepted) {
      if (result.error !== "") store.errorText = result.error
      return false
    }
    store.threadMutationState = result.state
    store.errorText = ""
  
    var project = projectForRoot(path)
    if (project) {
      assignMovingThreadToProject(String(project.id || ""))
      return true
    }
  
    providerLibrary.createProject(threadId, store.pendingMoveName, path)
    return true
  }
  
  function assignMovingThreadToProject(projectId) {
    if (store.movingThreadId === "" || projectId === "") {
      failThreadMove("Could not resolve the target Codex project")
      return
    }
    providerLibrary.moveThread(store.movingThreadId, projectId)
  }
  
  function failThreadMove(message, silent) {
    providerLibrary.clearMoveRequests()
    var result = ThreadMutationLogic.completeMutation(store.threadMutationState, "move")
    if (result.applied) store.threadMutationState = result.state
    if (!silent) store.errorText = String(message || "Could not move the Codex thread")
  }
  
  function finishThreadMove() {
    providerLibrary.clearMoveRequests()
    var result = ThreadMutationLogic.completeMutation(store.threadMutationState, "move")
    if (!result.applied) return false
    store.threadMutationState = result.state
    store.providers.refreshProjects()
    scheduleEventRefresh()
    return true
  }
  
  function threadStatus(threadId) {
    return store.threadStatuses[String(threadId || "")] || "done"
  }
  
  function threadUnread(threadId) {
    return store.unreadThreads[String(threadId || "")] === true
  }
  
  function markThreadSeen(threadId) {
    var id = String(threadId || "")
    if (id === "") return
    if (store.unreadThreads[id] === true) {
      var nextUnread = Object.assign({}, store.unreadThreads)
      delete nextUnread[id]
      store.unreadThreads = nextUnread
    }
    providerLibrary.markSupplementalThreadSeen(id)
  }
  
  function applyThreadStatuses(nextStatuses) {
    var nextUnread = ThreadStateLogic.nextUnreadThreads(
      store.threadStatuses, store.unreadThreads, nextStatuses, store.activeThreadId)
    store.threadStatuses = nextStatuses
    store.unreadThreads = nextUnread
  }
  
  function remoteStatusValue(status) {
    return ThreadStateLogic.remoteStatusValue(status)
  }
  
  function applyRemoteThreadStatuses() {
    applyThreadStatuses(ThreadNotificationLogic.statusMap(store.threads))
  }
  
  function applyRemoteStatusNotification(params) {
    var id = String(params && params.threadId || "")
    if (id === "") return
    var next = Object.assign({}, store.threadStatuses)
    next[id] = remoteStatusValue(params.status)
    applyThreadStatuses(next)
  }
  
  function refreshThreadStatuses() {
    if (!store.runtimeProcesses || store.runtimeProcesses.threadStatusesRunning) return
  
    var args = [store.streamGuardPath, "--", store.threadStatusesHelperPath]
    for (var i = 0; i < store.threads.length; i++) {
      var thread = store.threads[i]
      if (!thread || !thread.id || !thread.path) continue
      args.push(String(thread.id), String(thread.path))
    }
    store.runtimeProcesses.startThreadStatuses(args)
  }
  
  function archiveLocalCodexThread(thread) {
    if (!thread || !thread.id
        || !store.mutations.beginThreadMutation("archive", thread.id)) return false
    store.threadMutationState = ThreadMutationLogic.withArchiveSnapshot(
      store.threadMutationState, thread, threadIndex(store.threads, store.archivingThreadId))
    setArchiveTombstone(store.archivingThreadId, true)
    store.threads = threadsWithoutArchiveTombstones(store.threads)
    store.errorText = ""
    if (!providerLibrary.archiveLocalCodexRpc(store.archivingThreadId)) {
      restoreArchivedThread()
      store.errorText = "Could not reach the Codex App Server"
      return false
    }
    return true
  }
  
  function renameLocalCodexThread(thread, name) {
    var id = String(thread && thread.id || "")
    var normalized = String(name || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (id === "" || normalized === ""
        || !store.mutations.beginThreadMutation("rename", id)) return false
    if (!providerLibrary.renameLocalCodexRpc(id, normalized)) {
      store.mutations.failThreadMutation("rename", "Could not reach the Codex App Server")
      return false
    }
    return true
  }
  
  function toggleLocalCodexThreadPin(thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || !store.mutations.beginThreadMutation("pin", id)) return false
    store.mutations.setPendingPinValue(thread.isPinned !== true)
    if (!providerLibrary.pinLocalCodexRpc(id, store.pendingPinValue, store.pinnedSectionId)) {
      store.mutations.failThreadMutation("pin", "Could not reach the Codex App Server")
      return false
    }
    return true
  }
  
  function applyThreadPin(items, threadId, pinned, returnedThread) {
    return ThreadStateLogic.applyThreadPin(items, threadId, pinned, returnedThread)
  }
  
  function threadIndex(items, threadId) {
    return ThreadStateLogic.threadIndex(items, threadId)
  }
  
  function setArchiveTombstone(threadId, archived) {
    store.threadMutationState = ThreadMutationLogic.withArchiveTombstone(
      store.threadMutationState, threadId, archived)
  }
  
  function threadsWithoutArchiveTombstones(items) {
    return ThreadStateLogic.withoutArchiveTombstones(items, store.archiveTombstones)
  }
  
  function restoreArchivedThread() {
    var result = ThreadMutationLogic.restoreArchive(store.threads, store.threadMutationState)
    if (!result.applied) return false
    store.threads = result.items
    store.threadMutationState = result.state
    return true
  }
  
  function failThreadArchive(message) {
    restoreArchivedThread()
    store.errorText = ThreadMutationLogic.archiveErrorMessage(message)
  }
  
  function archiveThread(thread) {
    return providerLibrary.archiveThread("provider-codex", thread)
  }
  
  function renameThread(thread, name) {
    return providerLibrary.renameThread("provider-codex", thread, name)
  }
  
  function toggleThreadPin(thread) {
    return providerLibrary.toggleThreadPin("provider-codex", thread)
  }
  
  function openThread(thread, cwdOverride, source) {
    if (store.settings.threadFrontend === "agent-chat") {
      var path = String(cwdOverride || projectPathForThread(thread) || store.backendHomePath)
      return launchAgentChat(thread, path, source)
    }
    return !!providerLibrary.openThread(
      "provider-codex", thread, cwdOverride, source)
  }
  
  function newProjectThread(projectPath) {
    if (store.settings.threadFrontend === "agent-chat")
      return launchAgentChat(null, projectPath)
    return providerLibrary.createThread("provider-codex", projectPath)
  }
  
  function launchAgentChat(thread, cwd, source) {
    if (!store.runtimeProcesses || store.runtimeProcesses.agentChatRunning) return false
    var path = String(cwd || "")
    var threadId = String(thread && thread.id || "")
    if (path === "" || (thread && threadId === "")) return false
  
    var requestId = threadId !== ""
      ? store.mutations.beginThreadLaunch(threadId, source || "agent-chat") : 0
    if (threadId !== "" && requestId === 0) return false
  
    store.launchError = ""
    if (threadId === "") store.launchingProjectPath = path
  
    return store.runtimeProcesses.startAgentChat(
      ActionLogic.agentChatCommand(
        store.streamGuardPath, store.agentChatHelperPath, threadId, path,
        store.settings.selectedModel, store.settings.selectedEffort, store.codexServiceTier),
      threadId !== "" ? "thread" : "project", threadId, requestId)
  }
  
  function clearPendingNewThread() {
    providerLibrary.clearPendingLocalCodexThread()
  }
  
  function resolvePendingNewThread() {
    providerLibrary.resolvePendingLocalCodexThread()
  }
  
  function refreshActiveThread() {
    providerLibrary.refreshActiveThread()
  }
  
  function scheduleEventRefresh() {
    if (store.runtimeProcesses) store.runtimeProcesses.scheduleEventRefresh()
  }
}
