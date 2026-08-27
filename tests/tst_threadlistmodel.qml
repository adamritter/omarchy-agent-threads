import QtQuick
import QtTest
import "../ui"
import "../logic/ThreadListLogic.js" as ThreadListLogic

TestCase {
  id: testCase
  name: "ThreadListModel"

  property string activeProvider: "codex"
  property string searchText: ""
  property int groupPreviewLimit: 10
  property string homePath: "/home/test"
  property string workPath: "/home/test/Work"
  property string codexScratchRoot: "/home/test/Documents/Codex/"
  property var expandedGroups: ({})
  property var service: ({})

  ThreadListModel {
    id: listModel
    controller: testCase
  }

  function init() {
    activeProvider = "codex"
    searchText = ""
    listModel.selectedIndex = 0
    expandedGroups = ({})
    service = {
      threads: [
        { id: "home", name: "Home thread", cwd: "/home/test", updatedAt: 30 },
        { id: "alpha", name: "Alpha", cwd: "/work/project", updatedAt: 20 },
        { id: "beta", name: "Beta", cwd: "/work/project", updatedAt: 10 }
      ],
      projects: [],
      remoteHosts: [],
      collapsedProjects: ({ "local:/work/project": false }),
      collapsedRemotes: ({}),
      pinnedSections: ({}),
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

  function test_buildsStableRowAndSectionKeys() {
    compare(ThreadListLogic.rowKey({ kind: "remote", remoteId: "dev" }),
      "remote:dev")
    compare(ThreadListLogic.rowKey({
      kind: "project", remoteId: "dev", path: "/srv/app"
    }), "project:dev:/srv/app")
    compare(ThreadListLogic.rowKey({
      kind: "thread", thread: { id: "one" }
    }), "thread:local:one")
    compare(ThreadListLogic.sectionPinKey("project", "/srv/app", "dev"),
      "project:dev:/srv/app")
  }

  function test_resolvesLocalAndRemoteThreadPaths() {
    var projects = [{ id: "project", roots: [{ path: "/work/project" }] }]
    compare(ThreadListLogic.pathForThread(
      projects, { projectId: "project", cwd: "/fallback" }, "/home/test", false),
      "/work/project")
    compare(ThreadListLogic.pathForThread(
      projects, { projectId: "project", cwd: "/runtime" }, "/home/test", true),
      "/runtime")
  }

  function test_buildsUniqueProjectMoveTargets() {
    var projects = [
      { id: "current", name: "Current", roots: [{ path: "/work/current" }] },
      { id: "beta", name: "Beta", roots: [{ path: "/work/beta" }] }
    ]
    var threads = [
      { id: "one", projectId: "current" },
      { id: "two", cwd: "/work/alpha" },
      { id: "three", cwd: "/work/alpha" }
    ]
    var targets = ThreadListLogic.projectMoveTargets(
      projects, threads, threads[0], {
        homePath: "/home/test",
        workPath: "/home/test/Work",
        scratchRoot: "/home/test/Documents/Codex/"
    })
    compare(targets.length, 2)
    compare(targets[0].name, "Beta")
    compare(targets[1].name, "alpha")
    compare(ThreadListLogic.projectForRoot(projects, "/work/beta").id, "beta")
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
    service.pinnedSections = ({
      "project:remote-one:/srv/app": true
    })
    service.collapsedRemotes = ({
      "remote-one": true
    })

    service.collapsedProjects = ({
      "remote-one:/srv/app": true
    })
    listModel.rebuildRows("")
    compare(listModel.viewRows.length, 2)
    compare(listModel.viewRows[0].kind, "remote")
    compare(listModel.viewRows[1].kind, "project")

    service.collapsedProjects = ({
      "remote-one:/srv/app": false
    })
    listModel.rebuildRows("")
    compare(listModel.viewRows.length, 4)
    compare(listModel.viewRows[2].thread.id, "remote-alpha")
    compare(listModel.viewRows[3].thread.id, "remote-beta")
  }
}
