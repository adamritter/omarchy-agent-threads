import QtQuick
import "../logic/CodexConversationLogic.js" as ConversationLogic

QtObject {
  required property var client
  required property var operations

  function handleResponse(message) {
    client.finishRequest(message.id)
    if (message.id === client.initializeRequestId) {
      client.initializeRequestId = 0
      if (message.error) {
        client.errorText = String(message.error.message || "Codex App Server initialization failed")
        return
      }
      client.send({ method: "initialized" })
      client.ready = true
      operations.refreshModels()
      operations.refreshConfig()
      if (client.requestedThreadId !== "") {
        var nextThreadId = client.requestedThreadId
        client.requestedThreadId = ""
        operations.openThread(nextThreadId)
      } else {
        operations.newChat(client.configuredCwd, client.configuredModel, client.configuredEffort)
        client.sessionReady()
      }
      return
    }
    if (message.id === client.modelListRequestId && client.modelListRequestId !== 0) {
      client.modelListRequestId = 0
      if (!message.error)
        client.models = ConversationLogic.boundedModelEntries((message.result || {}).data)
      return
    }
    if (message.id === client.configReadRequestId && client.configReadRequestId !== 0) {
      client.configReadRequestId = 0
      if (!message.error) client.codexConfig = (message.result || {}).config || ({})
      return
    }
    if (message.id === client.resumeRequestId && client.resumeRequestId !== 0) {
      client.resumeRequestId = 0
      client.loading = false
      if (message.error) {
        client.errorText = String(message.error.message || "Could not open the Codex thread")
        return
      }
      var resume = message.result || ({})
      var thread = resume.thread || ({})
      client.activeThreadId = String(thread.id || client.activeThreadId)
      client.activeCwd = String(resume.cwd || thread.cwd || "")
      client.activeModel = String(resume.model || "")
      client.activeEffort = String(resume.reasoningEffort || "")
      client.messages = ConversationLogic.normalizeThread(thread)
      var activity = ConversationLogic.threadActivity(thread)
      client.busy = activity.client.busy
      client.activeTurnId = activity.turnId
      client.threadChanged(client.activeThreadId)
      client.sessionReady()
      return
    }
    if (message.id === client.threadStartRequestId && client.threadStartRequestId !== 0) {
      client.threadStartRequestId = 0
      if (message.error) {
        client.busy = false
        client.pendingPrompt = ""
        client.errorText = String(message.error.message || "Could not create the Codex thread")
        return
      }
      var started = message.result || ({})
      var newThread = started.thread || ({})
      client.activeThreadId = String(newThread.id || "")
      client.activeCwd = String(started.cwd || newThread.cwd || client.pendingCwd)
      client.activeModel = String(started.model || client.pendingModel)
      client.activeEffort = String(started.reasoningEffort || client.pendingEffort)
      client.busy = false
      client.threadChanged(client.activeThreadId)
      var prompt = client.pendingPrompt
      client.pendingPrompt = ""
      if (prompt !== "") operations.startTurn(prompt, client.activeCwd, client.activeModel, client.activeEffort)
      return
    }
    if (message.id === client.turnStartRequestId && client.turnStartRequestId !== 0) {
      client.turnStartRequestId = 0
      if (message.error) {
        client.busy = false
        client.errorText = String(message.error.message || "Could not start the Codex turn")
        return
      }
      var turn = (message.result || {}).turn || ({})
      client.activeTurnId = String(turn.id || client.activeTurnId)
      return
    }
    if (message.id === client.interruptRequestId && client.interruptRequestId !== 0) {
      client.interruptRequestId = 0
      if (message.error) client.errorText = String(message.error.message || "Could not stop the Codex turn")
    }
  }
  
  function sameThread(params) {
    var threadId = String((params || {}).threadId || "")
    return client.activeThreadId === "" || threadId === "" || threadId === client.activeThreadId
  }
  
  function handleNotification(method, params) {
    if (!sameThread(params)) return
    if (method === "turn/started") {
      client.activeTurnId = String((params.turn || {}).id || client.activeTurnId)
      client.busy = true
      return
    }
    if (method === "item/started" || method === "item/completed") {
      client.messages = ConversationLogic.upsertItem(client.messages, params.item, params.turnId)
      return
    }
    if (method === "item/agentMessage/delta") {
      client.messages = ConversationLogic.appendDelta(
        client.messages, params.itemId, params.delta, "assistant", "Codex")
      return
    }
    if (method === "item/reasoning/summaryTextDelta"
        || method === "item/reasoning/textDelta") {
      client.messages = ConversationLogic.appendDelta(
        client.messages, params.itemId, params.delta, "reasoning", "Reasoning")
      return
    }
    if (method === "item/commandExecution/outputDelta"
        || method === "item/fileChange/outputDelta") {
      client.messages = ConversationLogic.appendDelta(
        client.messages, params.itemId, params.delta, "tool", "Tool output")
      return
    }
    if (method === "item/fileChange/patchUpdated") {
      client.messages = ConversationLogic.upsertItem(client.messages, {
        id: params.itemId,
        type: "fileChange",
        changes: params.changes,
        status: "inProgress"
      }, params.turnId)
      return
    }
    if (method === "turn/completed") {
      var completed = params.turn || ({})
      var items = ConversationLogic.completedTurnItems(completed)
      for (var i = 0; i < items.length; i++)
        client.messages = ConversationLogic.upsertItem(client.messages, items[i], completed.id)
      client.activeTurnId = ""
      client.busy = false
      if (completed.error)
        client.errorText = String(completed.error.message || "The Codex turn failed")
      client.turnCompleted(client.activeThreadId)
    }
  }
  
  function handleLine(line) {
    var value = String(line || "").trim()
    if (value === "") return
    var message
    try {
      message = JSON.parse(value)
    } catch (error) {
      console.warn("Agent Chat: invalid Codex App Server message")
      return
    }
    var structureError = ConversationLogic.protocolStructureError(message)
    if (structureError !== "") {
      client.errorText = "Codex App Server " + structureError
      client.protocolViolation = true
      client.stopTransport()
      return
    }
    if (message.id !== undefined && message.id !== null && message.method) {
      var summary = ConversationLogic.approvalSummary(message.method, message.params)
      client.approvalRequest = Object.assign({}, message, summary)
      return
    }
    if (message.id !== undefined && message.id !== null) {
      handleResponse(message)
      return
    }
    handleNotification(String(message.method || ""), message.params || ({}))
  }
  
}
