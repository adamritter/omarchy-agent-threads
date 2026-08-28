.pragma library
// Purpose: Provides deterministic Remote Setup decisions shared by QML adapters.

function setupState(remoteId, host, activeProvider, currentType) {
  var id = String(remoteId || "")
  if (id !== "" && !host) return { accepted: false }
  var hostProvider = String(host && host.providerType || "").toLowerCase()
  var provider = host ? (hostProvider || "codex")
    : String(activeProvider || "").toLowerCase()
  if (["codex", "claude", "opencode"].indexOf(provider) < 0)
    return { accepted: false }
  return {
    accepted: true,
    id: id,
    provider: provider,
    type: host ? String(host.type || "ssh")
      : (provider !== "codex" ? "ssh" : String(currentType || "ssh"))
  }
}

function expandedRemotes(collapsedRemotes, remoteId) {
  var result = Object.assign({}, collapsedRemotes || ({}))
  var id = String(remoteId || "")
  if (id !== "") result[id] = false
  return result
}

function preferencesAfterRemoval(remoteId, collapsedRemotes,
                                 collapsedProjects, pinnedSections) {
  var id = String(remoteId || "")
  var remotes = Object.assign({}, collapsedRemotes || ({}))
  var projects = Object.assign({}, collapsedProjects || ({}))
  var pins = Object.assign({}, pinnedSections || ({}))
  if (id === "") return {
    collapsedRemotes: remotes,
    collapsedProjects: projects,
    pinnedSections: pins
  }

  delete remotes[id]
  var projectPrefix = id + ":"
  Object.keys(projects).forEach(function(key) {
    if (key.indexOf(projectPrefix) === 0) delete projects[key]
  })

  delete pins["remote:" + id]
  var pinPrefix = "project:" + id + ":"
  Object.keys(pins).forEach(function(key) {
    if (key.indexOf(pinPrefix) === 0) delete pins[key]
  })
  return {
    collapsedRemotes: remotes,
    collapsedProjects: projects,
    pinnedSections: pins
  }
}
