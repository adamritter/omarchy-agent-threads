import QtQuick
import QtTest
import "../logic/ActionLogic.js" as ActionLogic

TestCase {
  name: "ActionLogic"

  function test_selectsRowsSafely() {
    var rows = [{ id: "one" }]
    compare(ActionLogic.selectedRow(rows, 0).id, "one")
    compare(ActionLogic.selectedRow(rows, -1), null)
    compare(ActionLogic.selectedRow(rows, 1), null)
  }

  function test_targetsLocalAndSelectedRemoteThreads() {
    var local = ActionLogic.newThreadTarget("codex", "/home/test", null, null)
    compare(local.remoteId, "")
    compare(local.path, "/home/test")
    compare(local.error, "")

    var remote = ActionLogic.newThreadTarget("codex", "/home/test", {
      remoteId: "remote-one", path: "/srv/app"
    }, null)
    compare(remote.remoteId, "remote-one")
    compare(remote.path, "/srv/app")
  }

  function test_requiresNonCodexProviderHost() {
    var missing = ActionLogic.newThreadTarget("claude", "/home/test", null, null)
    compare(missing.error, "provider-not-ready")

    var ready = ActionLogic.newThreadTarget("claude", "/home/test", null, {
      id: "provider-claude", home: "/home/test"
    })
    compare(ready.remoteId, "provider-claude")
    compare(ready.path, "/home/test")
  }

  function test_configuresPickerFromSelectedRemote() {
    var host = {
      id: "remote-one", providerType: "opencode", home: "/srv", type: "ssh"
    }
    var target = ActionLogic.projectPickerTarget(
      "codex", "/home/test", { remoteId: "remote-one", path: "/srv/app" },
      host, null)
    compare(target.hostId, "remote-one")
    compare(target.providerType, "opencode")
    compare(target.path, "/srv/app")
    compare(target.error, "")
  }

  function test_usesProviderHomeAsPickerFallback() {
    var host = { id: "provider-claude", providerType: "claude", home: "/remote/home" }
    var target = ActionLogic.projectPickerTarget(
      "claude", "/home/test", null, null, host)
    compare(target.hostId, "provider-claude")
    compare(target.providerType, "claude")
    compare(target.path, "/remote/home")
  }

  function test_opensLocalTerminalFromHomeThreadAndProject() {
    var home = ActionLogic.terminalTarget("codex", "/home/test", null, null)
    compare(home.mode, "local")
    compare(home.path, "/home/test")

    var project = ActionLogic.terminalTarget("codex", "/home/test", {
      kind: "project", path: "/work/app"
    }, null)
    compare(project.mode, "local")
    compare(project.path, "/work/app")
  }

  function test_opensSshTerminalAtHostAndProjectPaths() {
    var host = {
      id: "remote-one", type: "ssh", sshHost: "dev", home: "/home/dev"
    }
    var remote = ActionLogic.terminalTarget("codex", "/home/test", {
      kind: "remote", remoteId: "remote-one", path: "/home/dev", host: host
    }, null)
    compare(remote.mode, "ssh")
    compare(remote.endpoint, "dev")
    compare(remote.path, "/home/dev")

    var project = ActionLogic.terminalTarget("codex", "/home/test", {
      kind: "project", remoteId: "remote-one", path: "/srv/app", host: host
    }, null)
    compare(project.mode, "ssh")
    compare(project.path, "/srv/app")
  }

  function test_opensLocalProviderTerminalAndRejectsAppServer() {
    var provider = {
      id: "provider-claude", type: "provider", home: "/home/test"
    }
    var local = ActionLogic.terminalTarget(
      "claude", "/home/test", null, provider)
    compare(local.mode, "local")
    compare(local.path, "/home/test")

    var appServer = ActionLogic.terminalTarget("codex", "/home/test", {
      remoteId: "server", path: "/srv/app",
      host: { id: "server", type: "app-server", home: "/srv" }
    }, null)
    compare(appServer.error, "ssh-required")
  }

  function test_defaultsThreadFrontendToTerminal() {
    compare(ActionLogic.normalizeThreadFrontend(""), "terminal")
    compare(ActionLogic.normalizeThreadFrontend("unknown"), "terminal")
    compare(ActionLogic.normalizeThreadFrontend("agent-chat"), "agent-chat")
  }

  function test_buildsAgentChatResumeAndNewThreadCommands() {
    compare(ActionLogic.agentChatCommand(
      "/plugin/bin/omarchy-agent-chat", "thread-1", "/work/app",
      "gpt-test", "high"), [
        "/plugin/bin/omarchy-agent-chat", "resume", "thread-1",
        "-C", "/work/app", "--model", "gpt-test", "--effort", "high"
      ])
    compare(ActionLogic.agentChatCommand(
      "/plugin/bin/omarchy-agent-chat", "", "/work/new", "", ""), [
        "/plugin/bin/omarchy-agent-chat", "-C", "/work/new"
      ])
  }
}
