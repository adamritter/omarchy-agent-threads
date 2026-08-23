import QtQuick
import QtTest
import "../ui"

TestCase {
  id: testCase
  name: "ThreadListModel"

  property string activeProvider: "codex"
  property string searchText: ""
  property int groupPreviewLimit: 10
  property var service: ({})
  property var pinnedSectionState: ({})
  property var collapsedProjectState: ({})
  property var collapsedRemoteState: ({})

  ThreadListModel {
    id: listModel
    controller: testCase
  }

  function cleanText(value) {
    return String(value || "").replace(/\s+/g, " ").trim()
  }

  function providerHost(providerId) {
    var hosts = service.remoteHosts || []
    var wanted = String(providerId || "")
    for (var i = 0; i < hosts.length; i++) {
      if (String(hosts[i].id || "") === "provider-" + wanted) return hosts[i]
    }
    return null
  }

  function projectPath(thread) { return String(thread && thread.cwd || "/home/test") }
  function isProjectPath(path) { return String(path || "") !== "/home/test" }
  function directoryName(path) {
    var parts = String(path || "").replace(/\/$/, "").split("/")
    return parts[parts.length - 1]
  }
  function rowKey(row) {
    if (!row) return ""
    if (row.kind === "remote") return "remote:" + String(row.remoteId || "")
    if (row.kind === "project")
      return "project:" + String(row.remoteId || "local") + ":" + String(row.path || "")
    return "thread:" + String(row.remoteId || "local") + ":"
      + String(row.thread && row.thread.id || "")
  }
  function rowIndexForKey(key) {
    for (var i = 0; i < listModel.viewRows.length; i++)
      if (rowKey(listModel.viewRows[i]) === key) return i
    return -1
  }
  function groupShowsAll(kind, path, remoteId) { return true }
  function groupPreviewKey(kind, path, remoteId) { return kind + ":" + path + ":" + remoteId }
  function sectionPinned(kind, path, remoteId) {
    var key = kind === "remote"
      ? "remote:" + String(remoteId || "")
      : "project:" + String(remoteId || "local") + ":" + String(path || "")
    return pinnedSectionState[key] === true
  }
  function projectCollapsed(path, remoteId) {
    return collapsedProjectState[String(remoteId || "local") + ":"
      + String(path || "")] !== false
  }
  function remoteCollapsed(remoteId) {
    return collapsedRemoteState[String(remoteId || "")] !== false
  }

  function init() {
    activeProvider = "codex"
    searchText = ""
    listModel.selectedIndex = 0
    pinnedSectionState = ({})
    collapsedProjectState = ({
      "local:/work/project": false
    })
    collapsedRemoteState = ({})
    service = {
      threads: [
        { id: "home", name: "Home thread", cwd: "/home/test", updatedAt: 30 },
        { id: "alpha", name: "Alpha", cwd: "/work/project", updatedAt: 20 },
        { id: "beta", name: "Beta", cwd: "/work/project", updatedAt: 10 }
      ],
      remoteHosts: [],
      remotePathForThread: function(host, thread) { return thread.cwd }
    }
  }

  function test_groupsLocalProjects() {
    listModel.rebuildRows("")
    compare(listModel.visibleThreadCount, 3)
    compare(listModel.projectCount, 1)
    compare(listModel.viewRows.length, 4)
    compare(listModel.viewRows[0].kind, "thread")
    compare(listModel.viewRows[1].kind, "project")
    compare(listModel.viewRows[2].thread.id, "alpha")
    compare(listModel.viewRows[3].thread.id, "beta")
  }

  function test_switchesProviderWithoutLeakingCodexRows() {
    activeProvider = "claude"
    service.remoteHosts = [{
      id: "provider-claude",
      providerType: "claude",
      home: "/home/test",
      threads: [{ id: "claude-1", name: "Claude", cwd: "/home/test", updatedAt: 40 }]
    }]
    listModel.rebuildRows("")
    compare(listModel.visibleThreadCount, 1)
    compare(listModel.viewRows.length, 1)
    compare(listModel.viewRows[0].thread.id, "claude-1")
  }

  function test_filtersRows() {
    searchText = "beta"
    listModel.rebuildRows("")
    compare(listModel.visibleThreadCount, 1)
    compare(listModel.projectCount, 1)
    compare(listModel.viewRows.length, 2)
    compare(listModel.viewRows[1].thread.id, "beta")
  }

  function test_filterIgnoresHiddenPromptDetailsAndParentPath() {
    service.threads = [{
      id: "crash",
      name: null,
      preview: "A process crashed on this machine\nPID: 49838",
      cwd: "/srv/8-hidden/work",
      updatedAt: 20
    }]
    searchText = "a 8"
    listModel.rebuildRows("")
    compare(listModel.visibleThreadCount, 0)
    compare(listModel.viewRows.length, 0)
  }

  function test_filterMatchesVisibleFallbackTitleAndProjectName() {
    service.threads = [{
      id: "crash",
      name: null,
      preview: "A process crashed on this machine\nPID: 49838",
      cwd: "/srv/workspace-eight",
      updatedAt: 20
    }]
    searchText = "crashed eight"
    listModel.rebuildRows("")
    compare(listModel.visibleThreadCount, 1)
    compare(listModel.projectCount, 1)
    compare(listModel.viewRows.length, 1)
    compare(listModel.viewRows[0].name, "workspace-eight")

  }

  function test_expandedPinnedProjectShowsThreadsUnderCollapsedRemote() {
    service.threads = []
    service.remoteHosts = [{
      id: "remote-one",
      label: "Remote one",
      providerType: "codex",
      home: "/home/remote",
      threads: [
        { id: "remote-alpha", name: "Alpha", cwd: "/srv/app", updatedAt: 20 },
        { id: "remote-beta", name: "Beta", cwd: "/srv/app", updatedAt: 10 }
      ]
    }]
    pinnedSectionState = ({
      "project:remote-one:/srv/app": true
    })
    collapsedRemoteState = ({
      "remote-one": true
    })

    collapsedProjectState = ({
      "remote-one:/srv/app": true
    })
    listModel.rebuildRows("")
    compare(listModel.viewRows.length, 2)
    compare(listModel.viewRows[0].kind, "remote")
    compare(listModel.viewRows[1].kind, "project")

    collapsedProjectState = ({
      "remote-one:/srv/app": false
    })
    listModel.rebuildRows("")
    compare(listModel.viewRows.length, 4)
    compare(listModel.viewRows[2].thread.id, "remote-alpha")
    compare(listModel.viewRows[3].thread.id, "remote-beta")
  }
}
