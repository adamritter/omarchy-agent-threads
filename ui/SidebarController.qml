import QtQuick

Item {
  id: root

  required property var panel
  required property var listView
  readonly property var service: panel.service
  property string followedActiveThreadId: ""
  property string activationIntentThreadId: ""

  SidebarActionController {
    id: actions
    controller: root
    panel: root.panel
    listView: root.listView
  }

  SidebarNavigationController {
    id: navigation
    controller: root
    panel: root.panel
    listView: root.listView
  }

  function rowIndexForThread(threadId, remoteId) {
    return actions.rowIndexForThread(threadId, remoteId)
  }

  function projectHeaderIndex(path, remoteId) {
    return actions.projectHeaderIndex(path, remoteId)
  }

  function remoteHeaderIndex(remoteId) {
    return actions.remoteHeaderIndex(remoteId)
  }

  function rowPresentation(row, index, hovered) {
    return actions.rowPresentation(row, index, hovered)
  }

  function loginRemoteForRow(row) {
    return actions.loginRemoteForRow(row)
  }

  function createThreadForRow(row) {
    return actions.createThreadForRow(row)
  }

  function toggleSectionPinForRow(row) {
    return actions.toggleSectionPinForRow(row)
  }

  function archiveRow(row) {
    return actions.archiveRow(row)
  }

  function renameRow(row) {
    return actions.renameRow(row)
  }

  function moveRowToProject(row, target) {
    return actions.moveRowToProject(row, target)
  }

  function testRemoteForRow(row) {
    return actions.testRemoteForRow(row)
  }

  function manageRemoteForRow(row) {
    return actions.manageRemoteForRow(row)
  }

  function disableRemoteForRow(row) {
    return actions.disableRemoteForRow(row)
  }

  function openSelected(source) {
    return actions.openSelected(source)
  }

  function activateRow(index, source) {
    return actions.activateRow(index, source)
  }

  function adjacentThreadIndex(startIndex, direction, wrap) {
    return actions.adjacentThreadIndex(startIndex, direction, wrap)
  }

  function selectThreadIndex(index) {
    return actions.selectThreadIndex(index)
  }

  function selectAdjacentThread(direction) {
    return actions.selectAdjacentThread(direction)
  }

  function activeThreadRowIndex() {
    return actions.activeThreadRowIndex()
  }

  function followTargetThreadId() {
    return actions.followTargetThreadId()
  }

  function activateAdjacentThread(direction) {
    return actions.activateAdjacentThread(direction)
  }

  function newSelectedThread() {
    return actions.newSelectedThread()
  }

  function openSelectedTerminal() {
    return actions.openSelectedTerminal()
  }

  function archiveSelected() {
    return actions.archiveSelected()
  }

  function renameSelected() {
    return actions.renameSelected()
  }

  function togglePin(remoteId, thread) {
    return actions.togglePin(remoteId, thread)
  }

  function togglePinSelected() {
    return navigation.togglePinSelected()
  }

  function pinnedThreadCount() {
    return navigation.pinnedThreadCount()
  }

  function threadForId(threadId) {
    return navigation.threadForId(threadId)
  }

  function threadScopeForId(threadId) {
    return navigation.threadScopeForId(threadId)
  }

  function handleHorizontalNavigation(direction) {
    return navigation.handleHorizontalNavigation(direction)
  }

  function followActiveThread(force) {
    return navigation.followActiveThread(force)
  }

  function activeThreadCursorPoint() {
    return navigation.activeThreadCursorPoint()
  }

  function visibleListCursorPoint() {
    return navigation.visibleListCursorPoint()
  }

}
