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

function codexState(snapshot) {
  var codex = snapshot && snapshot.codex
    && typeof snapshot.codex === "object" && !Array.isArray(snapshot.codex)
    ? snapshot.codex : ({})
  return {
    threads: Array.isArray(codex.threads) ? codex.threads : [],
    projects: Array.isArray(codex.projects) ? codex.projects : [],
    rateLimits: codex.rateLimits && typeof codex.rateLimits === "object"
      && !Array.isArray(codex.rateLimits) ? codex.rateLimits : ({}),
    rateLimitResetCredits: codex.rateLimitResetCredits
      && typeof codex.rateLimitResetCredits === "object"
      && !Array.isArray(codex.rateLimitResetCredits)
      ? codex.rateLimitResetCredits : ({}),
    models: Array.isArray(codex.models) ? codex.models : [],
    codexConfig: codex.codexConfig && typeof codex.codexConfig === "object"
      && !Array.isArray(codex.codexConfig) ? codex.codexConfig : ({}),
    threadStatuses: codex.threadStatuses
      && typeof codex.threadStatuses === "object"
      && !Array.isArray(codex.threadStatuses) ? codex.threadStatuses : ({}),
    unreadThreads: codex.unreadThreads
      && typeof codex.unreadThreads === "object"
      && !Array.isArray(codex.unreadThreads) ? codex.unreadThreads : ({}),
    activeThreadId: String(codex.activeThreadId || "")
  }
}
