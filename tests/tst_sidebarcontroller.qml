import QtQuick
import QtTest

SidebarControllerTestBase {
  name: "SidebarControllerActions"

  function test_clickActivationReleasesFocusBeforeOpeningThread() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } }
    ]

    compare(controller.activateRow(1), "thread:alpha")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 1)
    compare(openedThreadId, "alpha")
    compare(activationEvents.join(","), "release,open:alpha")
  }

  function test_derivesRowPresentationAtControllerBoundary() {
    service.activeThreadId = "busy"
    service.threads = [{ id: "busy", name: "Busy", cwd: "/work" }]
    var state = controller.rowPresentation({
      kind: "thread", path: "/work", thread: service.threads[0]
    }, 0, false)
    verify(state.threadRow)
    verify(state.activeThread)
    verify(state.busy)
    compare(state.threadTitle, "Busy")
  }

  function test_routesRowCommandsThroughController() {
    var threadRow = {
      kind: "thread", path: "/work/app", thread: { id: "thread-1" }
    }
    verify(controller.archiveRow(threadRow))
    compare(archiveCount, 1)
    verify(controller.renameRow(threadRow))
    compare(renamedThreadId, "thread-1")
    verify(controller.createThreadForRow({ kind: "project", path: "/work/new" }))
    compare(createdPath, "/work/new")
  }

  function test_selectsAdjacentThreadsAndSkipsStructuralRows() {
    viewRows = [
      { kind: "remote", id: "host" },
      { kind: "project", path: "/work/a" },
      { kind: "thread", id: "alpha" },
      { kind: "more", id: "more" },
      { kind: "project", path: "/work/b" },
      { kind: "thread", id: "beta" }
    ]
    selectedIndex = 0
    compare(controller.selectAdjacentThread(1), "thread:alpha")
    compare(selectedIndex, 2)
    compare(listView.positionedIndex, 2)
    compare(controller.selectAdjacentThread(1), "thread:beta")
    compare(selectedIndex, 5)
    compare(controller.selectAdjacentThread(1), "thread:alpha")
    compare(selectedIndex, 2)
    compare(controller.selectAdjacentThread(-1), "thread:beta")
    compare(selectedIndex, 5)
  }

  function test_selectAdjacentThreadHandlesEmptyAndUnselectedLists() {
    compare(controller.selectAdjacentThread(1), "")
    viewRows = [{ kind: "project", path: "/work" }, { kind: "thread", id: "only" }]
    compare(controller.selectAdjacentThread(1), "thread:only")
    selectedIndex = -1
    compare(controller.selectAdjacentThread(-1), "thread:only")
  }

  function test_activatesFromActiveThreadInsteadOfUiSelection() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } },
      { kind: "project", path: "/work/b" },
      { kind: "thread", path: "/work/b", thread: { id: "beta" } }
    ]
    service.activeThreadId = "alpha"
    selectedIndex = 3

    compare(controller.activateAdjacentThread(1), "thread:beta")
    compare(selectedIndex, 3)
    compare(openedThreadCount, 1)
    compare(openedThreadId, "beta")
    compare(controller.followTargetThreadId(), "beta")
    compare(releaseCount, 1)

    service.activeThreadId = "beta"
    service.launchingThreadId = ""
    compare(controller.activateAdjacentThread(-1), "thread:alpha")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 2)
    compare(openedThreadId, "alpha")
  }

  function test_previousActivationStopsAtFirstThread() {
    viewRows = [
      { kind: "project", path: "/work/a" },
      { kind: "thread", path: "/work/a", thread: { id: "alpha" } },
      { kind: "project", path: "/work/b" },
      { kind: "thread", path: "/work/b", thread: { id: "beta" } }
    ]
    service.activeThreadId = "alpha"
    selectedIndex = 1

    compare(controller.activateAdjacentThread(-1), "")
    compare(selectedIndex, 1)
    compare(openedThreadCount, 0)
    compare(openedRemoteThreadCount, 0)
    compare(releaseCount, 0)
  }

}
