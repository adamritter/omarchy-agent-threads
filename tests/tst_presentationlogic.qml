import QtQuick
import QtTest
import "../logic/PresentationLogic.js" as PresentationLogic

TestCase {
  name: "PresentationLogic"

  function baseState() {
    return {
      providerError: "",
      activeProvider: "codex",
      providerReady: true,
      providerLoading: false,
      providerLabel: "CODEX",
      totalThreadCount: 12,
      visibleThreadCount: 12,
      projectCount: 3,
      filtered: false,
      movingThread: false,
      renamingThread: false,
      archivingThread: false,
      pinningThread: false
    }
  }

  function test_selectsHeaderTitleByOverlayPriority() {
    compare(PresentationLogic.headerTitle({
      projectPickerOpen: true, remoteSetupOpen: true, renameOpen: true,
      helpOpen: true, providerLabel: "CODEX"
    }), "NEW PROJECT")
    compare(PresentationLogic.headerTitle({
      projectPickerOpen: false, remoteSetupOpen: false, renameOpen: false,
      helpOpen: true, providerLabel: "CLAUDE"
    }), "CLAUDE · HELP")
  }

  function test_calculatesHierarchyIndent() {
    compare(PresentationLogic.hierarchyIndent(0), 0)
    compare(PresentationLogic.hierarchyIndent(1), 32)
    compare(PresentationLogic.hierarchyIndent(2), 64)
    compare(PresentationLogic.hierarchyIndent("invalid"), 0)
  }

  function test_indentsOnlyGroupedThreads() {
    compare(PresentationLogic.threadIndent(false, 2), 0)
    compare(PresentationLogic.threadIndent(true, undefined), 32)
    compare(PresentationLogic.threadIndent(true, 2), 64)
  }

  function test_selectsRowBackgroundByFocusState() {
    compare(PresentationLogic.rowBackgroundRole(false, false, true, true),
      "focused-selection")
    compare(PresentationLogic.rowBackgroundRole(false, false, true, false),
      "unfocused-selection")
    compare(PresentationLogic.rowBackgroundRole(false, true, true, false),
      "unfocused-selection")
    compare(PresentationLogic.rowBackgroundRole(true, false, true, false),
      "unfocused-selection")
    compare(PresentationLogic.rowBackgroundRole(true, false, false, false), "active")
    compare(PresentationLogic.rowBackgroundRole(false, false, false, false), "none")
  }

  function test_prioritizesErrorsAndOperations() {
    var state = baseState()
    state.providerError = "Connection failed"
    state.movingThread = true
    compare(PresentationLogic.statusText(state), "Connection failed")

    state.providerError = ""
    compare(PresentationLogic.statusText(state), "Moving thread to project…")
  }

  function test_reportsFilteredCounts() {
    var state = baseState()
    state.filtered = true
    state.visibleThreadCount = 4
    compare(PresentationLogic.statusText(state),
      "3 projects · 4 of 12 threads · newest first")
  }

  function test_reportsProviderStartup() {
    var state = baseState()
    state.providerReady = false
    compare(PresentationLogic.statusText(state),
      "Connecting to the local Codex App Server…")
  }

  function test_formatsProviderTitlesAndRelativeAge() {
    var choices = [{ id: "codex", label: "CODEX" }]
    compare(PresentationLogic.providerLabel(choices, "codex"), "CODEX")
    compare(PresentationLogic.providerLabel(choices, "claude"), "CLAUDE")
    compare(PresentationLogic.threadTitle({ name: "  Named   thread " }, "CODEX"),
      "Named thread")
    compare(PresentationLogic.threadTitle({ preview: "Fallback" }, "CODEX"),
      "Fallback")
    compare(PresentationLogic.threadTitle({}, "CODEX"), "Untitled CODEX thread")
    compare(PresentationLogic.relativeAge(60, 121000), "1m")
    compare(PresentationLogic.relativeAge(60, 7260000), "2h")
  }

  function test_formatsRateLimits() {
    var now = 1000000
    var weekly = {
      usedPercent: 42,
      windowDurationMins: 10080,
      resetsAt: (now + 2 * 86400000) / 1000
    }
    compare(PresentationLogic.rateLimitText({ primary: weekly },
      { availableCount: 2 }, now), "7d 42% · reset 2d 0h · reset×2")
    compare(PresentationLogic.rateLimitWindowText({
      usedPercent: 5, windowDurationMins: 300
    }), "5h 5%")
  }

  function test_countsProviderThreadsWithoutDoubleCountingLocalProviders() {
    var hosts = [
      { id: "provider-claude", providerType: "claude", threads: [{}, {}] },
      { id: "claude-dev", providerType: "claude", threads: [{}] },
      { id: "codex-dev", providerType: "codex", threads: [{}, {}] }
    ]
    compare(PresentationLogic.totalThreadCount("codex", [{}, {}], hosts), 4)
    compare(PresentationLogic.totalThreadCount("claude", [], hosts), 3)
    compare(PresentationLogic.totalThreadCount("claude", [], hosts.slice().reverse()), 3)
  }

  function test_reportsNavigationPrefixBeforeCounts() {
    var state = baseState()
    state.navigationCount = "12"
    state.navigationFindDirection = 1
    compare(PresentationLogic.statusText(state), "12f…")
    state.navigationFindDirection = 0
    compare(PresentationLogic.statusText(state), "Count: 12")
  }
}
