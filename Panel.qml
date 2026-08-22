import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "services" as Services
import "ui" as Ui

Panel {
  id: root
  moduleName: "adam.codex-threads"
  ipcTarget: "adam.codex-threads"
  manageIpc: false

  readonly property var service: Services.ThreadStore
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Util.alpha(foreground, 0.58)
  readonly property color faint: Util.alpha(foreground, 0.10)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string homePath: Quickshell.env("HOME") || "/tmp"
  readonly property string workPath: homePath + "/Work"
  readonly property string codexScratchRoot: homePath + "/Documents/Codex/"
  readonly property string workspaceStateHelperPath: Qt.resolvedUrl(
    "bin/omarchy-agent-workspace-state").toString().replace(/^file:\/\//, "")
  readonly property int sidebarContentWidth: Style.space(380)
  readonly property int sidebarReserveWidth: sidebarContentWidth + Style.gapsOut
  readonly property bool fullscreenSuppressed: activeWorkspaceHasFullscreen
  readonly property bool sidebarPresented: opened && !fullscreenSuppressed
  readonly property bool sidebarItemFocused: keyCatcher.activeFocus || searchField.activeFocus
    || remoteSetup.inputFocused
  readonly property bool sidebarFocused: keyboardFocusRequested && sidebarItemFocused
  readonly property string activeProvider: service.selectedProvider || "codex"
  readonly property var activeProviderHost: providerHost(activeProvider)
  readonly property var providerChoices: [
    { id: "codex", label: "CODEX" },
    { id: "claude", label: "CLAUDE" },
    { id: "opencode", label: "OPENCODE" }
  ]
  readonly property alias viewRows: threadListModel.viewRows
  readonly property var collapsedProjects: service.collapsedProjects
  readonly property var collapsedRemotes: service.collapsedRemotes
  readonly property var pinnedSections: service.pinnedSections
  property var expandedGroups: ({})
  readonly property int groupPreviewLimit: 10
  property var providerViewStates: ({})
  readonly property alias projectCount: threadListModel.projectCount
  readonly property alias visibleThreadCount: threadListModel.visibleThreadCount
  property alias selectedIndex: threadListModel.selectedIndex
  readonly property var sidebarActions: sidebarController
  property double nowMs: Date.now()
  property string searchText: ""
  property bool searchOpen: false
  property bool helpOpen: false
  property bool remoteSetupOpen: false
  property string remoteSetupType: "ssh"
  property string remoteSetupProvider: "codex"
  property string editingRemoteId: ""
  property int focusAttemptsRemaining: 0
  property bool focusPrimed: false
  property int cursorReturnX: -1
  property int cursorReturnY: -1
  property int fullscreenInternalState: 0
  property int fullscreenClientState: 0
  property bool activeWorkspaceHasFullscreen: false
  property bool activeWorkspaceGeometryFullscreen: false
  property bool fullscreenProbeQueued: false
  property bool internalFocusTransfer: false
  property bool applyingPersistedSidebarState: false

  onSidebarItemFocusedChanged: {
    if (!sidebarItemFocused && keyboardFocusRequested
        && !internalFocusTransfer
        && !focusAcquireTimer.running && !focusReleaseGuard.running)
      releaseSidebarFocus(false)
  }
  readonly property var helpItems: [
    { keys: "↑ ↓  /  j k", description: "Move selection" },
    { keys: "← →  /  h l", description: "Collapse or expand project" },
    { keys: "Enter / o", description: "Open thread or toggle project" },
    { keys: "p", description: "Pin or unpin selected item" },
    { keys: "P", description: "Select provider" },
    { keys: "y", description: "Archive selected thread" },
    { keys: "/", description: "Search threads and projects" },
    { keys: "n", description: "New thread in the selected directory" },
    { keys: "R", description: "Add remote host (SSH or App Server)" },
    { keys: "Tab / Shift+Tab", description: "Switch between panels" },
    { keys: "Esc", description: "Close help or release focus" },
    { keys: "?", description: "Open or close help" }
  ]
  // Mapping or reloading the sidebar must never request keyboard focus.
  property bool keyboardFocusRequested: false
  Ui.ThreadListModel {
    id: threadListModel
    controller: root
  }

  Ui.SidebarController {
    id: sidebarController
    panel: root
    listView: threadList
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function cleanText(value) {
    return String(value || "").replace(/\s+/g, " ").trim()
  }

  function providerHost(providerId) {
    var wanted = String(providerId || "").toLowerCase()
    var hosts = service.remoteHosts || []
    var fallback = null
    for (var i = 0; i < hosts.length; i++) {
      if (String(hosts[i].providerType || "").toLowerCase() !== wanted) continue
      if (String(hosts[i].id || "") === "provider-" + wanted) return hosts[i]
      if (!fallback) fallback = hosts[i]
    }
    return fallback
  }

  function providerLabel(providerId) {
    var wanted = String(providerId || activeProvider).toLowerCase()
    for (var i = 0; i < providerChoices.length; i++) {
      if (providerChoices[i].id === wanted) return providerChoices[i].label
    }
    return wanted.toUpperCase()
  }

  function saveProviderViewState(providerId) {
    var id = String(providerId || activeProvider)
    var next = Object.assign({}, providerViewStates)
    next[id] = {
      searchText: searchText,
      searchOpen: searchOpen,
      selectedRowKey: rowKey(viewRows[selectedIndex])
    }
    providerViewStates = next
  }

  function restoreProviderViewState(providerId) {
    var state = providerViewStates[String(providerId || activeProvider)] || ({})
    searchText = String(state.searchText || "")
    searchOpen = state.searchOpen === true || searchText !== ""
    rebuildRows(String(state.selectedRowKey || ""))
    if (viewRows.length > 0)
      Qt.callLater(function() { threadList.positionViewAtIndex(selectedIndex, ListView.Contain) })
  }

  function selectProvider(providerId) {
    var next = String(providerId || "").toLowerCase()
    providerMenu.close()
    if (next === activeProvider) return
    saveProviderViewState(activeProvider)
    helpOpen = false
    if (remoteSetupOpen) closeRemoteSetup()
    service.setSelectedProvider(next)
  }

  function providerErrorText() {
    if (activeProvider === "codex")
      return service.errorText !== "" ? service.errorText : service.launchError
    if (service.launchError !== "") return service.launchError
    var host = activeProviderHost
    return host ? String(host.error || "") : ""
  }

  function providerLoading() {
    if (activeProvider === "codex") return !service.ready || service.loading
    return !activeProviderHost || activeProviderHost.loading === true
  }

  function rateLimitWindowText(window) {
    if (!window || window.usedPercent === undefined || window.usedPercent === null)
      return ""
    var minutes = Number(window.windowDurationMins || 0)
    var label = "limit"
    if (minutes === 10080) label = "7d"
    else if (minutes > 0 && minutes % 1440 === 0) label = (minutes / 1440) + "d"
    else if (minutes > 0 && minutes % 60 === 0) label = (minutes / 60) + "h"
    else if (minutes > 0) label = minutes + "m"
    return label + " " + Math.round(Number(window.usedPercent)) + "%"
  }

  function rateLimitResetText(window) {
    if (!window || !window.resetsAt) return ""
    var resetAt = Number(window.resetsAt)
    var resetMs = resetAt > 1000000000000 ? resetAt : resetAt * 1000
    var totalMinutes = Math.max(0, Math.ceil((resetMs - nowMs) / 60000))
    var days = Math.floor(totalMinutes / 1440)
    var hours = Math.floor((totalMinutes % 1440) / 60)
    var minutes = totalMinutes % 60
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + "h " + minutes + "m"
    return totalMinutes + "m"
  }

  function rateLimitText(providerLimits) {
    var hasProviderLimits = providerLimits && typeof providerLimits === "object"
    var limits = hasProviderLimits ? providerLimits : (service.rateLimits || ({}))
    var windows = [
      rateLimitWindowText(limits.primary),
      rateLimitWindowText(limits.secondary)
    ].filter(function(value) { return value !== "" })
    if (windows.length === 0) return ""
    var weekly = Number(limits.primary && limits.primary.windowDurationMins) === 10080
      ? limits.primary : limits.secondary
    var reset = Number(weekly && weekly.windowDurationMins) === 10080
      ? rateLimitResetText(weekly) : ""
    var availableResets = hasProviderLimits ? 0 : Math.max(0, Math.floor(Number(
      service.rateLimitResetCredits && service.rateLimitResetCredits.availableCount || 0)))
    return windows.join(" · ")
      + (reset !== "" ? " · reset " + reset : "")
      + (availableResets > 0 ? " · reset×" + availableResets : "")
  }

  function activeRateLimitText() {
    if (activeProvider === "codex") return rateLimitText()
    if (activeProvider !== "claude") return ""
    var row = selectedIndex >= 0 && selectedIndex < viewRows.length
      ? viewRows[selectedIndex] : null
    var selectedHost = row && row.host
      && String(row.host.providerType || "") === "claude" ? row.host : null
    var selectedLimits = selectedHost && selectedHost.rateLimits
      && typeof selectedHost.rateLimits === "object" ? selectedHost.rateLimits : ({})
    var hasSelectedLimits = selectedLimits.primary || selectedLimits.secondary
    var localLimits = activeProviderHost && activeProviderHost.rateLimits
      && typeof activeProviderHost.rateLimits === "object"
      ? activeProviderHost.rateLimits : ({})
    return rateLimitText(hasSelectedLimits ? selectedLimits : localLimits)
  }

  function threadTitle(thread) {
    var name = cleanText(thread ? thread.name : "")
    if (name !== "") return name
    var preview = cleanText(thread ? thread.preview : "")
    return preview !== "" ? preview : "Untitled " + providerLabel() + " thread"
  }

  function directoryName(path) {
    var value = String(path || "")
    if (value === "") return "Unknown folder"
    var parts = value.replace(/\/$/, "").split("/")
    return parts.length > 0 && parts[parts.length - 1] !== "" ? parts[parts.length - 1] : value
  }

  function projectPath(thread) {
    var path = String(service.projectPathForThread(thread) || "")
    return path !== "" ? path : homePath
  }

  function projectMoveTargets(thread) {
    var currentPath = projectPath(thread)
    var seen = ({})
    var targets = []

    function appendTarget(path, name) {
      var value = String(path || "")
      if (value === "" || value === currentPath || seen[value] || !isProjectPath(value)) return
      seen[value] = true
      targets.push({ path: value, name: String(name || "") || directoryName(value) })
    }

    for (var projectIndex = 0; projectIndex < service.projects.length; projectIndex++) {
      var project = service.projects[projectIndex]
      appendTarget(service.projectRootPath(project), project ? project.name : "")
    }
    for (var threadIndex = 0; threadIndex < service.threads.length; threadIndex++) {
      var candidatePath = projectPath(service.threads[threadIndex])
      appendTarget(candidatePath, directoryName(candidatePath))
    }

    targets.sort(function(a, b) { return a.name.localeCompare(b.name) })
    return targets
  }

  function threadMatchesSearch(thread, path) {
    var query = cleanText(searchText).toLowerCase()
    if (query === "") return true
    var haystack = [
      threadTitle(thread),
      cleanText(thread ? thread.preview : ""),
      cleanText(thread ? thread.name : ""),
      String(path || ""),
      directoryName(path)
    ].join(" ").toLowerCase()
    var terms = query.split(" ")
    for (var i = 0; i < terms.length; i++) {
      if (terms[i] !== "" && haystack.indexOf(terms[i]) < 0) return false
    }
    return true
  }

  function threadVisible(thread, path) {
    return threadMatchesSearch(thread, path)
  }

  function setSearchText(value) {
    var next = String(value || "")
    if (searchText === next) return
    searchText = next
    selectedIndex = 0
    rebuildRows("")
    if (viewRows.length > 0) threadList.positionViewAtIndex(0, ListView.Beginning)
  }

  function startSearch() {
    searchOpen = true
    keyboardFocusRequested = true
    helpOpen = false
    internalFocusTransfer = true
    searchField.forceActiveFocus()
    searchField.selectAll()
    Qt.callLater(function() { root.internalFocusTransfer = false })
  }

  function leaveSearch() {
    internalFocusTransfer = true
    searchField.focus = false
    if (searchText === "") searchOpen = false
    keyCatcher.forceActiveFocus()
    Qt.callLater(function() { root.internalFocusTransfer = false })
  }

  function cancelSearch() {
    setSearchText("")
    searchOpen = false
    if (searchField.activeFocus) leaveSearch()
  }

  function openRemoteSetup(remoteId) {
    var id = String(remoteId || "")
    var host = id !== "" ? service.remoteHostById(id) : null
    var hostProvider = String(host && host.providerType || "").toLowerCase()
    var provider = host ? (hostProvider || "codex") : activeProvider
    if (provider !== "codex" && provider !== "claude" && provider !== "opencode") return
    if (id !== "" && !host) return
    providerMenu.close()
    helpOpen = false
    searchOpen = false
    editingRemoteId = id
    remoteSetupProvider = provider
    remoteSetupOpen = true
    remoteSetupType = host ? String(host.type || "ssh")
      : (provider !== "codex" ? "ssh" : remoteSetupType)
    keyboardFocusRequested = true
    service.remoteAddError = ""
    if (host) remoteSetup.loadHost(host)
    else {
      remoteSetup.resetFields()
      service.refreshSshHosts()
    }
    Qt.callLater(remoteSetup.focusName)
  }

  function closeRemoteSetup() {
    remoteSetupOpen = false
    service.remoteAddError = ""
    editingRemoteId = ""
    internalFocusTransfer = true
    remoteSetup.blurFields()
    keyCatcher.forceActiveFocus()
    Qt.callLater(function() { root.internalFocusTransfer = false })
  }

  function persistRemoteSetup(closeAfterSave) {
    var id = editingRemoteId !== ""
      ? service.updateRemote(
          editingRemoteId,
          remoteSetup.nameText,
          remoteSetupType,
          remoteSetup.addressText,
          remoteSetup.homeText,
          remoteSetup.tokenText,
          remoteSetupProvider)
      : service.addRemote(
          remoteSetup.nameText,
          remoteSetupType,
          remoteSetup.addressText,
          remoteSetup.homeText,
          remoteSetup.tokenText,
          remoteSetupProvider)
    if (id === "") return
    var expanded = Object.assign({}, service.collapsedRemotes)
    expanded[id] = false
    service.setCollapsedRemotes(expanded)
    editingRemoteId = id
    if (closeAfterSave !== false) closeRemoteSetup()
    rebuildRows("remote:" + id)
    return id
  }

  function saveRemoteSetup() {
    persistRemoteSetup(true)
  }

  function testRemoteSetup() {
    if (editingRemoteId === "") return
    var id = persistRemoteSetup(false)
    if (id) service.testRemote(id)
  }

  function disableRemote(remoteId) {
    var id = String(remoteId || "")
    if (id === "" || !service.removeRemote(id)) return

    var collapsed = Object.assign({}, service.collapsedRemotes)
    delete collapsed[id]
    service.setCollapsedRemotes(collapsed)

    var projects = Object.assign({}, service.collapsedProjects)
    var projectPrefix = id + ":"
    Object.keys(projects).forEach(function(key) {
      if (key.indexOf(projectPrefix) === 0) delete projects[key]
    })
    service.setCollapsedProjects(projects)

    var pins = Object.assign({}, service.pinnedSections)
    delete pins["remote:" + id]
    var pinPrefix = "project:" + id + ":"
    Object.keys(pins).forEach(function(key) {
      if (key.indexOf(pinPrefix) === 0) delete pins[key]
    })
    service.setPinnedSections(pins)

    if (editingRemoteId === id) closeRemoteSetup()
    rebuildRows()
  }

  function deleteRemoteSetup() {
    disableRemote(editingRemoteId)
  }

  function enableSshHost(alias) {
    var host = String(alias || "")
    if (host === "" || service.sshHostEnabled(host, remoteSetupProvider)) return
    var id = service.addRemote(host, "ssh", host, "", "", remoteSetupProvider)
    if (id === "") return
    var expanded = Object.assign({}, service.collapsedRemotes)
    expanded[id] = false
    service.setCollapsedRemotes(expanded)
    rebuildRows("remote:" + id)
  }

  function toggleSshHost(alias) {
    var host = String(alias || "")
    if (host === "") return
    var id = service.remoteIdForSshHost(host, remoteSetupProvider)
    if (id !== "") disableRemote(id)
    else enableSshHost(host)
  }

  function isProjectPath(path) {
    var value = String(path || "")
    return value !== "" && value !== homePath
      && value !== workPath
      && value.indexOf(codexScratchRoot) !== 0
  }

  function rowKey(row) {
    if (!row) return ""
    if (row.kind === "remote") return "remote:" + String(row.remoteId || "")
    if (row.kind === "project")
      return "project:" + String(row.remoteId || "local") + ":" + String(row.path || "")
    if (row.kind === "more") return "more:" + String(row.groupKey || "")
    return "thread:" + String(row.remoteId || "local") + ":"
      + String(row.thread ? row.thread.id || "" : "")
  }

  function rowIndexForKey(key) {
    var wanted = String(key || "")
    for (var i = 0; i < viewRows.length; i++) {
      if (rowKey(viewRows[i]) === wanted) return i
    }
    return -1
  }

  function groupPreviewKey(kind, path, remoteId) {
    return kind === "remote"
      ? "remote:" + String(remoteId || "")
      : "project:" + String(remoteId || "local") + ":" + String(path || "")
  }

  function groupShowsAll(kind, path, remoteId) {
    return expandedGroups[groupPreviewKey(kind, path, remoteId)] === true
  }

  function showAllGroup(kind, path, remoteId) {
    var next = Object.assign({}, expandedGroups)
    next[groupPreviewKey(kind, path, remoteId)] = true
    expandedGroups = next
    rebuildRows("")
    threadList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function resetGroupPreview(kind, path, remoteId) {
    var key = groupPreviewKey(kind, path, remoteId)
    if (expandedGroups[key] !== true) return
    var next = Object.assign({}, expandedGroups)
    delete next[key]
    expandedGroups = next
  }

  function rebuildRows(preferredKey) {
    threadListModel.rebuildRows(preferredKey)
  }
  function projectCollapseKey(path, remoteId) {
    return String(remoteId || "local") + ":" + String(path || "")
  }

  function sectionPinKey(kind, path, remoteId) {
    return kind === "remote"
      ? "remote:" + String(remoteId || "")
      : "project:" + projectCollapseKey(path, remoteId)
  }

  function sectionPinned(kind, path, remoteId) {
    return service.pinnedSections[sectionPinKey(kind, path, remoteId)] === true
  }

  function toggleSectionPin(kind, path, remoteId) {
    var key = sectionPinKey(kind, path, remoteId)
    var next = Object.assign({}, service.pinnedSections)
    if (next[key] === true) delete next[key]
    else next[key] = true
    service.setPinnedSections(next)
    rebuildRows(kind + ":" + (kind === "remote"
      ? String(remoteId || "")
      : String(remoteId || "local") + ":" + String(path || "")))
  }

  function setProjectCollapsed(path, collapsed, selectHeader, remoteId) {
    var project = String(path || "")
    if (collapsed) resetGroupPreview("project", project, remoteId)
    var next = Object.assign({}, service.collapsedProjects)
    next[projectCollapseKey(project, remoteId)] = !!collapsed
    service.setCollapsedProjects(next)
    rebuildRows(selectHeader
      ? "project:" + String(remoteId || "local") + ":" + project
      : undefined)
    threadList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function projectCollapsed(path, remoteId) {
    return service.collapsedProjects[projectCollapseKey(path, remoteId)] !== false
  }

  function toggleProject(path, remoteId) {
    setProjectCollapsed(path, !projectCollapsed(path, remoteId), true, remoteId)
  }

  function remoteCollapsed(remoteId) {
    return service.collapsedRemotes[String(remoteId || "")] !== false
  }

  function toggleRemote(remoteId) {
    var id = String(remoteId || "")
    var next = Object.assign({}, service.collapsedRemotes)
    next[id] = !remoteCollapsed(id)
    if (next[id]) resetGroupPreview("remote", "", id)
    service.setCollapsedRemotes(next)
    rebuildRows("remote:" + id)
    if (next[id] === false) service.refreshRemotes(id)
    threadList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function age(timestamp) {
    var seconds = Math.max(0, Math.floor(root.nowMs / 1000 - Number(timestamp || 0)))
    if (seconds < 60) return ""
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h"
    var days = Math.floor(hours / 24)
    if (days < 30) return days + "d"
    return Math.floor(days / 30) + "mo"
  }

  function totalThreadCount() {
    var count = activeProvider === "codex" ? service.threads.length : 0
    if (activeProvider !== "codex") {
      var selectedHost = providerHost(activeProvider)
      count = selectedHost ? (selectedHost.threads || []).length : 0
    }
    var hosts = service.remoteHosts || []
    for (var i = 0; i < hosts.length; i++) {
      var hostId = String(hosts[i].id || "")
      if (hostId === "provider-claude" || hostId === "provider-opencode") continue
      if (String(hosts[i].providerType || "codex").toLowerCase() === activeProvider)
        count += (hosts[i].threads || []).length
    }
    return count
  }

  function applySidebarOpenState() {
    if (!bar) return
    applyingPersistedSidebarState = true
    if (service.sidebarOpen) open()
    else close()
    Qt.callLater(function() { root.applyingPersistedSidebarState = false })
  }

  function focusSidebar() {
    if (!opened) open()
    if (fullscreenSuppressed) return
    keyboardFocusRequested = true
    focusPrimed = false
    // Briefly use Exclusive so Hyprland transfers the compositor keyboard
    // focus, then settle on OnDemand so normal window clicks keep working.
    focusPrimeTimer.restart()
    focusAttemptsRemaining = 10
    focusReleaseGuard.restart()
    focusAcquireTimer.restart()
  }

  function requestOpen() {
    open()
    queryFullscreenState()
  }

  function requestClose() {
    close()
  }

  function requestToggle() {
    if (opened) requestClose()
    else requestOpen()
  }

  function queryFullscreenState() {
    if (fullscreenProbe.running) {
      fullscreenProbeQueued = true
      return
    }
    fullscreenProbe.running = true
  }

  function applyFullscreenState(text) {
    var state
    try { state = JSON.parse(String(text || "{}")) } catch (e) { return }
    var workspaceFullscreen = state.hasfullscreen === true
    var internalState = workspaceFullscreen ? 2 : 0
    var clientState = 0
    var wasSuppressed = fullscreenSuppressed
    activeWorkspaceHasFullscreen = workspaceFullscreen
    activeWorkspaceGeometryFullscreen = state.geometryFullscreen === true
    fullscreenInternalState = internalState
    fullscreenClientState = clientState
    if (!wasSuppressed && fullscreenSuppressed) releaseSidebarFocus(true)
  }

  function focusSidebarFrom(x, y) {
    var returnX = Number(x)
    var returnY = Number(y)
    if (!isNaN(returnX) && !isNaN(returnY)) {
      cursorReturnX = Math.round(returnX)
      cursorReturnY = Math.round(returnY)
    }
    focusSidebar()
  }

  function releaseSidebarFocus(force) {
    if (!opened) return
    // Moving the pointer into the layer surface can emit a delayed toplevel
    // change. Ignore only that transition; explicit Esc always passes force.
    if (!force && focusReleaseGuard.running) return
    focusAcquireTimer.stop()
    focusPrimeTimer.stop()
    focusAttemptsRemaining = 0
    focusPrimed = false
    cursorReturnX = -1
    cursorReturnY = -1
    keyboardFocusRequested = false
    searchField.focus = false
    if (searchText === "") searchOpen = false
    keyCatcher.focus = false
    Qt.callLater(function() {
      if (!root.sidebarFocused) root.sidebarActions.followActiveThread(true)
    })
  }

  function escapeSidebarFocus() {
    var returnX = cursorReturnX
    var returnY = cursorReturnY
    releaseSidebarFocus(true)
    if (returnX < 0 || returnY < 0) return
    Quickshell.execDetached([
      "hyprctl", "dispatch",
      "hl.dsp.cursor.move({ x = " + returnX + ", y = " + returnY + " })"
    ])
  }

  onOpenedChanged: {
    if (!bar) return
    service.setSidebarOpen(opened)
    if (opened) {
      nowMs = Date.now()
      service.refreshThreads()
      service.refreshActiveThread()
      if (!applyingPersistedSidebarState) sidebarActions.followActiveThread(true)
      queryFullscreenState()
    } else {
      keyboardFocusRequested = false
      focusPrimed = false
      cursorReturnX = -1
      cursorReturnY = -1
      setSearchText("")
      searchOpen = false
      helpOpen = false
      remoteSetupOpen = false
    }
  }

  onBarChanged: applySidebarOpenState()

  Connections {
    target: service
    ignoreUnknownSignals: true
    function onThreadsChanged() {
      root.rebuildRows()
      root.sidebarActions.followActiveThread(false)
    }
    function onProjectsChanged() { root.rebuildRows() }
    function onRemoteHostsChanged() {
      root.rebuildRows()
      root.sidebarActions.followActiveThread(false)
    }
    function onCollapsedProjectsChanged() { root.rebuildRows() }
    function onCollapsedRemotesChanged() { root.rebuildRows() }
    function onPinnedSectionsChanged() { root.rebuildRows() }
    function onSelectedProviderChanged() {
      root.restoreProviderViewState(root.activeProvider)
    }
    function onActiveThreadIdChanged() { root.sidebarActions.followActiveThread(false) }
    function onSidebarOpenChanged() { root.applySidebarOpenState() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() {
      root.queryFullscreenState()
      // The cursor warp used by Super+A may deliver a delayed toplevel event
      // after focus has already reached the layer surface. Keep the requested
      // sidebar focus while the pointer is still inside it; moving or clicking
      // back into an application will release it normally.
      if (root.keyboardFocusRequested && sidebarHover.hovered) return
      root.releaseSidebarFocus(false)
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event && (event.name || event.event || event.type) || "")
      if (name === "workspace" || name === "workspacev2"
          || name === "focusedmon" || name === "focusedmonv2"
          || name === "fullscreen" || name === "fullscreenv2"
          || name === "activewindow" || name === "activewindowv2"
          || name === "openwindow" || name === "closewindow")
        fullscreenProbeDebounce.restart()
    }
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    repeat: false
    onTriggered: if (root.opened && root.keyboardFocusRequested)
      root.focusPrimed = true
  }

  Timer {
    id: focusAcquireTimer
    interval: 30
    repeat: true
    onTriggered: {
      keyCatcher.forceActiveFocus()
      root.focusAttemptsRemaining--
      if (keyCatcher.activeFocus) stop()
      else if (root.focusAttemptsRemaining <= 0) {
        stop()
        root.releaseSidebarFocus(true)
      }
    }
  }

  Timer {
    id: focusReleaseGuard
    interval: 350
    repeat: false
  }

  Timer {
    id: fullscreenProbeDebounce
    interval: 40
    repeat: false
    onTriggered: root.queryFullscreenState()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.queryFullscreenState()
  }

  Process {
    id: fullscreenProbe
    command: [root.workspaceStateHelperPath]
    running: false
    onRunningChanged: {
      if (!running && root.fullscreenProbeQueued) {
        root.fullscreenProbeQueued = false
        fullscreenProbeDebounce.restart()
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyFullscreenState(text)
    }
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.requestOpen() }
    function close(): void { root.requestClose() }
    function show(): void { root.requestOpen() }
    function hide(): void { root.requestClose() }
    function toggle(): void { root.requestToggle() }
    function focus(): void { root.focusSidebar() }
    function focusFrom(x: string, y: string): void { root.focusSidebarFrom(x, y) }
    function blur(): void { root.releaseSidebarFocus(true) }
    function help(): void { root.helpOpen = !root.helpOpen }
    function addRemote(): void { root.openRemoteSetup() }
    function manageRemote(id: string): string {
      root.requestOpen()
      root.openRemoteSetup(id)
      return root.editingRemoteId
    }
    function testRemote(id: string): string {
      return root.service.testRemote(id) ? "started" : root.service.remoteAddError
    }
    function provider(name: string): string {
      root.selectProvider(name)
      return root.activeProvider
    }
    function followThread(id: string): string {
      var threadId = String(id || "").trim()
      if (threadId === "") return ""
      root.service.activeThreadId = threadId
      root.sidebarActions.followActiveThread(true)
      return root.rowKey(root.viewRows[root.selectedIndex])
    }
    function cursorPoint(): string { return root.sidebarActions.activeThreadCursorPoint() }
    function refresh(): string {
      root.service.refreshThreads()
      root.service.refreshRemotes()
      return "ok"
    }
    function search(text: string): string {
      root.setSearchText(text)
      return String(root.visibleThreadCount)
    }
    function status(): string {
      return JSON.stringify({
        activeProvider: root.activeProvider,
        providerLoading: root.providerLoading(),
        ready: root.service.ready,
        loading: root.service.loading,
        threadCount: root.service.threads.length,
        appServerProjectCount: root.service.projects.length,
        error: root.service.errorText,
        launchingThreadId: root.service.launchingThreadId,
        launchingProjectPath: root.service.launchingProjectPath,
        archivingThreadId: root.service.archivingThreadId,
        pinningThreadId: root.service.pinningThreadId,
        movingThreadId: root.service.movingThreadId,
        activeThreadId: root.service.activeThreadId,
        selectedRowKey: root.rowKey(root.viewRows[root.selectedIndex]),
        searchText: root.searchText,
        searchOpen: root.searchOpen,
        visibleThreadCount: root.visibleThreadCount,
        visibleProjectCount: root.projectCount,
        helpOpen: root.helpOpen,
        sidebarFocused: root.sidebarFocused,
        sidebarOpen: root.service.sidebarOpen,
        sidebarPresented: root.sidebarPresented,
        fullscreenSuppressed: root.fullscreenSuppressed,
        fullscreenInternalState: root.fullscreenInternalState,
        fullscreenClientState: root.fullscreenClientState,
        activeWorkspaceHasFullscreen: root.activeWorkspaceHasFullscreen,
        activeWorkspaceGeometryFullscreen: root.activeWorkspaceGeometryFullscreen,
        remoteCount: (root.service.remoteHosts || []).length,
        pinnedThreadCount: root.sidebarActions.pinnedThreadCount(),
        availableSshHostCount: (root.service.sshHosts || []).length,
        remoteSetupOpen: root.remoteSetupOpen,
        editingRemoteId: root.editingRemoteId,
        remoteTestHostId: root.service.remoteTestHostId,
        remoteTestRunning: root.service.remoteTestRunning,
        remoteTestSucceeded: root.service.remoteTestSucceeded,
        remoteTestMessage: root.service.remoteTestMessage,
        codexLimit: root.rateLimitText(),
        providerLimit: root.activeRateLimitText(),
        modelCount: root.service.modelsForProvider(root.activeProvider).length,
        selectedModel: root.service.selectedModelForProvider(root.activeProvider) || "default",
        selectedEffort: root.service.selectedEffortForProvider(root.activeProvider) || "default",
        selectedAgent: root.service.selectedAgentForProvider(root.activeProvider) || "default",
        effectiveModel: root.service.effectiveModelForProvider(root.activeProvider),
        effectiveEffort: root.service.effectiveEffortForProvider(root.activeProvider),
        effectiveAgent: root.service.effectiveAgentForProvider(root.activeProvider),
        providerVersion: root.activeProviderHost
          ? String(root.activeProviderHost.version || "") : "",
        providerAuthenticated: root.activeProviderHost
          ? root.activeProviderHost.authenticated !== false : true
      })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰚩"
    active: root.sidebarFocused
    tooltipText: root.fullscreenSuppressed
      ? "Agent Threads is hidden while fullscreen"
      : root.opened
      ? (root.sidebarFocused
          ? "Codex thread sidebar · focused · click to close"
          : "Codex thread sidebar · click to close")
      : "Open Codex thread sidebar"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.requestToggle()
    }
  }

  // Keep compositor reservation separate from the visible overlay surface.
  PanelWindow {
    id: sidebarReservation

    screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    visible: root.sidebarPresented
    color: "transparent"
    implicitWidth: root.sidebarReserveWidth
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.sidebarReserveWidth

    WlrLayershell.namespace: "omarchy-codex-threads-reservation"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
    }

    mask: Region {
      width: 0
      height: 0
    }
  }

  // A persistent layer-shell sidebar rather than a popup. It has no full-screen
  // dismissal overlay, so clicking an application leaves it mapped.
  PanelWindow {
    id: panel

    screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    visible: root.sidebarPresented
    color: "transparent"
    implicitWidth: root.sidebarReserveWidth
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-codex-threads"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.sidebarPresented && root.keyboardFocusRequested
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
    }

    margins {
      // Overlay layers do not inherit the bar's exclusive edge, so include it.
      top: root.bar && root.bar.position === "top"
        ? root.bar.barSize + Style.gapsOut
        : Style.gapsOut
      bottom: root.bar && root.bar.position === "bottom"
        ? root.bar.barSize + Style.gapsOut
        : Style.gapsOut
    }

    BorderSurface {
      id: card
      anchors.fill: parent
      anchors.leftMargin: Style.gapsOut
      anchors.rightMargin: 0
      color: Color.popups.background
      borderSpec: root.sidebarFocused
        ? Border.surfaceSpec("popups", "border", Color.popups.border,
                             Math.max(1, Style.space(2)))
        : Border.none()
      padding: Style.spacing.popupPadding
      radius: Style.cornerRadius

      HoverHandler {
        id: sidebarHover
        onHoveredChanged: {
          // Super+A already starts an explicit focus cycle after moving the
          // pointer. Do not start a second competing cycle on pointer entry.
          if (hovered && root.opened && !root.keyboardFocusRequested)
            root.focusSidebar()
        }
      }

      PanelKeyCatcher {
        id: keyCatcher
        anchors.fill: parent
        blocked: searchField.activeFocus
          || remoteSetup.inputFocused
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

      onMoveRequested: function(dx, dy) {
        if (root.helpOpen) return
        if (providerMenu.opened) {
          if (dy !== 0) providerMenu.moveSelection(dy)
          return
        }
        if (root.viewRows.length === 0) return
        if (dx !== 0) {
          root.sidebarActions.handleHorizontalNavigation(dx)
          return
        }
        if (dy !== 0) {
          root.selectedIndex = Math.max(0, Math.min(root.viewRows.length - 1,
                                                     root.selectedIndex + dy))
          threadList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
        }
      }
      onActivateRequested: {
        if (providerMenu.opened) providerMenu.activateSelection()
        else if (root.helpOpen) root.helpOpen = false
        else root.sidebarActions.openSelected()
      }
      onCloseRequested: {
        if (providerMenu.opened) providerMenu.close()
        else if (root.remoteSetupOpen) root.closeRemoteSetup()
        else if (root.helpOpen) root.helpOpen = false
        else if (root.searchText !== "" || root.searchOpen) root.cancelSearch()
        else root.escapeSidebarFocus()
      }
      onDeleteRequested: {
        // PanelKeyCatcher reserves x for destructive actions. Archiving uses y
        // here by preference, so x intentionally does nothing.
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "/") {
          root.startSearch()
          return
        }
        if (text === "?") {
          root.helpOpen = !root.helpOpen
          return
        }
        if ((text === "r" || text === "R")
            && (root.activeProvider === "codex" || root.activeProvider === "claude"
                || root.activeProvider === "opencode")) {
          root.openRemoteSetup()
          return
        }
        if (root.helpOpen) return
        if (text === "P") {
          if (providerMenu.opened) providerMenu.close()
          else providerMenu.open()
          return
        }
        if (text === "o" || text === "O") {
          root.sidebarActions.openSelected()
          return
        }
        if (text === "y" || text === "Y") {
          root.sidebarActions.archiveSelected()
          return
        }
        if (text === "p") {
          root.sidebarActions.togglePinSelected()
          return
        }
        if (text === "n" || text === "N") root.sidebarActions.newSelectedThread()
      }

      Column {
        id: content
        anchors.fill: parent
        spacing: Style.space(8)

        Item {
          width: parent.width
          height: Style.space(36)

          Text {
            id: headerTitle
            anchors.left: parent.left
            anchors.right: newThreadButton.left
            anchors.rightMargin: Style.space(8)
            height: parent.height
            text: root.remoteSetupOpen ? "ADD REMOTE"
              : (root.helpOpen
                  ? root.providerLabel() + " · HELP"
                  : root.providerLabel() + "  ▾")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter

            MouseArea {
              anchors.fill: parent
              enabled: !root.remoteSetupOpen && !root.helpOpen
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (providerMenu.opened) providerMenu.close()
                else providerMenu.open()
              }
            }
          }

          Popup {
            id: providerMenu
            property int selectedIndex: 0
            x: 0
            y: parent.height - Style.space(2)
            width: Math.min(parent.width - Style.space(8), Style.space(176))
            height: providerChoicesColumn.implicitHeight + Style.space(8)
            padding: Style.space(4)
            modal: false
            dim: false
            focus: false
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            function resetSelection() {
              selectedIndex = 0
              for (var i = 0; i < root.providerChoices.length; i++) {
                if (root.providerChoices[i].id === root.activeProvider) {
                  selectedIndex = i
                  return
                }
              }
            }

            function moveSelection(direction) {
              var count = root.providerChoices.length
              if (count === 0) return
              selectedIndex = (selectedIndex + direction + count) % count
            }

            function activateSelection() {
              if (selectedIndex < 0 || selectedIndex >= root.providerChoices.length) return
              root.selectProvider(root.providerChoices[selectedIndex].id)
            }

            onOpened: resetSelection()

            background: Rectangle {
              color: Color.popups.background
              border.color: root.faint
              border.width: Math.max(1, Style.space(1))
              radius: Style.cornerRadius
            }

            contentItem: Column {
              id: providerChoicesColumn
              spacing: 0

              Repeater {
                model: root.providerChoices

                Rectangle {
                  required property var modelData
                  required property int index
                  width: providerMenu.availableWidth
                  height: Style.space(30)
                  radius: Math.max(2, Style.cornerRadius - Style.space(2))
                  color: providerChoiceMouse.containsMouse
                    || index === providerMenu.selectedIndex
                    ? root.faint : "transparent"

                  Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: modelData.id === root.activeProvider
                      ? Color.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.id === root.activeProvider
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.id === root.activeProvider
                    text: "●"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Math.max(7, Style.font.caption - 2)
                  }

                  MouseArea {
                    id: providerChoiceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                      if (containsMouse) providerMenu.selectedIndex = parent.index
                    }
                    onClicked: root.selectProvider(modelData.id)
                  }
                }
              }
            }
          }

          Item {
            id: newThreadButton
            visible: !root.remoteSetupOpen && !root.helpOpen
            anchors.right: remoteButton.left
            anchors.rightMargin: Style.space(4)
            anchors.top: parent.top
            anchors.topMargin: -Style.space(6)
            width: visible ? Style.space(18) : 0
            height: Style.space(24)

            Text {
              anchors.centerIn: parent
              text: "+"
              color: newThreadMouse.containsMouse ? Color.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: newThreadMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.sidebarActions.newSelectedThread()
            }
          }

          Item {
            id: remoteButton
            visible: root.activeProvider === "codex" || root.activeProvider === "claude"
              || root.activeProvider === "opencode"
            anchors.right: helpButton.left
            anchors.rightMargin: Style.space(4)
            anchors.top: parent.top
            anchors.topMargin: -Style.space(6)
            width: visible ? Style.space(20) : 0
            height: Style.space(24)

            Column {
              anchors.centerIn: parent
              spacing: -Style.space(5)

              Text {
                text: "→"
                color: root.remoteSetupOpen || remoteMouse.containsMouse
                  ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Math.max(9, Style.font.caption - 1)
              }

              Text {
                text: "←"
                color: root.remoteSetupOpen || remoteMouse.containsMouse
                  ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Math.max(9, Style.font.caption - 1)
              }
            }

            MouseArea {
              id: remoteMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.remoteSetupOpen) root.closeRemoteSetup()
                else root.openRemoteSetup()
              }
            }
          }

          Item {
            id: helpButton
            anchors.right: parent.right
            anchors.rightMargin: -Style.space(6)
            anchors.top: parent.top
            anchors.topMargin: -Style.space(6)
            width: Style.space(18)
            height: Style.space(24)

            Text {
              anchors.centerIn: parent
              text: "?"
              color: root.helpOpen || helpMouse.containsMouse ? Color.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: helpMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.helpOpen = !root.helpOpen
            }
          }
        }

        Text {
          width: parent.width
          height: Style.space(18)
          text: {
            var providerError = root.providerErrorText()
            if (providerError !== "") return providerError
            if (root.activeProvider === "codex" && !root.service.ready)
              return "Connecting to the local Codex App Server…"
            if (root.providerLoading() && root.totalThreadCount() === 0)
              return "Loading saved " + root.providerLabel() + " threads…"
            if (root.activeProvider === "codex" && root.service.movingThreadId !== "")
              return "Moving thread to project…"
            if (root.activeProvider === "codex" && root.service.archivingThreadId !== "")
              return "Archiving thread…"
            if (root.activeProvider === "codex" && root.service.pinningThreadId !== "")
              return "Updating pin…"
            var filtered = root.searchText !== ""
            return root.projectCount + " projects · "
              + (filtered
                  ? root.visibleThreadCount + " of " + root.totalThreadCount()
                  : root.totalThreadCount())
              + " threads · newest first"
          }
          color: root.providerErrorText() !== ""
            ? Color.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
        }

        TextField {
          id: searchField
          visible: root.searchOpen || root.searchText !== ""
          width: parent.width
          height: Style.space(34)
          text: root.searchText
          placeholderText: "Search threads and projects…"
          foreground: root.foreground
          accent: Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          verticalPadding: Style.space(5)
          rightPadding: Style.space(30)
          selectByMouse: true
          onTextEdited: root.setSearchText(text)
          onActiveFocusChanged: if (activeFocus) root.keyboardFocusRequested = true

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.cancelSearch()
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
              root.leaveSearch()
              if (root.viewRows.length > 0) {
                var direction = event.key === Qt.Key_Down ? 1 : -1
                root.selectedIndex = Math.max(0, Math.min(root.viewRows.length - 1,
                                                           root.selectedIndex + direction))
                threadList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.leaveSearch()
              event.accepted = true
            } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
              root.setSearchText("")
              event.accepted = true
            }
          }

          TapHandler {
            onTapped: {
              root.keyboardFocusRequested = true
              Qt.callLater(root.startSearch)
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.searchText !== ""
            text: "×"
            color: clearSearchMouse.containsMouse ? Color.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body

            MouseArea {
              id: clearSearchMouse
              anchors.fill: parent
              anchors.margins: -Style.space(7)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setSearchText("")
                root.startSearch()
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        Item {
          width: parent.width
          height: Math.max(0, parent.height - y)

          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: codexLimitFooter.top

            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(40)
              visible: !root.helpOpen && !root.providerLoading()
                && root.viewRows.length === 0
              text: root.totalThreadCount() === 0
                ? "No saved " + root.providerLabel() + " threads"
                : "No threads match this search"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Ui.CodexThreadList {
              id: threadList
              anchors.fill: parent
              panel: root
            }
          }

          Item {
            id: codexLimitFooter
            readonly property string label: root.activeRateLimitText()
            readonly property bool hasSelector: root.service
              .modelsForProvider(root.activeProvider).length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: visible ? Style.space(22) : 0
            visible: (label !== "" || hasSelector)
              && !root.helpOpen && !root.remoteSetupOpen

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              anchors.right: modelEffortSelector.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: parent.label
              visible: parent.label !== ""
              color: Util.alpha(root.foreground, 0.42)
              font.family: root.fontFamily
              font.pixelSize: Math.max(8, Style.font.caption - 1)
              font.letterSpacing: 0.25
              elide: Text.ElideRight
            }

            Ui.ModelEffortSelector {
              id: modelEffortSelector
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              panel: root
              visible: codexLimitFooter.hasSelector
            }
          }

          Ui.RemoteSetup {
            id: remoteSetup
            anchors.fill: parent
            panel: root
          }

          Ui.HelpOverlay {
            anchors.fill: parent
            panel: root
          }
        }
      }
      }
    }
  }

  Component.onCompleted: {
    rebuildRows()
    applySidebarOpenState()
  }
}
