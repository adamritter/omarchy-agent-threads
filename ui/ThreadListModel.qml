import QtQuick
import "../logic/ThreadListLogic.js" as ThreadListLogic

Item {
  id: root

  required property var controller
  readonly property var service: controller.service
  readonly property var session: controller.session || controller
  readonly property string activeProvider: controller.activeProvider
  readonly property string searchText: session.searchText
  readonly property int groupPreviewLimit: controller.groupPreviewLimit

  property var viewRows: []
  property int projectCount: 0
  property int visibleThreadCount: 0
  property int selectedIndex: 0

  function rebuildRows(preferredKey) {
    var previousKey = preferredKey !== undefined
      ? String(preferredKey || "")
      : ThreadListLogic.rowKey(viewRows[selectedIndex])
    var result = ThreadListLogic.buildRows({
      activeProvider: activeProvider,
      searchText: searchText,
      groupPreviewLimit: groupPreviewLimit,
      localThreads: service.threads,
      localProjects: service.projects,
      remoteHosts: service.remoteHosts,
      expandedGroups: session.expandedGroups,
      collapsedProjects: service.collapsedProjects,
      collapsedRemotes: service.collapsedRemotes,
      pinnedSections: service.pinnedSections,
      homePath: controller.homePath,
      workPath: controller.workPath,
      scratchRoot: controller.codexScratchRoot
    })
    projectCount = result.projectCount
    visibleThreadCount = result.visibleThreadCount
    viewRows = result.rows
    var restoredIndex = ThreadListLogic.rowIndexForKey(result.rows, previousKey)
    selectedIndex = restoredIndex >= 0
      ? restoredIndex
      : Math.max(0, Math.min(selectedIndex, result.rows.length - 1))
  }

}
