.pragma library

var snapshotVersion = 1

function encode(snapshot) {
  try {
    return JSON.stringify(Object.assign({ version: snapshotVersion }, snapshot || ({})))
  } catch (error) {
    return ""
  }
}

function decode(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || Number(parsed.version || 0) !== snapshotVersion) return null
    return parsed
  } catch (error) {
    return null
  }
}

function hydratedHost(snapshot, defaults) {
  if (!snapshot || typeof snapshot !== "object" || Array.isArray(snapshot))
    return Object.assign({}, defaults || ({}))
  return Object.assign({}, defaults || ({}), snapshot, { loading: false })
}

function hydratedHosts(snapshots) {
  if (!Array.isArray(snapshots)) return []
  var result = []
  for (var i = 0; i < snapshots.length; i++) {
    var host = hydratedHost(snapshots[i])
    if (String(host.id || "") !== "") result.push(host)
  }
  return result
}
