import QtQuick
import QtTest
import "../providers" as Providers

TestCase {
  id: testCase
  name: "RemoteAgentLaunch"

  property int beginCount: 0
  property int focusCount: 0
  property int openCount: 0
  property int observedCount: 0
  property bool cachedFocusAvailable: true
  property string begunThreadId: ""
  property string begunSource: ""
  property string observedThreadId: ""
  property var command: []

  QtObject {
    id: mutations
    function beginThreadLaunch(threadId, source) {
      testCase.beginCount++
      testCase.begunThreadId = String(threadId || "")
      testCase.begunSource = String(source || "")
      return 73
    }
    function observeActiveThread(threadId, source) {
      testCase.observedCount++
      testCase.observedThreadId = String(threadId || "")
      return true
    }
  }

  QtObject {
    id: providerModels
    function selectedModelForProvider(providerType) { return "model-test" }
    function selectedEffortForProvider(providerType) { return "medium" }
    function selectedAgentForProvider(providerType) { return "agent-test" }
  }

  QtObject {
    id: controller
    readonly property var mutations: mutations
    readonly property var settings: providerModels
    property string launchError: ""
    property string launchingProjectPath: ""
    property string codexServiceTier: "fast"
  }

  QtObject {
    id: provider
    readonly property var controller: controller
    property string openHelperPath: "/test/open"
    property string configPath: "/test/remotes.json"
    property bool openIsNew: false
    property string openHostId: ""
    property int openRequestId: 0
    property string openThreadId: ""
    property string pendingHostId: ""
    property string pendingPath: ""
    property string pendingWindowAddress: ""
    property int pendingAttempts: 0
    property var pendingKnownIds: ({})
    function hostById(hostId) {
      return String(hostId || "") === "remote-a" ? {
        id: "remote-a", available: true, home: "/srv", threads: []
      } : null
    }
    function providerTypeForEntry(host) { return "codex" }
    function providerLabel(host) { return "Codex" }
    function pathForThread(host, thread) { return String(thread.cwd || host.home) }
    function stopNewResolveTimer() {}
  }

  QtObject {
    id: processes
    property bool openRunning: false
    function runOpen(nextCommand) {
      testCase.openCount++
      testCase.command = nextCommand
    }
  }

  QtObject {
    id: launches
    function focusCachedThread(threadId, hostId) {
      testCase.focusCount++
      return testCase.cachedFocusAvailable
    }
    function map(threadId, address, hostId, serverUrl) { return true }
  }

  Providers.RemoteAgentLaunch {
    id: launch
    provider: provider
    processes: processes
    launches: launches
  }

  function init() {
    beginCount = 0
    focusCount = 0
    openCount = 0
    observedCount = 0
    cachedFocusAvailable = true
    begunThreadId = ""
    begunSource = ""
    observedThreadId = ""
    command = []
    controller.launchError = ""
    provider.openRequestId = 0
    provider.openThreadId = ""
  }

  function test_verifiedCachedWindowBypassesProcessDiscovery() {
    verify(launch.openThread("remote-a", {
      id: "thread-beta", cwd: "/srv/project"
    }, "", "keyboard"))

    compare(focusCount, 1)
    compare(beginCount, 1)
    compare(begunThreadId, "thread-beta")
    compare(begunSource, "keyboard")
    compare(observedCount, 1)
    compare(observedThreadId, "thread-beta")
    compare(openCount, 0)
    compare(provider.openRequestId, 0)
    compare(provider.openThreadId, "")
  }

  function test_staleCacheFallsBackToVerifiedProcessDiscovery() {
    cachedFocusAvailable = false
    verify(launch.openThread("remote-a", {
      id: "thread-beta", cwd: "/srv/project"
    }, "", "keyboard"))

    compare(focusCount, 1)
    compare(beginCount, 1)
    compare(observedCount, 0)
    compare(openCount, 1)
    compare(provider.openRequestId, 73)
    compare(provider.openThreadId, "thread-beta")
    compare(command[4], "remote-a")
    compare(command[6], "/srv/project")
    compare(command[8], "thread-beta")
  }
}
