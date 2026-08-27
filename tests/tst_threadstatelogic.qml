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

  function test_reportsReadyAndBlockedNotificationTransitions() {
    var previous = {
      ready: { status: "busy", ready: false, title: "Ready thread" },
      blocked: { status: "busy", ready: false, title: "Blocked thread" },
      unchanged: { status: "blocked", ready: false, title: "Still blocked" }
    }
    var next = {
      ready: { status: "done", ready: true, title: "Ready thread" },
      blocked: { status: "blocked", ready: false, title: "Blocked thread" },
      unchanged: { status: "blocked", ready: false, title: "Still blocked" },
      restored: { status: "done", ready: true, title: "Existing ready thread" }
    }

    var events = ThreadStateLogic.notificationEvents(previous, next)
    compare(events.length, 2)
    compare(events[0].type, "ready")
    compare(events[0].title, "Ready thread")
    compare(events[1].type, "blocked")
    compare(events[1].title, "Blocked thread")
  }

  function test_buildsDesktopAndSoundNotificationCommands() {
    var ready = ThreadStateLogic.notificationCommands({
      type: "ready", title: "Ready thread"
    })
    compare(ready.desktop[0], "notify-send")
    compare(ready.desktop[ready.desktop.length - 1], "Ready thread")
    compare(ready.sound[0], "canberra-gtk-play")
    compare(ready.sound[2], "complete")

    var blocked = ThreadStateLogic.notificationCommands({
      type: "blocked", title: "Blocked thread"
    })
    compare(blocked.desktop[6], "dialog-warning-symbolic")
    compare(blocked.sound[2], "dialog-warning")
    compare(blocked.sound[4], "Agent thread needs attention")
  }

  function test_ordersReadyThreadsAcrossProviders() {
    var local = [
      { id: "local-old", updatedAt: 10 },
      { id: "local-ready", updatedAt: 20 }
    ]
    var hosts = [{
      id: "claude-local",
      providerType: "claude",
      threads: [
        { id: "claude-seen", updatedAt: 50, unread: false },
        { id: "claude-ready", updatedAt: 30, unread: true }
      ]
    }, {
      id: "codex-remote",
      providerType: "codex",
      threads: [{ id: "remote-ready", updatedAt: 40, unread: true }]
    }]

    var targets = ThreadStateLogic.readyThreadTargets(
      local, { "local-ready": true }, hosts)
    compare(targets.length, 3)
    compare(targets[0].threadId, "remote-ready")
    compare(targets[0].hostId, "codex-remote")
    compare(targets[0].providerType, "codex")
    compare(targets[0].scope, "codex-remote")
    compare(targets[1].threadId, "claude-ready")
    compare(targets[2].threadId, "local-ready")
    compare(targets[2].hostId, "provider-codex")
    compare(targets[2].scope, "local")
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

  function test_mergesProviderUnreadTransitionsWithoutMutatingSnapshots() {
    var previous = [
      { id: "finished", status: { type: "active" }, unread: false },
      { id: "token", status: { type: "idle" }, completionToken: "old" },
      { id: "active", status: { type: "active" }, unread: true }
    ]
    var incoming = [
      { id: "finished", status: { type: "idle" } },
      { id: "token", status: { type: "idle" }, completionToken: "new" },
      { id: "active", status: { type: "idle" } },
      { id: "attention", status: { type: "idle" }, attention: true }
    ]
    var merged = ThreadStateLogic.mergeProviderUnread(previous, incoming, "active")
    verify(merged[0].unread)
    verify(merged[1].unread)
    verify(!merged[2].unread)
    verify(merged[3].unread)
    verify(incoming[0].unread === undefined)
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
