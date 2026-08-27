import QtQuick
import QtTest

SidebarControllerTestBase {
  name: "SidebarControllerNavigation"

  function test_followTargetPrefersPendingActivation() {
    service.activeThreadId = "old"
    service.threads = [
      { id: "old", cwd: "/work/a" },
      { id: "requested", cwd: "/work/b" }
    ]
    service.launchingThreadId = "requested"
    compare(controller.followTargetThreadId(), "requested")

    service.launchingThreadId = ""
    compare(controller.followTargetThreadId(), "old")
  }

  function test_failedActivationDoesNotSnapSelectionBackToActiveThread() {
    viewRows = [
      { kind: "thread", path: "/work/a", thread: { id: "old" } },
      { kind: "thread", path: "/work/b", thread: { id: "requested" } }
    ]
    service.activeThreadId = "old"

    compare(controller.activateRow(1, "pointer"), "thread:requested")
    service.launchingThreadId = ""
    service.failedLaunchThreadId = "requested"

    compare(controller.followTargetThreadId(), "requested")
    controller.followActiveThread(true)
    compare(selectedIndex, 1)
  }

  function test_rejectedActivationDoesNotCreateAnIntent() {
    viewRows = [{
      kind: "thread", path: "/work/a", thread: { id: "requested" }
    }]
    service.acceptLaunch = false

    compare(controller.activateRow(0, "keyboard"), "")
    compare(controller.activationIntentThreadId, "")
    compare(service.launchingThreadId, "")
  }

  function test_activatesRemoteThreadThroughRemoteProvider() {
    viewRows = [
      { kind: "thread", path: "/work/local", thread: { id: "local" } },
      { kind: "remote", remoteId: "dev" },
      { kind: "project", remoteId: "dev", path: "/srv/app" },
      { kind: "thread", remoteId: "dev", path: "/srv/app",
        thread: { id: "remote" } }
    ]
    service.activeThreadId = "local"

    compare(controller.activateAdjacentThread(1), "thread:remote")
    compare(openedRemoteThreadCount, 1)
    compare(openedRemoteId, "dev")
    compare(openedThreadId, "remote")
  }

  function test_opensLocalProjectTerminal() {
    viewRows = [{ kind: "project", path: "/work/app" }]
    selectedIndex = 0
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "local")
    compare(terminalPath, "/work/app")
    compare(releaseCount, 1)
  }

  function test_opensSshHostAndFolderTerminals() {
    var host = {
      id: "dev", type: "ssh", sshHost: "devbox", home: "/home/dev"
    }
    viewRows = [{
      kind: "remote", remoteId: "dev", path: "/home/dev", host: host
    }]
    selectedIndex = 0
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "ssh")
    compare(terminalEndpoint, "devbox")
    compare(terminalPath, "/home/dev")

    viewRows = [{
      kind: "project", remoteId: "dev", path: "/srv/app", host: host
    }]
    terminalCount = 0
    verify(controller.openSelectedTerminal())
    compare(terminalCount, 1)
    compare(terminalPath, "/srv/app")
  }

  function test_usesLocalProviderHomeWithoutSelection() {
    activeProvider = "claude"
    activeProviderHost = {
      id: "provider-claude", type: "provider", home: "/home/test"
    }
    verify(controller.openSelectedTerminal())
    compare(terminalMode, "local")
    compare(terminalPath, "/home/test")
  }

  function test_rejectsAppServerWithoutSsh() {
    viewRows = [{
      kind: "remote", remoteId: "server", path: "/srv/app",
      host: { id: "server", type: "app-server", home: "/srv" }
    }]
    selectedIndex = 0
    verify(!controller.openSelectedTerminal())
    compare(terminalCount, 0)
    compare(releaseCount, 0)
    verify(service.launchError.indexOf("requires an SSH connection") >= 0)
  }
}
