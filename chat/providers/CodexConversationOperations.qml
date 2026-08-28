// Purpose: Implements Codex Conversation Operations integration for Agent Chat.
import QtQuick
import Quickshell
import "../../logic/AgentProviderLogic.js" as AgentProviderLogic
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions
import "../logic/CodexConversationLogic.js" as ConversationLogic

QtObject {
  required property var client

  function modelState(modelId, modelSelection, effortSelection) {
    var selectedModelValue = modelSelection !== undefined
      ? String(modelSelection || "") : client.configuredModel
    var selectedEffortValue = effortSelection !== undefined
      ? String(effortSelection || "") : client.configuredEffort
    return AgentProviderLogic.modelState(
      client.models, client.codexConfig, selectedModelValue, selectedEffortValue, modelId)
  }
  
  function applyThreadOptions(params) {
    return ChatLaunchOptions.threadParams(params, client.runtimeOptions())
  }
  
  function applyTurnOptions(params) {
    return ChatLaunchOptions.turnParams(params, client.runtimeOptions())
  }
  
  function refreshModels() {
    if (!client.ready || client.modelListRequestId !== 0) return
    client.modelListRequestId = client.beginRequest("model list")
    if (!client.send({ method: "model/list", id: client.modelListRequestId,
        params: { limit: 100, includeHidden: false } })) {
      client.finishRequest(client.modelListRequestId)
      client.modelListRequestId = 0
    }
  }
  
  function refreshConfig() {
    if (!client.ready || client.configReadRequestId !== 0) return
    client.configReadRequestId = client.beginRequest("configuration")
    if (!client.send({ method: "config/read", id: client.configReadRequestId,
        params: { includeLayers: false } })) {
      client.finishRequest(client.configReadRequestId)
      client.configReadRequestId = 0
    }
  }
  
  function resetConversation() {
    client.loading = false
    client.busy = false
    client.activeThreadId = ""
    client.activeTurnId = ""
    client.activeCwd = ""
    client.messages = []
    client.errorText = ""
    client.approvalRequest = null
  }
  
  function newChat(cwd, model, effort) {
    if (client.busy) return false
    resetConversation()
    client.pendingCwd = String(cwd || client.configuredCwd || Quickshell.env("HOME"))
    client.pendingModel = String(model || client.configuredModel || "")
    client.pendingEffort = String(effort || client.configuredEffort || "")
    return true
  }
  
  function openThread(threadId) {
    var id = String(threadId || "")
    if (!client.ready || client.busy || id === "") return false
    client.loading = true
    client.errorText = ""
    client.messages = []
    client.activeThreadId = id
    client.activeTurnId = ""
    client.resumeRequestId = client.beginRequest("thread resume")
    var sent = client.send({
      method: "thread/resume",
      id: client.resumeRequestId,
      params: applyThreadOptions({ threadId: id })
    })
    if (!sent) {
      client.finishRequest(client.resumeRequestId)
      client.resumeRequestId = 0
      client.loading = false
    }
    return sent
  }
  
  function sendPrompt(prompt, cwd, model, effort) {
    var value = String(prompt || "").trim()
    if (!client.ready || client.busy || value === "") return false
    var promptError = ConversationLogic.promptValidationError(value)
    if (promptError !== "") {
      client.errorText = promptError
      return false
    }
    client.errorText = ""
    client.messages = ConversationLogic.optimisticUserMessage(client.messages, value)
    if (client.activeThreadId === "") {
      client.pendingPrompt = value
      client.pendingCwd = String(cwd || client.pendingCwd || Quickshell.env("HOME"))
      client.pendingModel = String(model || client.pendingModel || "")
      client.pendingEffort = String(effort || client.pendingEffort || "")
      client.busy = true
      client.threadStartRequestId = client.beginRequest("thread start")
      var startParams = applyThreadOptions({
        cwd: client.pendingCwd,
        experimentalRawEvents: false
      })
      if (client.pendingModel !== "") startParams.model = client.pendingModel
      var sent = client.send({ method: "thread/start", id: client.threadStartRequestId, params: startParams })
      if (!sent) {
        client.finishRequest(client.threadStartRequestId)
        client.threadStartRequestId = 0
        client.pendingPrompt = ""
        client.busy = false
      }
      return sent
    }
    return startTurn(value, cwd, model, effort)
  }
  
  function startTurn(prompt, cwd, model, effort) {
    if (client.activeThreadId === "") return false
    var promptError = ConversationLogic.promptValidationError(prompt)
    if (promptError !== "") {
      client.errorText = promptError
      return false
    }
    client.busy = true
    client.turnStartRequestId = client.beginRequest("turn start")
    var params = applyTurnOptions({
      threadId: client.activeThreadId,
      input: [{ type: "text", text: String(prompt || "") }]
    })
    var turnCwd = String(cwd || "")
    var turnModel = String(model || client.configuredModel || "")
    var turnEffort = String(effort || client.configuredEffort || "")
    if (turnCwd !== "") params.cwd = turnCwd
    if (turnModel !== "") params.model = turnModel
    if (turnEffort !== "") params.effort = turnEffort
    if (!client.send({ method: "turn/start", id: client.turnStartRequestId, params: params })) {
      client.finishRequest(client.turnStartRequestId)
      client.turnStartRequestId = 0
      client.busy = false
      return false
    }
    return true
  }
  
  function interrupt() {
    if (!client.busy || client.activeThreadId === "" || client.activeTurnId === "") return false
    client.interruptRequestId = client.beginRequest("turn interrupt")
    var sent = client.send({
      method: "turn/interrupt",
      id: client.interruptRequestId,
      params: { threadId: client.activeThreadId, turnId: client.activeTurnId }
    })
    if (!sent) {
      client.finishRequest(client.interruptRequestId)
      client.interruptRequestId = 0
    }
    return sent
  }
  
}
