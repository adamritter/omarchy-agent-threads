.pragma library
// Purpose: Provides deterministic Sidebar Preferences decisions shared by QML adapters.

function map(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? Object.assign({}, value) : ({})
}

function provider(value, fallback) {
  var next = String(value || "").toLowerCase()
  return next === "codex" || next === "claude" || next === "opencode"
    ? next : String(fallback || "codex")
}

function frontendPreference(current, requested, source, nowMs) {
  var previous = String(current || "") === "agent-chat" ? "agent-chat" : "terminal"
  var next = String(requested || "") === "agent-chat" ? "agent-chat" : "terminal"
  return {
    changed: previous !== next,
    frontend: next,
    changedBy: previous !== next ? String(source || "unknown") : "",
    changedAt: previous !== next ? Math.max(0, Number(nowMs || 0)) : 0
  }
}

function workspaceOpen(scope, globalOpen, openWorkspaces, workspaceId) {
  if (scope === "global") return globalOpen === true
  var id = String(workspaceId || "")
  return id !== "" && map(openWorkspaces)[id] === true
}

function setWorkspaceOpen(scope, globalOpen, openWorkspaces, workspaceId, value) {
  if (scope === "global") {
    return {
      globalOpen: value === true,
      openWorkspaces: map(openWorkspaces)
    }
  }
  var id = String(workspaceId || "")
  var next = map(openWorkspaces)
  if (id === "" || id === "0")
    return { globalOpen: globalOpen === true, openWorkspaces: next }
  if (value) next[id] = true
  else delete next[id]
  return { globalOpen: globalOpen === true, openWorkspaces: next }
}

function changeScope(currentScope, globalOpen, openWorkspaces,
                     requestedScope, workspaceId, visibleNow) {
  var nextScope = requestedScope === "global" ? "global" : "workspace"
  var id = String(workspaceId || "")
  var nextWorkspaces = map(openWorkspaces)
  if (nextScope === currentScope || id === "" || id === "0") {
    return {
      scope: currentScope,
      globalOpen: globalOpen === true,
      openWorkspaces: nextWorkspaces
    }
  }
  var currentlyOpen = visibleNow === undefined
    ? workspaceOpen(currentScope, globalOpen, nextWorkspaces, id)
    : visibleNow === true
  if (nextScope === "global") globalOpen = currentlyOpen
  else if (currentlyOpen) nextWorkspaces[id] = true
  else delete nextWorkspaces[id]
  return {
    scope: nextScope,
    globalOpen: globalOpen === true,
    openWorkspaces: nextWorkspaces
  }
}
