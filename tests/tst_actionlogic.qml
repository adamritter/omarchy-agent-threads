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
}
