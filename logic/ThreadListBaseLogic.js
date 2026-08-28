.pragma library
// Purpose: Provides deterministic Thread List Base decisions shared by QML adapters.

function text(value) {
  return String(value || "")
}

function cleanText(value) {
  return text(value).replace(/\s+/g, " ").trim()
}

function directoryName(path) {
  var value = text(path)
  if (value === "") return "Unknown folder"
  var parts = value.replace(/\/$/, "").split("/")
  return parts.length > 0 && parts[parts.length - 1] !== ""
    ? parts[parts.length - 1] : value
}

function providerHost(hosts, providerId) {
  var wanted = text(providerId).toLowerCase()
  var items = Array.isArray(hosts) ? hosts : []
  var fallback = null
  for (var i = 0; i < items.length; i++) {
    if (text(items[i] && items[i].providerType).toLowerCase() !== wanted) continue
    if (text(items[i] && items[i].id) === "provider-" + wanted) return items[i]
    if (!fallback) fallback = items[i]
  }
  return fallback
}

function projectRoot(project) {
  if (!project || !Array.isArray(project.roots) || project.roots.length === 0)
    return ""
  return text(project.roots[0] && project.roots[0].path)
}

function projectForId(projects, projectId) {
  var wanted = text(projectId)
  var items = Array.isArray(projects) ? projects : []
  for (var i = 0; i < items.length; i++) {
    if (text(items[i] && items[i].id) === wanted) return items[i]
  }
  return null
}

function projectForRoot(projects, path) {
  var wanted = text(path)
  var items = Array.isArray(projects) ? projects : []
  for (var i = 0; i < items.length; i++) {
    if (projectRoot(items[i]) === wanted) return items[i]
  }
  return null
}

function pathForThread(projects, thread, fallbackHome, preferThreadCwd) {
  var cwd = text(thread && thread.cwd)
  if (preferThreadCwd && cwd !== "") return cwd
  var root = projectRoot(projectForId(projects, thread && thread.projectId))
  if (root !== "") return root
  return cwd !== "" ? cwd : text(fallbackHome)
}

function isProjectPath(path, homePath, workPath, scratchRoot) {
  var value = text(path)
  var scratch = text(scratchRoot)
  return value !== "" && value !== text(homePath)
    && value !== text(workPath)
    && (scratch === "" || value.indexOf(scratch) !== 0)
}

function rowKey(row) {
  if (!row) return ""
  if (row.kind === "remote") return "remote:" + text(row.remoteId)
  if (row.kind === "project")
    return "project:" + text(row.remoteId || "local") + ":" + text(row.path)
  if (row.kind === "more") return "more:" + text(row.groupKey)
  return "thread:" + text(row.remoteId || "local") + ":"
    + text(row.thread && row.thread.id)
}

function rowIndexForKey(rows, key) {
  var wanted = text(key)
  var items = Array.isArray(rows) ? rows : []
  for (var i = 0; i < items.length; i++) {
    if (rowKey(items[i]) === wanted) return i
  }
  return -1
}

function groupPreviewKey(kind, path, remoteId) {
  return kind === "remote"
    ? "remote:" + text(remoteId)
    : "project:" + text(remoteId || "local") + ":" + text(path)
}

function projectCollapseKey(path, remoteId) {
  return text(remoteId || "local") + ":" + text(path)
}

function sectionPinKey(kind, path, remoteId) {
  return kind === "remote"
    ? "remote:" + text(remoteId)
    : "project:" + projectCollapseKey(path, remoteId)
}

function threadSearchTitle(thread) {
  var name = cleanText(thread && thread.name)
  if (name !== "") return name
  return cleanText(text(thread && thread.preview).split(/\r?\n/)[0])
}

function threadVisible(thread, path, searchText) {
  var query = cleanText(searchText).toLowerCase()
  if (query === "") return true
  var haystack = [threadSearchTitle(thread), directoryName(path)].join(" ").toLowerCase()
  var terms = query.split(" ")
  for (var i = 0; i < terms.length; i++) {
    if (terms[i] !== "" && haystack.indexOf(terms[i]) < 0) return false
  }
  return true
}

function projectMoveTargets(projects, threads, currentThread, options) {
  var settings = options && typeof options === "object" ? options : ({})
  var currentPath = pathForThread(
    projects, currentThread, settings.homePath, false)
  var seen = ({})
  var targets = []

  function append(path, name) {
    var value = text(path)
    if (value === "" || value === currentPath || seen[value]
        || !isProjectPath(value, settings.homePath,
          settings.workPath, settings.scratchRoot)) return
    seen[value] = true
    targets.push({ path: value, name: text(name) || directoryName(value) })
  }

  var projectItems = Array.isArray(projects) ? projects : []
  for (var projectIndex = 0; projectIndex < projectItems.length; projectIndex++)
    append(projectRoot(projectItems[projectIndex]), projectItems[projectIndex].name)

  var threadItems = Array.isArray(threads) ? threads : []
  for (var threadIndex = 0; threadIndex < threadItems.length; threadIndex++) {
    var path = pathForThread(projectItems, threadItems[threadIndex],
      settings.homePath, false)
    append(path, directoryName(path))
  }

  targets.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return targets
}

