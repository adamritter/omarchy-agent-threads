import QtQuick
import QtTest
import "../ui" as Ui

TestCase {
  id: testCase
  name: "SidebarController"

  property string activeProvider: "codex"
  property string homePath: "/home/test"
  property var activeProviderHost: null
  property var viewRows: []
  property int selectedIndex: -1
  property int releaseCount: 0
  property int terminalCount: 0
  property string terminalMode: ""
  property string terminalEndpoint: ""
  property string terminalPath: ""

  QtObject {
    id: fakeService
    property string launchError: ""
    function openTerminal(mode, endpoint, path) {
      testCase.terminalCount++
      testCase.terminalMode = mode
      testCase.terminalEndpoint = endpoint
      testCase.terminalPath = path
      return true
    }
  }

  Item { id: fakeListView }

  Ui.SidebarController {
    id: controller
    panel: testCase
    listView: fakeListView
  }

  property var service: fakeService

  function releaseSidebarFocus(force) { releaseCount++ }

  function init() {
    activeProvider = "codex"
    activeProviderHost = null
    viewRows = []
    selectedIndex = -1
    releaseCount = 0
    terminalCount = 0
    terminalMode = ""
    terminalEndpoint = ""
    terminalPath = ""
    fakeService.launchError = ""
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
    verify(fakeService.launchError.indexOf("requires an SSH connection") >= 0)
  }
}
