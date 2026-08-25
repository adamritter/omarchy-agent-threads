import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/AgentProviderLogic.js" as AgentProviderLogic
import "../logic/CodexConversationLogic.js" as ConversationLogic
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions

Item {
  id: root

  property bool ready: false
  property bool loading: false
  property bool busy: false
  property string activeThreadId: ""
  property string activeTurnId: ""
  property string activeCwd: ""
  property string activeModel: ""
  property string activeEffort: ""
  property string remoteAddress: ""
  property string remoteAuthTokenEnv: ""
  property string configuredModel: ""
  property string configuredEffort: ""
  property string configuredServiceTier: ""
  property string configuredApprovalPolicy: ""
  property string configuredApprovalsReviewer: "user"
  property string configuredSandbox: ""
  property string configuredCwd: Quickshell.env("HOME") || "/tmp"
  property var configOverrides: []
  property var models: []
  property var codexConfig: ({})
  property var messages: []
  property string errorText: ""
  property var approvalRequest: null

  property int nextRequestId: 1
  property int initializeRequestId: 0
  property int resumeRequestId: 0
  property int threadStartRequestId: 0
  property int turnStartRequestId: 0
  property int interruptRequestId: 0
  property int modelListRequestId: 0
  property int configReadRequestId: 0
  property string pendingPrompt: ""
  property string pendingCwd: ""
  property string pendingModel: ""
  property string pendingEffort: ""
  property string requestedThreadId: ""
  property bool reconnectAfterExit: false
  property bool shuttingDown: false

  readonly property string websocketHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-app-server-websocket").toString().replace(/^file:\/\//, "")

  signal threadChanged(string threadId)
  signal turnCompleted(string threadId)
  signal sessionReady()

  function start() {
    if (appServer.running || shuttingDown) return
    appServer.command = ChatLaunchOptions.transportCommand(
      remoteAddress, remoteAuthTokenEnv, websocketHelperPath, configOverrides)
    appServer.running = true
  }

  function configure(options) {
    if (busy) {
      errorText = "Stop the active turn before opening another thread or server"
      return false
    }
    var next = ChatLaunchOptions.normalize(options)
    remoteAddress = next.remote
    remoteAuthTokenEnv = next.remoteAuthTokenEnv
    configuredModel = next.model
    configuredEffort = next.effort
    configuredServiceTier = next.serviceTier
    configuredApprovalPolicy = next.approvalPolicy
    configuredApprovalsReviewer = next.approvalsReviewer
    configuredSandbox = next.sandbox
    configuredCwd = next.cwd || Quickshell.env("HOME") || "/tmp"
    configOverrides = next.configOverrides
    requestedThreadId = next.threadId
    models = []
    codexConfig = ({})
    ready = false
    resetConversation()
    if (appServer.running) {
      reconnectAfterExit = true
      appServer.running = false
    } else start()
    return true
  }

  function send(message) {
    if (!appServer.running) return false
    appServer.write(JSON.stringify(message) + "\n")
    return true
  }

  function beginInitialize() {
    initializeRequestId = nextRequestId++
    send({
      method: "initialize",
      id: initializeRequestId,
      params: {
        clientInfo: { name: "omarchy_agent_chat", title: "Omarchy Agent Chat", version: "1.0.0" },
        capabilities: { experimentalApi: true }
      }
    })
  }

  function runtimeOptions() {
    return {
      cwd: configuredCwd,
      model: configuredModel,
      effort: configuredEffort,
      serviceTier: configuredServiceTier,
      approvalPolicy: configuredApprovalPolicy,
      approvalsReviewer: configuredApprovalsReviewer,
      sandbox: configuredSandbox
    }
  }

  function modelState(modelId, modelSelection, effortSelection) {
    var selectedModelValue = modelSelection !== undefined
      ? String(modelSelection || "") : configuredModel
    var selectedEffortValue = effortSelection !== undefined
      ? String(effortSelection || "") : configuredEffort
    return AgentProviderLogic.modelState(
      models, codexConfig, selectedModelValue, selectedEffortValue, modelId)
  }

  function applyThreadOptions(params) {
    return ChatLaunchOptions.threadParams(params, runtimeOptions())
  }

  function applyTurnOptions(params) {
    return ChatLaunchOptions.turnParams(params, runtimeOptions())
  }

  function refreshModels() {
    if (!ready || modelListRequestId !== 0) return
    modelListRequestId = nextRequestId++
    if (!send({ method: "model/list", id: modelListRequestId,
        params: { limit: 100, includeHidden: false } })) modelListRequestId = 0
  }

  function refreshConfig() {
    if (!ready || configReadRequestId !== 0) return
    configReadRequestId = nextRequestId++
    if (!send({ method: "config/read", id: configReadRequestId,
        params: { includeLayers: false } })) configReadRequestId = 0
  }

  function resetConversation() {
    loading = false
    busy = false
    activeThreadId = ""
    activeTurnId = ""
    activeCwd = ""
    messages = []
    errorText = ""
    approvalRequest = null
  }

  function newChat(cwd, model, effort) {
    if (busy) return false
    resetConversation()
    pendingCwd = String(cwd || configuredCwd || Quickshell.env("HOME") || "/tmp")
    pendingModel = String(model || configuredModel || "")
    pendingEffort = String(effort || configuredEffort || "")
    return true
  }

  function openThread(threadId) {
    var id = String(threadId || "")
    if (!ready || busy || id === "") return false
    loading = true
    errorText = ""
    messages = []
    activeThreadId = id
    activeTurnId = ""
    resumeRequestId = nextRequestId++
    return send({
      method: "thread/resume",
      id: resumeRequestId,
      params: applyThreadOptions({ threadId: id })
    })
  }

  function sendPrompt(prompt, cwd, model, effort) {
    var value = String(prompt || "").trim()
    if (!ready || busy || value === "") return false
    errorText = ""
    messages = ConversationLogic.optimisticUserMessage(messages, value)
    if (activeThreadId === "") {
      pendingPrompt = value
      pendingCwd = String(cwd || pendingCwd || Quickshell.env("HOME") || "/tmp")
      pendingModel = String(model || pendingModel || "")
      pendingEffort = String(effort || pendingEffort || "")
      busy = true
      threadStartRequestId = nextRequestId++
      var startParams = applyThreadOptions({
        cwd: pendingCwd,
        experimentalRawEvents: false
      })
      if (pendingModel !== "") startParams.model = pendingModel
      return send({ method: "thread/start", id: threadStartRequestId, params: startParams })
    }
    return startTurn(value, cwd, model, effort)
  }

  function startTurn(prompt, cwd, model, effort) {
    if (activeThreadId === "") return false
    busy = true
    turnStartRequestId = nextRequestId++
    var params = applyTurnOptions({
      threadId: activeThreadId,
      input: [{ type: "text", text: String(prompt || "") }]
    })
    var turnCwd = String(cwd || "")
    var turnModel = String(model || configuredModel || "")
    var turnEffort = String(effort || configuredEffort || "")
    if (turnCwd !== "") params.cwd = turnCwd
    if (turnModel !== "") params.model = turnModel
    if (turnEffort !== "") params.effort = turnEffort
    if (!send({ method: "turn/start", id: turnStartRequestId, params: params })) {
      busy = false
      return false
    }
    return true
  }

  function interrupt() {
    if (!busy || activeThreadId === "" || activeTurnId === "") return false
    interruptRequestId = nextRequestId++
    return send({
      method: "turn/interrupt",
      id: interruptRequestId,
      params: { threadId: activeThreadId, turnId: activeTurnId }
    })
  }

  function answerApproval(accepted, remember) {
    if (!approvalRequest) return
    var request = approvalRequest
    approvalRequest = null
    var method = String(request.method || "")
    var result
    if (method === "item/commandExecution/requestApproval"
        || method === "item/fileChange/requestApproval") {
      result = { decision: accepted ? (remember ? "acceptForSession" : "accept") : "decline" }
    } else if (method === "item/permissions/requestApproval" && accepted) {
      result = {
        permissions: (request.params || {}).permissions || ({}),
        scope: remember ? "session" : "turn"
      }
    } else {
      send({ id: request.id, error: { code: -32001, message: "Request declined by the user" } })
      return
    }
    send({ id: request.id, result: result })
  }

  function handleResponse(message) {
    if (message.id === initializeRequestId) {
      if (message.error) {
        errorText = String(message.error.message || "Codex App Server initialization failed")
        return
      }
      send({ method: "initialized" })
      ready = true
      refreshModels()
      refreshConfig()
      if (requestedThreadId !== "") {
        var nextThreadId = requestedThreadId
        requestedThreadId = ""
        openThread(nextThreadId)
      } else {
        newChat(configuredCwd, configuredModel, configuredEffort)
        sessionReady()
      }
      return
    }
    if (message.id === modelListRequestId && modelListRequestId !== 0) {
      modelListRequestId = 0
      if (!message.error) models = (message.result || {}).data || []
      return
    }
    if (message.id === configReadRequestId && configReadRequestId !== 0) {
      configReadRequestId = 0
      if (!message.error) codexConfig = (message.result || {}).config || ({})
      return
    }
    if (message.id === resumeRequestId && resumeRequestId !== 0) {
      resumeRequestId = 0
      loading = false
      if (message.error) {
        errorText = String(message.error.message || "Could not open the Codex thread")
        return
      }
      var resume = message.result || ({})
      var thread = resume.thread || ({})
      activeThreadId = String(thread.id || activeThreadId)
      activeCwd = String(resume.cwd || thread.cwd || "")
      activeModel = String(resume.model || "")
      activeEffort = String(resume.reasoningEffort || "")
      messages = ConversationLogic.normalizeThread(thread)
      threadChanged(activeThreadId)
      sessionReady()
      return
    }
    if (message.id === threadStartRequestId && threadStartRequestId !== 0) {
      threadStartRequestId = 0
      if (message.error) {
        busy = false
        pendingPrompt = ""
        errorText = String(message.error.message || "Could not create the Codex thread")
        return
      }
      var started = message.result || ({})
      var newThread = started.thread || ({})
      activeThreadId = String(newThread.id || "")
      activeCwd = String(started.cwd || newThread.cwd || pendingCwd)
      activeModel = String(started.model || pendingModel)
      activeEffort = String(started.reasoningEffort || pendingEffort)
      busy = false
      threadChanged(activeThreadId)
      var prompt = pendingPrompt
      pendingPrompt = ""
      if (prompt !== "") startTurn(prompt, activeCwd, activeModel, activeEffort)
      return
    }
    if (message.id === turnStartRequestId && turnStartRequestId !== 0) {
      turnStartRequestId = 0
      if (message.error) {
        busy = false
        errorText = String(message.error.message || "Could not start the Codex turn")
        return
      }
      var turn = (message.result || {}).turn || ({})
      activeTurnId = String(turn.id || activeTurnId)
      return
    }
    if (message.id === interruptRequestId && interruptRequestId !== 0) {
      interruptRequestId = 0
      if (message.error) errorText = String(message.error.message || "Could not stop the Codex turn")
    }
  }

  function sameThread(params) {
    var threadId = String((params || {}).threadId || "")
    return activeThreadId === "" || threadId === "" || threadId === activeThreadId
  }

  function handleNotification(method, params) {
    if (!sameThread(params)) return
    if (method === "turn/started") {
      activeTurnId = String((params.turn || {}).id || activeTurnId)
      busy = true
      return
    }
    if (method === "item/started" || method === "item/completed") {
      messages = ConversationLogic.upsertItem(messages, params.item)
      return
    }
    if (method === "item/agentMessage/delta") {
      messages = ConversationLogic.appendDelta(
        messages, params.itemId, params.delta, "assistant", "Codex")
      return
    }
    if (method === "item/reasoning/summaryTextDelta"
        || method === "item/reasoning/textDelta") {
      messages = ConversationLogic.appendDelta(
        messages, params.itemId, params.delta, "reasoning", "Reasoning")
      return
    }
    if (method === "item/commandExecution/outputDelta"
        || method === "item/fileChange/outputDelta") {
      messages = ConversationLogic.appendDelta(
        messages, params.itemId, params.delta, "tool", "Tool output")
      return
    }
    if (method === "turn/completed") {
      var completed = params.turn || ({})
      var items = Array.isArray(completed.items) ? completed.items : []
      for (var i = 0; i < items.length; i++)
        messages = ConversationLogic.upsertItem(messages, items[i])
      activeTurnId = ""
      busy = false
      if (completed.error)
        errorText = String(completed.error.message || "The Codex turn failed")
      turnCompleted(activeThreadId)
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
    if (message.id !== undefined && message.id !== null && message.method) {
      var summary = ConversationLogic.approvalSummary(message.method, message.params)
      approvalRequest = Object.assign({}, message, summary)
      return
    }
    if (message.id !== undefined && message.id !== null) {
      handleResponse(message)
      return
    }
    handleNotification(String(message.method || ""), message.params || ({}))
  }

  Process {
    id: appServer
    running: false
    stdinEnabled: true
    onStarted: root.beginInitialize()
    onExited: {
      root.ready = false
      root.loading = false
      root.busy = false
      root.modelListRequestId = 0
      root.configReadRequestId = 0
      if (root.reconnectAfterExit) {
        root.reconnectAfterExit = false
        Qt.callLater(root.start)
      } else if (!root.shuttingDown) {
        if (root.activeThreadId !== "") root.requestedThreadId = root.activeThreadId
        restartTimer.restart()
      }
    }
    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    stderr: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (value !== "") console.warn("Agent Chat Codex App Server:", value)
      }
    }
  }

  Timer {
    id: restartTimer
    interval: 1500
    repeat: false
    onTriggered: root.start()
  }

  Component.onDestruction: {
    shuttingDown = true
    appServer.running = false
  }
}
