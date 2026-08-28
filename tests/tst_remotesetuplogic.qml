// Purpose: Verifies remotesetuplogic behavior with Qt Quick Test.
import QtQuick
import QtTest
import "../logic/RemoteSetupLogic.js" as RemoteSetupLogic

TestCase {
  name: "RemoteSetupLogic"

  function test_derivesSetupStateForNewAndExistingHosts() {
    var created = RemoteSetupLogic.setupState("", null, "claude", "http")
    verify(created.accepted)
    compare(created.provider, "claude")
    compare(created.type, "ssh")

    var existing = RemoteSetupLogic.setupState("dev", {
      providerType: "opencode", type: "http"
    }, "codex", "ssh")
    verify(existing.accepted)
    compare(existing.id, "dev")
    compare(existing.provider, "opencode")
    compare(existing.type, "http")
  }

  function test_rejectsMissingAndUnsupportedHosts() {
    verify(!RemoteSetupLogic.setupState("missing", null, "codex", "ssh").accepted)
    verify(!RemoteSetupLogic.setupState("", null, "unknown", "ssh").accepted)
  }

  function test_removesOnlyPreferencesOwnedByRemote() {
    var result = RemoteSetupLogic.preferencesAfterRemoval("dev",
      { dev: true, prod: true },
      { "dev:/work/a": true, "prod:/work/b": true },
      {
        "remote:dev": true,
        "project:dev:/work/a": true,
        "project:prod:/work/b": true
      })
    verify(result.collapsedRemotes.dev === undefined)
    verify(result.collapsedRemotes.prod)
    verify(result.collapsedProjects["dev:/work/a"] === undefined)
    verify(result.collapsedProjects["prod:/work/b"])
    verify(result.pinnedSections["remote:dev"] === undefined)
    verify(result.pinnedSections["project:dev:/work/a"] === undefined)
    verify(result.pinnedSections["project:prod:/work/b"])
  }

  function test_expandsSavedRemoteWithoutMutatingInput() {
    var source = { dev: true }
    var expanded = RemoteSetupLogic.expandedRemotes(source, "dev")
    verify(source.dev)
    verify(!expanded.dev)
  }
}
