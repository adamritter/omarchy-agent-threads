.pragma library

function selectedRow(rows, selectedIndex) {
  return selectedIndex >= 0 && selectedIndex < rows.length ? rows[selectedIndex] : null
}

function newThreadTarget(activeProvider, homePath, row, providerHost) {
  var path = String(row && (row.path || (row.host ? row.host.home : "")) || homePath || "")
  if (row && row.remoteId)
    return { remoteId: String(row.remoteId), path: path, error: "" }
  if (activeProvider !== "codex") {
    if (!providerHost) return { remoteId: "", path: path, error: "provider-not-ready" }
    return { remoteId: String(providerHost.id || ""), path: path, error: "" }
  }
  return { remoteId: "", path: path, error: "" }
}

function projectPickerTarget(activeProvider, homePath, row, selectedHost, providerHost) {
  var host = selectedHost || null
  var hostId = String(row && row.remoteId || "")
  var providerType = String(activeProvider || "codex")
  var path = String(row && (row.path || (row.host ? row.host.home : "")) || "")

  if (hostId === "" && activeProvider !== "codex") {
    host = providerHost || null
    if (!host) {
      return {
        hostId: "",
        providerType: providerType,
        path: path || String(homePath || ""),
        error: "provider-not-ready"
      }
    }
    hostId = String(host.id || "")
  }
  if (host) providerType = String(host.providerType || providerType || "codex")
  if (path === "") path = String(host && host.home || homePath || "")
  return { hostId: hostId, providerType: providerType, path: path, error: "" }
}
