// Purpose: Provides shared Thread Store Mutations state and operations to the plugin.
import QtQuick
import "../logic/ThreadLaunchLogic.js" as ThreadLaunchLogic
import "../logic/ThreadMutationLogic.js" as ThreadMutationLogic

QtObject {
  required property var store

  function beginThreadLaunch(threadId, source) {
    var result = ThreadLaunchLogic.beginThreadLaunch(
      store.threadLaunchState, threadId, source)
    if (!result.accepted) {
      store.launchError = result.error
      return 0
    }
    store.threadLaunchState = result.state
    store.launchError = ""
    threadLaunchRequested(String(threadId || ""))
    return result.requestId
  }
  
  function confirmThreadLaunch(requestId, threadId) {
    var result = ThreadLaunchLogic.confirmThreadLaunch(
      store.threadLaunchState, requestId, threadId)
    if (!result.applied) return false
    store.threadLaunchState = result.state
    store.activeThreadId = result.threadId
    store.launchError = ""
    return true
  }
  
  function failThreadLaunch(requestId, message) {
    var result = ThreadLaunchLogic.failThreadLaunch(
      store.threadLaunchState, requestId, message)
    if (!result.applied) return false
    store.threadLaunchState = result.state
    store.launchError = result.error
    return true
  }
  
  function observeActiveThread(threadId, source) {
    var id = String(threadId || "")
    if (store.threadLaunchPhase === "launching" && id === store.launchingThreadId)
      return confirmThreadLaunch(store.threadLaunchRequestId, id)
    store.activeThreadId = id
    return true
  }
  
  function threadMutationRunning() {
    return ThreadMutationLogic.mutationRunning(store.threadMutationState)
  }
  
  function beginThreadMutation(kind, threadId) {
    var result = ThreadMutationLogic.beginMutation(
      store.threadMutationState, kind, threadId, store.activeThreadId)
    if (!result.accepted) {
      if (result.error !== "") store.errorText = result.error
      return false
    }
    store.threadMutationState = result.state
    store.errorText = ""
    return true
  }
  
  function finishThreadMutation(kind) {
    var result = ThreadMutationLogic.completeMutation(store.threadMutationState, kind)
    if (!result.applied) return false
    store.threadMutationState = result.state
    return true
  }
  
  function failThreadMutation(kind, message) {
    if (!finishThreadMutation(kind)) return false
    store.errorText = ThreadMutationLogic.mutationErrorMessage(kind, message)
    return true
  }
  
  function resetThreadMutations() {
    store.threadMutationState = ThreadMutationLogic.resetMutation(store.threadMutationState)
  }
  
  function setPendingPinValue(pinned) {
    store.threadMutationState = ThreadMutationLogic.withPinValue(
      store.threadMutationState, pinned)
  }
  
  function confirmThreadArchive() {
    if (store.archivingThreadId === "") return false
    store.archiveConfirmationId = store.archivingThreadId
    return finishThreadMutation("archive")
  }
}
