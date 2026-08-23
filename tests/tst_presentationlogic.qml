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
}
