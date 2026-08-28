import QtQuick
import Quickshell
import qs.AgentThreads.chat.providers as Providers

ShellRoot {
  id: root

  Providers.CodexConversationClient {
    id: conversationClient
    configuredCwd: "/work"
  }

  function check(condition, message) {
    if (condition) return true
    console.warn("CHAT_COMPONENT_FAIL: " + message)
    Qt.callLater(Qt.quit)
    return false
  }

  Component.onCompleted: {
    var path = Quickshell.env("AGENT_CHAT_COMPONENT_PATH")
    var component = Qt.createComponent(
      "file://" + path, Component.PreferSynchronous)
    if (!check(component.status === Component.Ready,
        component.errorString())) return
    component.destroy()

    conversationClient.ready = true
    var oversizedPrompt = new Array(200002).join("x")
    if (!check(!conversationClient.sendPrompt(
        oversizedPrompt, "/work", "", ""),
        "oversized prompt was accepted")) return
    if (!check(conversationClient.errorText.indexOf("200,000") >= 0,
        "oversized prompt did not report its limit")) return

    conversationClient.errorText = ""
    conversationClient.handleLine(JSON.stringify({ values: new Array(5001) }))
    if (!check(conversationClient.protocolViolation,
        "unsafe protocol structure did not stop the client")) return
    if (!check(conversationClient.errorText.indexOf("array entries") >= 0,
        "unsafe protocol structure did not report its reason")) return

    conversationClient.protocolViolation = false
    conversationClient.errorText = ""
    conversationClient.requestDeadlines = ({})
    var requestId = conversationClient.beginRequest("initialization")
    conversationClient.initializeRequestId = requestId
    conversationClient.requestDeadlines[String(requestId)].deadline = 0
    conversationClient.expireRequests()
    if (!check(conversationClient.initializeRequestId === 0,
        "expired initialization stayed pending")) return
    if (!check(Object.keys(conversationClient.requestDeadlines).length === 0,
        "expired request stayed retained")) return
    if (!check(conversationClient.errorText
        === "Codex App Server initialization timed out",
        "expired initialization did not surface its timeout")) return

    console.info("CHAT_COMPONENT_PASS")
    Qt.callLater(Qt.quit)
  }
}
