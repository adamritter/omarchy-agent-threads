// Purpose: Implements the Codex App Server Response Handler provider integration boundary.
import QtQuick

QtObject {
  required property var client

  function handleResponse(message) {
    if (message.id === client.initializeRequestId) {
      if (message.error) {
        client.controller.errorText = String(message.error.message
          || "Codex App Server initialization failed")
        return
      }
      client.send({ method: "initialized" })
      client.ready = true
      client.refreshProjects()
      client.refreshThreads()
      client.refreshRateLimits()
      client.refreshModels()
      client.refreshConfig()
      return
    }
  
    if (message.id === client.rateLimitsRequestId && client.rateLimitsRequestId !== 0) {
      client.rateLimitsRequestId = 0
      if (!message.error) {
        var limitResult = message.result || {}
        client.controller.rateLimits = limitResult.rateLimits || ({})
        client.controller.rateLimitResetCredits = limitResult.rateLimitResetCredits || ({})
      }
      return
    }
    if (message.id === client.modelListRequestId && client.modelListRequestId !== 0) {
      client.modelListRequestId = 0
      if (!message.error) client.controller.models = (message.result || {}).data || []
      return
    }
    if (message.id === client.configReadRequestId && client.configReadRequestId !== 0) {
      client.configReadRequestId = 0
      if (!message.error) client.controller.codexConfig = (message.result || {}).config || ({})
      return
    }
    if (message.id === client.projectListRequestId && client.projectListRequestId !== 0) {
      if (message.error) {
        client.projectListRequestId = 0
        client.controller.errorText = String(message.error.message || "Could not list Codex projects")
        return
      }
      var projectResult = message.result || {}
      client.projectPageBuffer = client.projectPageBuffer.concat(projectResult.data || [])
      client.projectPageCount++
      if (projectResult.nextCursor && client.projectPageCount < 20)
        client.requestProjectPage(projectResult.nextCursor)
      else {
        client.projectListRequestId = 0
        client.controller.projects = client.projectPageBuffer
      }
      return
    }
    if (message.id === client.projectCreateRequestId && client.projectCreateRequestId !== 0) {
      client.projectCreateRequestId = 0
      if (message.error) {
        client.controller.threadActions.failThreadMove(message.error.message || "Could not create the Codex project")
        return
      }
      var createdProject = message.result ? message.result.project : null
      if (createdProject) client.controller.projects = client.controller.projects.concat([createdProject])
      client.controller.threadActions.assignMovingThreadToProject(String(createdProject && createdProject.id || ""))
      return
    }
    if (message.id === client.moveThreadRequestId && client.moveThreadRequestId !== 0) {
      if (message.error) {
        client.controller.threadActions.failThreadMove(message.error.message || "Could not move the Codex thread")
        return
      }
      client.controller.threadActions.finishThreadMove()
      return
    }
    if (message.id === client.archiveRequestId && client.archiveRequestId !== 0) {
      client.archiveRequestId = 0
      if (message.error) {
        client.controller.threadActions.failThreadArchive(message.error.message)
      } else {
        client.controller.mutations.confirmThreadArchive()
        client.controller.threadActions.scheduleEventRefresh()
      }
      return
    }
    if (message.id === client.renameRequestId && client.renameRequestId !== 0) {
      client.renameRequestId = 0
      if (message.error)
        client.controller.mutations.failThreadMutation("rename", message.error.message)
      else client.controller.mutations.finishThreadMutation("rename")
      if (!message.error) client.controller.threadActions.scheduleEventRefresh()
      return
    }
    if (message.id === client.pinRequestId && client.pinRequestId !== 0) {
      var pinnedThreadId = client.controller.pinningThreadId
      var pinnedValue = client.controller.pendingPinValue
      client.pinRequestId = 0
      if (message.error) {
        client.controller.mutations.failThreadMutation("pin", message.error.message)
      } else {
        client.controller.mutations.finishThreadMutation("pin")
        var returnedThread = message.result ? message.result.thread : null
        client.controller.threads = client.controller.threadActions.applyThreadPin(
          client.controller.threads, pinnedThreadId, pinnedValue, returnedThread)
        client.controller.threadActions.scheduleEventRefresh()
      }
      return
    }
    if (message.id !== client.listRequestId) return
    if (message.error) {
      client.loading = false
      client.controller.errorText = String(message.error.message || "Could not list Codex threads")
      return
    }
    var result = message.result || {}
    client.pageBuffer = client.pageBuffer.concat(result.data || [])
    client.pageCount++
    if (result.nextCursor && client.pageCount < 20) client.requestThreadPage(result.nextCursor)
    else client.finishRefresh()
  }
}
