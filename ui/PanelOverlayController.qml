import QtQuick
import "../logic/ActionLogic.js" as ActionLogic
import "../logic/RemoteSetupLogic.js" as RemoteSetupLogic

QtObject {
  required property var panel

  function setSearchText(value) {
    var next = String(value || "")
    if (panel.session.searchText === next) return
    panel.session.searchText = next
    panel.selectedIndex = 0
    panel.listActions.rebuildRows("")
    if (panel.viewRows.length > 0) panel.threadList.positionViewAtIndex(0, ListView.Beginning)
  }
  
  function startSearch() {
    panel.session.searchOpen = true
    panel.session.keyboardFocusRequested = true
    panel.session.helpOpen = false
    panel.session.internalFocusTransfer = true
    panel.searchField.forceActiveFocus()
    panel.searchField.selectAll()
    Qt.callLater(function() { panel.session.internalFocusTransfer = false })
  }
  
  function leaveSearch() {
    panel.session.internalFocusTransfer = true
    panel.searchField.focus = false
    if (panel.session.searchText === "") panel.session.searchOpen = false
    panel.keyCatcher.forceActiveFocus()
    Qt.callLater(function() { panel.session.internalFocusTransfer = false })
  }
  
  function cancelSearch() {
    setSearchText("")
    panel.session.searchOpen = false
    if (panel.searchField.activeFocus) leaveSearch()
  }
  
  function startRename(remoteId, thread) {
    var targetRemoteId = remoteId === undefined ? "" : String(remoteId || "")
    var targetThread = thread || null
    if (!targetThread && panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length) {
      var row = panel.viewRows[panel.selectedIndex]
      if (row.kind !== "thread") return
      targetRemoteId = String(row.remoteId || "")
      targetThread = row.thread
    }
    if (!targetThread || !targetThread.id || panel.service.renamingThreadId !== "") return
    panel.providerMenu.close()
    panel.session.helpOpen = false
    panel.session.renameTargetThread = targetThread
    panel.session.renameTargetRemoteId = targetRemoteId
    panel.session.renameOpen = true
    panel.session.keyboardFocusRequested = true
    panel.session.internalFocusTransfer = true
    panel.renameField.text = panel.providerActions.threadTitle(targetThread)
    panel.renameField.forceActiveFocus()
    panel.renameField.selectAll()
    Qt.callLater(function() { panel.session.internalFocusTransfer = false })
  }
  
  function cancelRename() {
    panel.session.renameOpen = false
    panel.session.renameTargetThread = null
    panel.session.renameTargetRemoteId = ""
    panel.session.internalFocusTransfer = true
    panel.renameField.focus = false
    panel.keyCatcher.forceActiveFocus()
    Qt.callLater(function() { panel.session.internalFocusTransfer = false })
  }
  
  function submitRename() {
    var name = panel.providerActions.cleanText(panel.renameField.text).slice(0, 200)
    if (!panel.session.renameTargetThread || name === "") return
    var remoteId = panel.session.renameTargetRemoteId
    var thread = panel.session.renameTargetThread
    cancelRename()
    if (remoteId !== "") panel.service.providers.renameRemoteThread(remoteId, thread, name)
    else panel.service.threadActions.renameThread(thread, name)
  }
  
  function openRemoteSetup(remoteId) {
    var id = String(remoteId || "")
    var host = id !== "" ? panel.service.providers.remoteHostById(id) : null
    var state = RemoteSetupLogic.setupState(
      id, host, panel.activeProvider, panel.session.remoteSetupType)
    if (!state.accepted) return
    panel.providerMenu.close()
    if (panel.session.renameOpen) cancelRename()
    panel.session.helpOpen = false
    panel.session.searchOpen = false
    panel.session.editingRemoteId = state.id
    panel.session.remoteSetupProvider = state.provider
    panel.session.remoteSetupOpen = true
    panel.session.remoteSetupType = state.type
    panel.session.keyboardFocusRequested = true
    panel.service.remoteAddError = ""
    if (host) panel.remoteSetup.loadHost(host)
    else {
      panel.remoteSetup.resetFields()
      panel.service.providers.refreshSshHosts()
    }
    Qt.callLater(panel.remoteSetup.focusName)
  }
  
  function closeRemoteSetup() {
    panel.session.remoteSetupOpen = false
    panel.service.remoteAddError = ""
    panel.session.editingRemoteId = ""
    panel.session.internalFocusTransfer = true
    panel.remoteSetup.blurFields()
    panel.keyCatcher.forceActiveFocus()
    Qt.callLater(function() { panel.session.internalFocusTransfer = false })
  }
  
  function persistRemoteSetup(closeAfterSave) {
    var id = panel.session.editingRemoteId !== ""
      ? panel.service.providers.updateRemote(
          panel.session.editingRemoteId,
          panel.remoteSetup.nameText,
          panel.session.remoteSetupType,
          panel.remoteSetup.addressText,
          panel.remoteSetup.homeText,
          panel.remoteSetup.tokenText,
          panel.session.remoteSetupProvider)
      : panel.service.providers.addRemote(
          panel.remoteSetup.nameText,
          panel.session.remoteSetupType,
          panel.remoteSetup.addressText,
          panel.remoteSetup.homeText,
          panel.remoteSetup.tokenText,
          panel.session.remoteSetupProvider)
    if (id === "") return
    panel.service.settings.setCollapsedRemotes(
      RemoteSetupLogic.expandedRemotes(panel.service.collapsedRemotes, id))
    panel.session.editingRemoteId = id
    if (closeAfterSave !== false) closeRemoteSetup()
    panel.listActions.rebuildRows("remote:" + id)
    return id
  }
  
  function saveRemoteSetup() {
    persistRemoteSetup(true)
  }
  
  function testRemoteSetup() {
    if (panel.session.editingRemoteId === "") return
    var id = persistRemoteSetup(false)
    if (id) panel.service.providers.testRemote(id)
  }
  
  function disableRemote(remoteId) {
    var id = String(remoteId || "")
    if (id === "" || !panel.service.providers.removeRemote(id)) return
  
    var preferences = RemoteSetupLogic.preferencesAfterRemoval(
      id, panel.service.collapsedRemotes, panel.service.collapsedProjects,
      panel.service.pinnedSections)
    panel.service.settings.setCollapsedRemotes(preferences.collapsedRemotes)
    panel.service.settings.setCollapsedProjects(preferences.collapsedProjects)
    panel.service.settings.setPinnedSections(preferences.pinnedSections)
  
    if (panel.session.editingRemoteId === id) closeRemoteSetup()
    panel.listActions.rebuildRows()
  }
  
  function deleteRemoteSetup() {
    disableRemote(panel.session.editingRemoteId)
  }
  
  function enableSshHost(alias) {
    var host = String(alias || "")
    if (host === "" || panel.service.providers.sshHostEnabled(host, panel.session.remoteSetupProvider)) return
    var id = panel.service.providers.addRemote(host, "ssh", host, "", "", panel.session.remoteSetupProvider)
    if (id === "") return
    panel.service.settings.setCollapsedRemotes(
      RemoteSetupLogic.expandedRemotes(panel.service.collapsedRemotes, id))
    panel.listActions.rebuildRows("remote:" + id)
  }

  function toggleSshHost(alias) {
    var host = String(alias || "")
    if (host === "") return
    var id = panel.service.providers.remoteIdForSshHost(
      host, panel.session.remoteSetupProvider)
    if (id !== "") disableRemote(id)
    else enableSshHost(host)
  }
  
}
