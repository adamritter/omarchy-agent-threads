.pragma library
.import "ThreadListBaseLogic.js" as Base
.import "ThreadListRowsLogic.js" as Rows

function text(value) {
  return Base.text(value)
}

function cleanText(value) {
  return Base.cleanText(value)
}

function directoryName(path) {
  return Base.directoryName(path)
}

function providerHost(hosts, providerId) {
  return Base.providerHost(hosts, providerId)
}

function projectRoot(project) {
  return Base.projectRoot(project)
}

function projectForId(projects, projectId) {
  return Base.projectForId(projects, projectId)
}

function projectForRoot(projects, path) {
  return Base.projectForRoot(projects, path)
}

function pathForThread(projects, thread, fallbackHome, preferThreadCwd) {
  return Base.pathForThread(projects, thread, fallbackHome, preferThreadCwd)
}

function isProjectPath(path, homePath, workPath, scratchRoot) {
  return Base.isProjectPath(path, homePath, workPath, scratchRoot)
}

function rowKey(row) {
  return Base.rowKey(row)
}

function rowIndexForKey(rows, key) {
  return Base.rowIndexForKey(rows, key)
}

function groupPreviewKey(kind, path, remoteId) {
  return Base.groupPreviewKey(kind, path, remoteId)
}

function projectCollapseKey(path, remoteId) {
  return Base.projectCollapseKey(path, remoteId)
}

function sectionPinKey(kind, path, remoteId) {
  return Base.sectionPinKey(kind, path, remoteId)
}

function threadSearchTitle(thread) {
  return Base.threadSearchTitle(thread)
}

function threadVisible(thread, path, searchText) {
  return Base.threadVisible(thread, path, searchText)
}

function projectMoveTargets(projects, threads, currentThread, options) {
  return Base.projectMoveTargets(projects, threads, currentThread, options)
}

function buildRows(input) {
  return Rows.buildRows(input)
}
