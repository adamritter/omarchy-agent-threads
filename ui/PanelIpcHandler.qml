import QtQuick
import Quickshell
import Quickshell.Io

Item {
  required property var panel
  visible: false

  IpcHandler {
    enabled: panel.bar !== null
    target: panel.ipcTarget

  function open() { panel.focusActions.requestOpen() }
  function close() { panel.focusActions.requestClose() }
  function show() { panel.focusActions.requestOpen() }
  function hide() { panel.focusActions.requestClose() }
  function toggle() { panel.focusActions.requestToggle() }
  function focus() { panel.focusActions.focusSidebar() }
  function focusSidebar() { panel.focusActions.summonSidebarFocus() }
  function focusFrom(x: string, y: string) {
    panel.focusActions.focusSidebarFrom(x, y)
  }
  function blur() { panel.focusActions.releaseSidebarFocus(true) }
  function help() { panel.session.helpOpen = !panel.session.helpOpen }
  function addRemote() { panel.overlayActions.openRemoteSetup() }

  function manageRemote(id: string): string {
    panel.focusActions.requestOpen()
    panel.overlayActions.openRemoteSetup(id)
    return panel.session.editingRemoteId
  }

  function testRemote(id: string): string {
    return panel.service.providers.testRemote(id)
      ? "started" : panel.service.providers.remoteAddError
  }

  function provider(name: string): string {
    panel.providerActions.selectProvider(name)
    return panel.activeProvider
  }

  function frontend(name: string): string {
    var wanted = String(name || "").toLowerCase()
    if (wanted === "toggle")
      return panel.service.settings.toggleThreadFrontend("ipc")
    if (wanted === "terminal" || wanted === "agent-chat")
      panel.service.settings.setThreadFrontend(wanted, "ipc")
    return panel.service.settings.threadFrontend
  }

  function fast(mode: string): string {
    var wanted = String(mode || "").toLowerCase()
    if (wanted === "toggle") panel.service.settings.toggleFastMode()
    else if (wanted === "on" || wanted === "fast")
      panel.service.settings.setFastMode(true)
    else if (wanted === "off" || wanted === "default")
      panel.service.settings.setFastMode(false)
    return panel.service.settings.fastMode ? "on" : "off"
  }

  function notifications(mode: string): string {
    var wanted = String(mode || "").toLowerCase()
    if (wanted === "toggle") panel.service.settings.toggleNotifications()
    else if (wanted === "on") panel.service.settings.setNotificationsEnabled(true)
    else if (wanted === "off") panel.service.settings.setNotificationsEnabled(false)
    return panel.service.settings.notificationsEnabled ? "on" : "off"
  }

  function effort(mode: string): string {
    if (String(mode || "").toLowerCase() === "cycle")
      return panel.providerActions.cycleEffort()
    return panel.service.providers.selectedEffortForProvider(
      panel.activeProvider) || "default"
  }

  function scope(mode: string): string {
    var wanted = String(mode || "").toLowerCase()
    if (wanted === "toggle")
      wanted = panel.service.settings.scope === "global" ? "workspace" : "global"
    if (wanted !== "workspace" && wanted !== "global")
      return panel.service.settings.scope
    if (panel.session.activeWorkspaceKey === "") return panel.service.settings.scope
    panel.service.settings.setSidebarScope(
      wanted, panel.session.activeWorkspaceKey, panel.opened)
    panel.focusActions.applySidebarOpenState()
    return panel.service.settings.scope
  }

  function followThread(id: string): string {
    var threadId = String(id || "").trim()
    if (threadId === "") return ""
    var index = panel.sidebarActions.actions.rowIndexForThread(threadId)
    return index >= 0 ? panel.sidebarActions.actions.selectThreadIndex(index) : ""
  }

  function nextThread(): string {
    return panel.sidebarActions.actions.activateAdjacentThread(1)
  }

  function previousThread(): string {
    return panel.sidebarActions.actions.activateAdjacentThread(-1)
  }

  function openReady(): string {
    return panel.providerActions.openLatestReadyThread()
  }
  function cursorPoint(): string {
    return panel.sidebarActions.navigation.activeThreadCursorPoint()
  }

  function refresh(): string {
    panel.service.providers.refreshThreads()
    panel.service.providers.refreshRemotes()
    return "ok"
  }

  function reloadQml(): string {
    if (typeof panel.service.providers.flushProviderSnapshot === "function")
      panel.service.providers.flushProviderSnapshot()
    Qt.callLater(function() { Quickshell.reload(false) })
    return "ok"
  }

  function search(text: string): string {
    panel.overlayActions.setSearchText(text)
    return String(panel.visibleThreadCount)
  }

  function status(): string {
    return JSON.stringify({
      instanceToken: panel.session.instanceToken,
      activeProvider: panel.activeProvider,
      threadFrontend: panel.service.settings.threadFrontend,
      threadFrontendChangedBy: panel.service.settings.threadFrontendChangedBy,
      threadFrontendChangedAt: panel.service.settings.threadFrontendChangedAt,
      notificationsEnabled: panel.service.settings.notificationsEnabled,
      providerLoading: panel.providerActions.providerLoading(),
      providerSnapshotRestored: panel.service.providers.snapshotRestored,
      ready: panel.service.providers.ready,
      loading: panel.service.providers.loading,
      threadCount: panel.service.threads.length,
      appServerProjectCount: panel.service.projects.length,
      error: panel.service.errorText,
      launchingThreadId: panel.service.launchingThreadId,
      launchingProjectPath: panel.service.launchingProjectPath,
      archivingThreadId: panel.service.archivingThreadId,
      pinningThreadId: panel.service.pinningThreadId,
      movingThreadId: panel.service.movingThreadId,
      activeThreadId: panel.service.activeThreadId,
      readyThreadCount: panel.readyThreadCount,
      selectedRowKey: panel.listActions.rowKey(
        panel.viewRows[panel.selectedIndex]),
      searchText: panel.session.searchText,
      searchOpen: panel.session.searchOpen,
      visibleThreadCount: panel.visibleThreadCount,
      visibleProjectCount: panel.projectCount,
      helpOpen: panel.session.helpOpen,
      renameOpen: panel.session.renameOpen,
      sidebarFocused: panel.sidebarFocused,
      sidebarOpen: panel.service.settings.sidebarOpen,
      sidebarOpenOnWorkspace: panel.service.settings.sidebarOpenOnWorkspace(
        panel.session.activeWorkspaceKey),
      activeWorkspaceId: panel.session.activeWorkspaceId,
      activeWorkspaceKey: panel.session.activeWorkspaceKey,
      sidebarScope: panel.service.settings.scope,
      sidebarPresented: panel.sidebarPresented,
      fullscreenSuppressed: panel.fullscreenSuppressed,
      fullscreenInternalState: panel.session.fullscreenInternalState,
      fullscreenClientState: panel.session.fullscreenClientState,
      activeWorkspaceHasFullscreen: panel.session.activeWorkspaceHasFullscreen,
      activeWorkspaceGeometryFullscreen: panel.session.activeWorkspaceGeometryFullscreen,
      remoteCount: (panel.service.providers.remoteHosts || []).length,
      pinnedThreadCount: panel.sidebarActions.navigation.pinnedThreadCount(),
      availableSshHostCount: (panel.service.providers.sshHosts || []).length,
      remoteSetupOpen: panel.session.remoteSetupOpen,
      editingRemoteId: panel.session.editingRemoteId,
      remoteTestHostId: panel.service.providers.remoteTestHostId,
      remoteTestRunning: panel.service.providers.remoteTestRunning,
      remoteTestSucceeded: panel.service.providers.remoteTestSucceeded,
      remoteTestMessage: panel.service.providers.remoteTestMessage,
      codexLimit: panel.providerActions.rateLimitText(),
      providerLimit: panel.providerActions.activeRateLimitText(),
      modelCount: panel.service.providers.modelsForProvider(
        panel.activeProvider).length,
      selectedModel: panel.service.providers.selectedModelForProvider(
        panel.activeProvider) || "default",
      selectedEffort: panel.service.providers.selectedEffortForProvider(
        panel.activeProvider) || "default",
      selectedAgent: panel.service.providers.selectedAgentForProvider(
        panel.activeProvider) || "default",
      effectiveModel: panel.service.providers.effectiveModelForProvider(
        panel.activeProvider),
      effectiveEffort: panel.service.providers.effectiveEffortForProvider(
        panel.activeProvider),
      effectiveAgent: panel.service.providers.effectiveAgentForProvider(
        panel.activeProvider),
      providerVersion: panel.activeProviderHost
        ? String(panel.activeProviderHost.version || "") : "",
      providerAuthenticated: panel.activeProviderHost
        ? panel.activeProviderHost.authenticated !== false : true
    })
  }
  }
}
