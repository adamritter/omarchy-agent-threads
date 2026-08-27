import QtQuick
import QtTest
import "../logic/ThreadMutationLogic.js" as ThreadMutationLogic

TestCase {
  name: "ThreadMutationLogic"

  function test_allowsOnlyOneMutationAtATime() {
    var started = ThreadMutationLogic.beginMutation(
      ThreadMutationLogic.idleMutationState(), "rename", "thread-a", "")
    verify(started.accepted)
    compare(started.state.kind, "rename")
    compare(started.state.threadId, "thread-a")

    var overlapping = ThreadMutationLogic.beginMutation(
      started.state, "pin", "thread-b", "")
    verify(!overlapping.accepted)
    compare(overlapping.state.kind, "rename")
    compare(overlapping.error,
      "Wait for the current thread action to finish before starting pin")
  }

  function test_blocksArchivingTheActiveThread() {
    var result = ThreadMutationLogic.beginMutation(
      ThreadMutationLogic.idleMutationState(), "archive", "active", "active")
    verify(!result.accepted)
    compare(result.error,
      "Close the Codex session that is using this thread before archiving it")
  }

  function test_normalizesMutationFailures() {
    var writerMessage =
      "Close the Codex session that is using this thread before archiving it"
    compare(ThreadMutationLogic.archiveErrorMessage(
      "thread already has an active writer (code -32600)"), writerMessage)
    compare(ThreadMutationLogic.archiveErrorMessage("permission denied"),
      "permission denied")
    compare(ThreadMutationLogic.archiveErrorMessage(""),
      "Could not archive the Codex thread")
    compare(ThreadMutationLogic.mutationErrorMessage("rename", ""),
      "Could not rename the thread")
    compare(ThreadMutationLogic.mutationErrorMessage("pin", "permission denied"),
      "permission denied")
  }

  function test_ignoresStaleCompletion() {
    var started = ThreadMutationLogic.beginMutation(
      ThreadMutationLogic.idleMutationState(), "rename", "thread-a", "")
    var stale = ThreadMutationLogic.completeMutation(started.state, "pin")
    verify(!stale.applied)
    compare(stale.state.kind, "rename")

    var completed = ThreadMutationLogic.completeMutation(started.state, "rename")
    verify(completed.applied)
    compare(completed.state.kind, "")
  }

  function test_tracksMoveAsTheSameExclusiveMutation() {
    var started = ThreadMutationLogic.beginMove(
      ThreadMutationLogic.idleMutationState(), "thread-a", "/work/demo", "Demo")
    verify(started.accepted)
    compare(started.state.kind, "move")
    compare(started.state.movePath, "/work/demo")
    compare(started.state.moveName, "Demo")

    var blocked = ThreadMutationLogic.beginMutation(
      started.state, "archive", "thread-b", "")
    verify(!blocked.accepted)
  }

  function test_restoresOptimisticallyArchivedThreadAndClearsTombstone() {
    var source = [{ id: "one" }, { id: "two" }]
    var started = ThreadMutationLogic.beginMutation(
      ThreadMutationLogic.idleMutationState(), "archive", "one", "")
    var captured = ThreadMutationLogic.withArchiveSnapshot(
      started.state, source[0], 0)
    var hidden = ThreadMutationLogic.withArchiveTombstone(captured, "one", true)
    var restored = ThreadMutationLogic.restoreArchive([source[1]], hidden)

    verify(restored.applied)
    compare(restored.items.length, 2)
    compare(restored.items[0].id, "one")
    compare(restored.state.kind, "")
    verify(restored.state.archiveTombstones.one !== true)
  }

  function test_pinValueCannotLeakIntoAnotherMutation() {
    var pin = ThreadMutationLogic.beginMutation(
      ThreadMutationLogic.idleMutationState(), "pin", "one", "")
    var pending = ThreadMutationLogic.withPinValue(pin.state, true)
    verify(pending.pinValue)

    var completed = ThreadMutationLogic.completeMutation(pending, "pin")
    verify(!completed.state.pinValue)
    var rename = ThreadMutationLogic.beginMutation(
      completed.state, "rename", "two", "")
    verify(!ThreadMutationLogic.withPinValue(rename.state, true).pinValue)
  }
}
