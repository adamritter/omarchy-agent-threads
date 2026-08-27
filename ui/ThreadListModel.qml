import QtQuick
import "../logic/ThreadListLogic.js" as ThreadListLogic

Item {
  id: root

  required property var service
  required property var session
  required property string activeProvider
  required property int groupPreviewLimit
  required property string homePath
  required property string workPath
  required property string codexScratchRoot
  readonly property string searchText: session.searchText

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
      remoteHosts: service.providers.remoteHosts,
      expandedGroups: session.expandedGroups,
      collapsedProjects: service.settings.collapsedProjects,
      collapsedRemotes: service.settings.collapsedRemotes,
      pinnedSections: service.settings.pinnedSections,
      homePath: root.homePath,
      workPath: root.workPath,
      scratchRoot: root.codexScratchRoot
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
