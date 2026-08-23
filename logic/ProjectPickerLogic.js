.pragma library

function rows(currentPath, parentPath, entries, browsable) {
  var result = [{ kind: "use", name: "Use this directory", path: String(currentPath || "") }]
  if (browsable && parentPath !== "" && parentPath !== currentPath)
    result.push({ kind: "parent", name: "Parent directory", path: parentPath })
  var folders = Array.isArray(entries) ? entries : []
  for (var i = 0; i < folders.length; i++)
    result.push({ kind: "folder", name: folders[i].name, path: folders[i].path })
  return result
}

function wrappedIndex(index, direction, length) {
  if (length <= 0) return 0
  return (Number(index || 0) + Number(direction || 0) + length) % length
}

function command(helperPath, sshMode, sshHost, action, targetPath, name) {
  return [
    helperPath,
    sshMode ? "ssh" : "local",
    sshMode ? String(sshHost || "") : "-",
    String(action || ""),
    String(targetPath || ""),
    String(name || "")
  ]
}

function parseResult(stdout, stderr, exitCode, currentPath) {
  var response = null
  try { response = JSON.parse(String(stdout || "{}").trim()) }
  catch (parseError) {}
  if (!response || response.error || exitCode !== 0) {
    return {
      ok: false,
      error: String(response && response.error || stderr
        || "Directory operation failed").trim()
    }
  }
  return {
    ok: true,
    path: String(response.path || currentPath || ""),
    parent: String(response.parent || ""),
    entries: Array.isArray(response.entries) ? response.entries : []
  }
}
