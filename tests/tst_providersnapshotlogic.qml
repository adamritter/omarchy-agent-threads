import QtQuick
import QtTest
import "../logic/ProviderSnapshotLogic.js" as ProviderSnapshotLogic

TestCase {
  name: "ProviderSnapshotLogic"

  function test_roundTripsProviderData() {
    var encoded = ProviderSnapshotLogic.encode({
      codex: { threads: [{ id: "local-1" }] },
      remoteHosts: [{ id: "dev", threads: [{ id: "remote-1" }] }]
    })
    var decoded = ProviderSnapshotLogic.decode(encoded)
    compare(decoded.version, 1)
    compare(decoded.codex.threads[0].id, "local-1")
    compare(decoded.remoteHosts[0].threads[0].id, "remote-1")
  }

  function test_rejectsInvalidAndUnknownSnapshots() {
    verify(ProviderSnapshotLogic.decode("") === null)
    verify(ProviderSnapshotLogic.decode("not-json") === null)
    verify(ProviderSnapshotLogic.decode('{"version":2}') === null)
  }

  function test_hydratesHostsWithoutStartupLoadingState() {
    var host = ProviderSnapshotLogic.hydratedHost({
      id: "dev",
      label: "Cached",
      loading: true,
      threads: [{ id: "thread-1" }]
    }, { label: "Default", type: "ssh" })
    compare(host.id, "dev")
    compare(host.label, "Cached")
    compare(host.type, "ssh")
    compare(host.threads.length, 1)
    verify(!host.loading)
  }

  function test_filtersInvalidHostSnapshots() {
    var hosts = ProviderSnapshotLogic.hydratedHosts([
      { id: "dev", loading: true },
      { label: "Missing id" },
      null
    ])
    compare(hosts.length, 1)
    compare(hosts[0].id, "dev")
    verify(!hosts[0].loading)
  }

  function test_normalizesCodexSnapshotState() {
    var state = ProviderSnapshotLogic.codexState({
      codex: {
        threads: [{ id: "one" }],
        projects: "invalid",
        rateLimits: { primary: { usedPercent: 5 } },
        models: null,
        activeThreadId: 42
      }
    })
    compare(state.threads.length, 1)
    compare(state.projects.length, 0)
    compare(state.models.length, 0)
    compare(state.rateLimits.primary.usedPercent, 5)
    compare(state.activeThreadId, "42")
  }
}
