import QtQuick
import QtTest
import "../logic/ThreadRowLogic.js" as ThreadRowLogic

TestCase {
  name: "ThreadRowLogic"

  function baseState(row) {
    return {
      row: row,
      activeThreadId: "",
      activeThreadScope: "",
      activeProjectPath: "",
      threadStatus: "done",
      unread: false,
      pinnedSection: false,
      operationRemoteId: "",
      archivingThreadId: "",
      pinningThreadId: "",
      renamingThreadId: "",
      movingThreadId: "",
      threadTitle: "Example",
      launchingProjectPath: "",
      remoteClaudeLoginHostId: "",
      remoteClaudeLoginRunning: false,
      collapsed: false
    }
  }

  function test_derivesThreadStateAndMutationScope() {
    var input = baseState({
      kind: "thread", remoteId: "dev", grouped: true,
      thread: { id: "thread-1", isPinned: true }
    })
    input.activeThreadId = "thread-1"
    input.activeThreadScope = "dev"
    input.threadStatus = "blocked"
    input.unread = true
    input.pinningThreadId = "thread-1"
    input.operationRemoteId = "dev"

    var state = ThreadRowLogic.presentation(input)
    verify(state.threadRow)
    verify(state.groupedThread)
    verify(state.activeThread)
    verify(state.blocked)
    verify(state.unread)
    verify(state.pinning)
    compare(state.threadTitle, "Updating pin…  Example")

    input.operationRemoteId = "other"
    verify(!ThreadRowLogic.presentation(input).pinning)
  }

  function test_derivesProjectAndRemotePresentation() {
    var project = baseState({ kind: "project", path: "/work/app" })
    project.activeProjectPath = "/work/app"
    project.collapsed = true
    project.pinnedSection = true
    var projectState = ThreadRowLogic.presentation(project)
    verify(projectState.activeProject)
    verify(projectState.pinnedSection)
    compare(projectState.sectionIndicator, "\uf07b")
    compare(projectState.sectionSubtitle, "/work/app")

    var remote = baseState({
      kind: "remote", remoteId: "claude-dev",
      host: { providerType: "claude", authenticated: false, available: true }
    })
    remote.remoteClaudeLoginHostId = "claude-dev"
    remote.remoteClaudeLoginRunning = true
    var remoteState = ThreadRowLogic.presentation(remote)
    verify(remoteState.needsRemoteClaudeAction)
    verify(remoteState.loggingInRemoteClaude)
    compare(remoteState.sectionSubtitle, "CLAUDE")
    compare(remoteState.sectionIndicator, "▾")
  }

  function test_prioritizesOperationTitles() {
    compare(ThreadRowLogic.threadTitle("Title", {
      renaming: true, pinning: true, moving: true, archiving: true, pinned: true
    }), "Renaming…  Title")
    compare(ThreadRowLogic.threadTitle("Title", {
      renaming: false, pinning: false, moving: false, archiving: false, pinned: true
    }), "󰐃  Title")
  }
}
