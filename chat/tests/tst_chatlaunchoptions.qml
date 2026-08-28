import QtQuick
import QtTest
import "../logic/ChatLaunchOptions.js" as ChatLaunchOptions

TestCase {
  name: "ChatLaunchOptions"

  function test_normalizesLaunchOptions() {
    var options = ChatLaunchOptions.parseJson(JSON.stringify({
      explicit: true,
      threadId: "thread-1",
      model: "gpt-test",
      configOverrides: ["service_tier=fast"]
    }))
    compare(options.explicit, true)
    compare(options.threadId, "thread-1")
    compare(options.model, "gpt-test")
    compare(options.approvalsReviewer, "user")
    compare(options.configOverrides.length, 1)
  }

  function test_mapsSandboxModesToProtocolPolicies() {
    compare(ChatLaunchOptions.sandboxPolicy("read-only").type, "readOnly")
    compare(ChatLaunchOptions.sandboxPolicy("workspace-write").type, "workspaceWrite")
    compare(ChatLaunchOptions.sandboxPolicy("danger-full-access").type, "dangerFullAccess")
    verify(ChatLaunchOptions.sandboxPolicy("") === null)
  }

  function test_labelsApprovalAndConnections() {
    compare(ChatLaunchOptions.approvalLabel("on-request", "auto_review"), "Auto review")
    compare(ChatLaunchOptions.approvalLabel("never", "user"), "Never ask")
    compare(ChatLaunchOptions.connectionLabel(""), "Local")
    compare(ChatLaunchOptions.connectionLabel("wss://example.test"), "wss://example.test")
  }

  function test_buildsTransportCommands() {
    compare(ChatLaunchOptions.transportCommand(
      "", "", "/guard", "/helper", ["model=x"]),
      ["/guard", "--", "codex", "app-server", "-c", "model=x"])
    compare(ChatLaunchOptions.transportCommand(
      "wss://example.test", "TOKEN", "/guard", "/helper", []),
      ["/guard", "--", "/helper", "wss://example.test", "TOKEN", ""])
    compare(ChatLaunchOptions.transportCommand(
      "unix://", "", "/guard", "/helper", []),
      ["/guard", "--", "codex", "app-server", "proxy"])
    compare(ChatLaunchOptions.transportCommand(
      "unix:///run/user/1000/codex.sock", "", "/guard", "/helper", []),
      ["/guard", "--", "codex", "app-server", "proxy", "--sock",
        "/run/user/1000/codex.sock"])
  }

  function test_buildsProtocolOverrides() {
    var options = {
      cwd: "/workspace",
      model: "gpt-test",
      effort: "high",
      serviceTier: "fast",
      approvalPolicy: "on-request",
      approvalsReviewer: "auto_review",
      sandbox: "workspace-write"
    }
    var thread = ChatLaunchOptions.threadParams({ threadId: "thread-1" }, options)
    compare(thread.threadId, "thread-1")
    compare(thread.cwd, "/workspace")
    compare(thread.model, "gpt-test")
    compare(thread.serviceTier, "fast")
    compare(thread.approvalPolicy, "on-request")
    compare(thread.approvalsReviewer, "auto_review")
    compare(thread.sandbox, "workspace-write")

    var turn = ChatLaunchOptions.turnParams({ threadId: "thread-1", input: [] }, options)
    compare(turn.effort, "high")
    compare(turn.sandboxPolicy.type, "workspaceWrite")
    compare(turn.serviceTier, "fast")
  }
}
