// Purpose: Implements the Sidebar Row Presentation user-interface component.
import QtQuick
import "../logic/ThreadRowLogic.js" as ThreadRowLogic

QtObject {
  required property var controller
  readonly property var panel: controller.panel
  readonly property var service: controller.service

  function rowPresentation(row, index, hovered) {
    var entry = row || ({})
    var thread = entry.kind === "thread" ? entry.thread || null : null
    var remoteId = String(entry.remoteId || "")
    var activeId = String(service.activeThreadId || "")
    var activeThread = controller.navigation.threadForId(activeId)
    var status = thread
      ? (remoteId !== "" ? service.providers.remoteThreadStatus(thread)
        : service.threadActions.threadStatus(thread.id))
      : "done"
    var collapsed = entry.kind === "remote"
      ? panel.listActions.remoteCollapsed(entry.remoteId)
      : (entry.kind === "project"
        ? panel.listActions.projectCollapsed(entry.path, entry.remoteId) : false)
    return ThreadRowLogic.presentation({
      row: entry,
      activeThreadId: activeId,
      activeThreadScope: controller.navigation.threadScopeForId(activeId),
      activeProjectPath: activeThread ? panel.providerActions.projectPath(activeThread) : "",
      threadStatus: status,
      unread: !!thread && (remoteId !== ""
        ? thread.unread === true : service.threadActions.threadUnread(thread.id)),
      pinnedSection: (entry.kind === "remote" || entry.kind === "project")
        && panel.listActions.sectionPinned(entry.kind, entry.path, entry.remoteId),
      operationRemoteId: service.providers.remoteActionHostId,
      archivingThreadId: service.archivingThreadId,
      pinningThreadId: service.pinningThreadId,
      renamingThreadId: service.renamingThreadId,
      movingThreadId: service.movingThreadId,
      launchingProjectPath: service.launchingProjectPath,
      remoteClaudeLoginHostId: service.providers.remoteClaudeLoginHostId,
      remoteClaudeLoginRunning: service.providers.remoteClaudeLoginRunning,
      collapsed: collapsed,
      threadTitle: thread ? panel.providerActions.threadTitle(thread) : ""
    })
  }
  
}
