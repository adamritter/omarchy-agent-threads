import QtQuick
import Quickshell
import Quickshell.Io
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
  property bool protocolViolation: false
  property var requestDeadlines: ({})

  readonly property string websocketHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-app-server-websocket").toString().replace(/^file:\/\//, "")
  readonly property string transportGuardPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-stream-guard").toString().replace(/^file:\/\//, "")

  signal threadChanged(string threadId)
  signal turnCompleted(string threadId)
  signal sessionReady()

  function beginRequest(label) {
    var requestId = nextRequestId++
    requestDeadlines = ConversationLogic.trackRequestDeadline(
      requestDeadlines, requestId, label, Date.now(), ConversationLogic.requestTimeoutMs())
    return requestId
  }

  function finishRequest(requestId) {
    requestDeadlines = ConversationLogic.clearRequestDeadline(requestDeadlines, requestId)
  }

  function clearRequests() {
    requestDeadlines = ({})
  }

  function handleRequestTimeout(requestId, label) {
    if (requestId === initializeRequestId) {
      initializeRequestId = 0
      ready = false
      errorText = "Codex App Server initialization timed out"
      if (appServer.running) appServer.running = false
      return
    }
    if (requestId === modelListRequestId) {
      modelListRequestId = 0
      return
    }
    if (requestId === configReadRequestId) {
      configReadRequestId = 0
      return
    }
    if (requestId === resumeRequestId) {
      resumeRequestId = 0
      loading = false
      errorText = "Opening the Codex thread timed out"
      if (appServer.running) appServer.running = false
      return
    }
    if (requestId === threadStartRequestId) {
      threadStartRequestId = 0
      pendingPrompt = ""
      busy = false
      errorText = "Creating the Codex thread timed out"
      if (appServer.running) appServer.running = false
      return
    }
    if (requestId === turnStartRequestId) {
      turnStartRequestId = 0
      busy = false
      errorText = "Starting the Codex turn timed out"
      if (appServer.running) appServer.running = false
      return
    }
    if (requestId === interruptRequestId) {
      interruptRequestId = 0
      errorText = "Stopping the Codex turn timed out"
      if (appServer.running) appServer.running = false
      return
    }
    console.warn("Agent Chat request timed out:", label)
  }

  function expireRequests() {
    var result = ConversationLogic.takeExpiredRequestDeadlines(requestDeadlines, Date.now())
    requestDeadlines = result.remaining
    for (var i = 0; i < result.expired.length; i++) {
      var entry = result.expired[i] || ({})
      handleRequestTimeout(Number(entry.id), String(entry.label || "request"))
    }
  }

  function start() {
    if (appServer.running || shuttingDown || protocolViolation) return
    appServer.command = ChatLaunchOptions.transportCommand(
      remoteAddress, remoteAuthTokenEnv, transportGuardPath,
      websocketHelperPath, configOverrides)
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
    protocolViolation = false
    clearRequests()
    models = []
    codexConfig = ({})
    ready = false
    operationApi.resetConversation()
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
    initializeRequestId = beginRequest("initialization")
    if (!send({
      method: "initialize",
      id: initializeRequestId,
      params: {
        clientInfo: { name: "omarchy_agent_chat", title: "Omarchy Agent Chat", version: "1.0.0" },
        capabilities: { experimentalApi: true }
      }
    })) {
      finishRequest(initializeRequestId)
      initializeRequestId = 0
    }
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

  CodexConversationOperations { id: operationApi; client: root }
  CodexConversationResponseHandler {
    id: responseApi
    client: root
    operations: operationApi
  }

  function modelState(modelId, modelSelection, effortSelection) {
    return operationApi.modelState(modelId, modelSelection, effortSelection)
  }
  function newChat(cwd, model, effort) { return operationApi.newChat(cwd, model, effort) }
  function sendPrompt(prompt, cwd, model, effort) {
    return operationApi.sendPrompt(prompt, cwd, model, effort)
  }
  function interrupt() { return operationApi.interrupt() }
  function stopTransport() { appServer.running = false }

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

  Process {
    id: appServer
    running: false
    stdinEnabled: true
    onStarted: root.beginInitialize()
    onExited: function(exitCode) {
      var reconnect = root.reconnectAfterExit
      root.ready = false
      root.loading = false
      root.busy = false
      root.clearRequests()
      root.initializeRequestId = 0
      root.resumeRequestId = 0
      root.threadStartRequestId = 0
      root.turnStartRequestId = 0
      root.interruptRequestId = 0
      root.modelListRequestId = 0
      root.configReadRequestId = 0
      if (reconnect) {
        root.reconnectAfterExit = false
        Qt.callLater(root.start)
      } else if (Number(exitCode) === 2) {
        root.protocolViolation = true
        if (root.errorText === "")
          root.errorText = "Codex App Server transport stopped after rejecting unsafe input"
      } else if (!root.shuttingDown && !root.protocolViolation) {
        if (root.activeThreadId !== "") root.requestedThreadId = root.activeThreadId
        restartTimer.restart()
      }
    }
    stdout: SplitParser { onRead: function(line) { responseApi.handleLine(line) } }
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

  Timer {
    interval: 250
    repeat: true
    running: Object.keys(root.requestDeadlines).length > 0
    onTriggered: root.expireRequests()
  }

  Component.onDestruction: {
    shuttingDown = true
    appServer.running = false
  }
}
