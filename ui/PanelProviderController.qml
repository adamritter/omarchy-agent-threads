// Purpose: Implements the Panel Provider Controller user-interface component.
import QtQuick
import Quickshell
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/PresentationLogic.js" as PresentationLogic
import "../logic/ThreadListLogic.js" as ThreadListLogic
import "../logic/ThreadNotificationLogic.js" as ThreadNotificationLogic

QtObject {
  required property var panel

  function cycleEffort() {
    var current = panel.service.settings.selectedEffortForProvider(panel.activeProvider)
    var next = ActionLogic.nextChoiceId(
      current, panel.sidebarView.modelEffortSelector.effortChoices())
    panel.service.settings.setEffortForProvider(panel.activeProvider, next)
    return next || "default"
  }
  
  function openLatestReadyThread() {
    if (panel.readyThreadTargets.length === 0) return ""
    var target = panel.readyThreadTargets[0]
    var thread = target.thread
    selectProvider(target.providerType)
    panel.focusActions.releaseSidebarFocus(true)
    if (target.hostId === "provider-codex")
      panel.service.threadActions.openThread(thread, projectPath(thread))
    else panel.service.providers.openRemoteThread(
      target.hostId, thread, panel.service.providers.remotePathForThread(target.host, thread))
    panel.service.threadActions.markThreadSeen(target.threadId)
    return "thread:" + target.scope + ":" + target.threadId
  }
  
  function visibleRowIndex(first) {
    if (panel.viewRows.length === 0) return -1
    var edgeY = panel.sidebarView.threadList.contentY
      + (first ? 1 : panel.sidebarView.threadList.height - 1)
    var direction = first ? 1 : -1
    for (var offset = 0; offset <= 48; offset += 2) {
      var index = panel.sidebarView.threadList.indexAt(
        panel.sidebarView.threadList.width / 2,
        edgeY + direction * offset)
      if (index >= 0) return index
    }
    return panel.selectedIndex
  }
  
  function cleanText(value) {
    return ThreadListLogic.cleanText(value)
  }
  
  function providerHost(providerId) {
    return ThreadListLogic.providerHost(panel.service.providers.remoteHosts, providerId)
  }
  
  function providerLabel(providerId) {
    return PresentationLogic.providerLabel(
      panel.providerChoices, providerId || panel.activeProvider)
  }
  
  function saveProviderViewState(providerId) {
    var id = String(providerId || panel.activeProvider)
    var next = Object.assign({}, panel.session.providerViewStates)
    next[id] = {
      searchText: panel.session.searchText,
      searchOpen: panel.session.searchOpen,
      selectedRowKey: panel.listActions.rowKey(panel.viewRows[panel.selectedIndex])
    }
    panel.session.providerViewStates = next
  }
  
  function restoreProviderViewState(providerId) {
    var state = panel.session.providerViewStates[String(providerId || panel.activeProvider)] || ({})
    panel.session.searchText = String(state.searchText || "")
    panel.session.searchOpen = state.searchOpen === true || panel.session.searchText !== ""
    panel.listActions.rebuildRows(String(state.selectedRowKey || ""))
    if (panel.viewRows.length > 0)
      Qt.callLater(function() {
        panel.sidebarView.threadList.positionViewAtIndex(
          panel.selectedIndex, ListView.Contain)
      })
  }
  
  function selectProvider(providerId) {
    var next = String(providerId || "").toLowerCase()
    panel.sidebarView.providerMenu.close()
    if (next === panel.activeProvider) return
    saveProviderViewState(panel.activeProvider)
    panel.session.helpOpen = false
    if (panel.session.remoteSetupOpen) panel.overlayActions.closeRemoteSetup()
    panel.service.settings.setSelectedProvider(next)
  }
  
  function providerErrorText() {
    if (panel.activeProvider === "codex")
      return panel.service.errorText !== "" ? panel.service.errorText : panel.service.launchError
    if (panel.service.launchError !== "") return panel.service.launchError
    var host = panel.activeProviderHost
    return host ? String(host.error || "") : ""
  }
  
  function providerLoading() {
    if (panel.activeProvider === "codex")
      return !panel.service.providers.ready || panel.service.providers.loading
    return !panel.activeProviderHost || panel.activeProviderHost.loading === true
  }
  
  function statusText() {
    return PresentationLogic.statusText({
      providerError: providerErrorText(),
      activeProvider: panel.activeProvider,
      providerReady: panel.service.providers.ready,
      providerLoading: providerLoading(),
      providerLabel: providerLabel(),
      totalThreadCount: panel.listActions.totalThreadCount(),
      visibleThreadCount: panel.visibleThreadCount,
      projectCount: panel.projectCount,
      filtered: panel.session.searchText !== "",
      movingThread: panel.service.movingThreadId !== "",
      renamingThread: panel.service.renamingThreadId !== "",
      archivingThread: panel.service.archivingThreadId !== "",
      pinningThread: panel.service.pinningThreadId !== "",
      navigationCount: panel.session.navigationCount,
      navigationFindDirection: panel.session.navigationFindDirection
    })
  }
  
  function rateLimitText(providerLimits) {
    var hasProviderLimits = providerLimits && typeof providerLimits === "object"
    var limits = hasProviderLimits ? providerLimits : (panel.service.rateLimits || ({}))
    return PresentationLogic.rateLimitText(limits,
      hasProviderLimits ? null : panel.service.rateLimitResetCredits, panel.session.nowMs)
  }
  
  function activeRateLimitText() {
    if (panel.activeProvider === "codex") return rateLimitText()
    if (panel.activeProvider !== "claude") return ""
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    var selectedHost = row && row.host
      && String(row.host.providerType || "") === "claude" ? row.host : null
    var selectedLimits = selectedHost && selectedHost.rateLimits
      && typeof selectedHost.rateLimits === "object" ? selectedHost.rateLimits : ({})
    var hasSelectedLimits = selectedLimits.primary || selectedLimits.secondary
    var localLimits = panel.activeProviderHost && panel.activeProviderHost.rateLimits
      && typeof panel.activeProviderHost.rateLimits === "object"
      ? panel.activeProviderHost.rateLimits : ({})
    return rateLimitText(hasSelectedLimits ? selectedLimits : localLimits)
  }
  
  function threadTitle(thread) {
    return PresentationLogic.threadTitle(thread, providerLabel())
  }
  
  function notificationStateSnapshot() {
    return ThreadNotificationLogic.notificationStateSnapshot(
      panel.service.threads, panel.service.threadStatuses,
      panel.service.unreadThreads, panel.service.providers.remoteHosts)
  }
  
  function sendThreadNotification(event) {
    if (!panel.service.settings.notificationsEnabled
        || Quickshell.env("AGENT_THREADS_PANEL_TEST") === "1") return
    var commands = ThreadNotificationLogic.notificationCommands(event)
    Quickshell.execDetached(commands.desktop)
    Quickshell.execDetached(commands.sound)
  }
  
  function syncThreadNotificationStates() {
    var nextStates = notificationStateSnapshot()
    if (!panel.session.notificationStateReady) {
      panel.session.notificationThreadStates = nextStates
      panel.session.notificationStateReady = true
      return
    }
    var events = ThreadNotificationLogic.notificationEvents(panel.session.notificationThreadStates, nextStates)
    panel.session.notificationThreadStates = nextStates
    for (var index = 0; index < events.length; index++)
      sendThreadNotification(events[index])
  }
  
  function projectPath(thread) {
    var path = String(panel.service.threadActions.projectPathForThread(thread) || "")
    return path !== "" ? path : panel.environment.homePath
  }
  
  function projectMoveTargets(thread) {
    return ThreadListLogic.projectMoveTargets(
      panel.service.projects, panel.service.threads, thread, {
        homePath: panel.environment.homePath,
        workPath: panel.environment.workPath,
        scratchRoot: panel.environment.codexScratchRoot
      })
  }
}
