import QtQuick
import QtTest
import "../logic/ThreadStateLogic.js" as ThreadStateLogic

TestCase {
  name: "ThreadStateLogic"

  readonly property string pinnedSectionId: "pinned-section"

  function test_detectsPinnedThreads() {
    verify(ThreadStateLogic.threadIsPinned({ isPinned: true }, pinnedSectionId))
    verify(ThreadStateLogic.threadIsPinned({
      section: { id: pinnedSectionId, name: "Anything" }
    }, pinnedSectionId))
    verify(ThreadStateLogic.threadIsPinned({ section: { name: "Pinned" } }, pinnedSectionId))
    verify(!ThreadStateLogic.threadIsPinned({ section: { name: "Archived" } }, pinnedSectionId))
  }

  function test_normalizesPinsWithoutMutatingInput() {
    var source = [{ id: "one", section: { name: "Pinned" } }, { id: "two" }]
    var normalized = ThreadStateLogic.normalizePinnedThreads(source, pinnedSectionId)
    verify(normalized[0].isPinned)
    verify(!normalized[1].isPinned)
    verify(source[0].isPinned === undefined)
  }

  function test_marksCompletedBackgroundThreadsUnread() {
    var unread = ThreadStateLogic.nextUnreadThreads(
      { one: "busy", two: "blocked", active: "busy" },
      { old: true },
      { one: "done", two: "done", active: "done" },
      "active")
    verify(unread.old)
    verify(unread.one)
    verify(unread.two)
    verify(unread.active !== true)
  }

  function test_mapsRemoteStatuses() {
    compare(ThreadStateLogic.remoteStatusValue("active"), "busy")
    compare(ThreadStateLogic.remoteStatusValue({ type: "idle" }), "done")
    compare(ThreadStateLogic.remoteStatusValue({
      type: "active", activeFlags: ["waitingOnApproval"]
    }), "blocked")
    compare(ThreadStateLogic.remoteStatusValue({
      type: "active", activeFlags: ["waitingOnUserInput"]
    }), "blocked")
  }

  function test_appliesPinsAndArchiveTombstones() {
    var source = [{ id: "one", name: "Old" }, { id: "two" }]
    var pinned = ThreadStateLogic.applyThreadPin(
      source, "one", true, { name: "Returned" })
    compare(pinned[0].name, "Returned")
    verify(pinned[0].isPinned)
    compare(ThreadStateLogic.threadIndex(pinned, "two"), 1)
    compare(ThreadStateLogic.threadIndex(pinned, "missing"), -1)

    var visible = ThreadStateLogic.withoutArchiveTombstones(
      pinned, { one: true })
    compare(visible.length, 1)
    compare(visible[0].id, "two")
  }
}
