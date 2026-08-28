.pragma library

function activeTarget(toplevel) {
  var source = toplevel || ({})
  var appId = String(source.appId || "")
  var title = String(source.title || "")
  if (appId === "org.omarchy.agent-chat"
      || (appId === "org.quickshell" && title.indexOf("Agent Chat") === 0))
    return "agent-chat"
  return "other"
}

function route(action, context) {
  var wanted = String(action || "").toLowerCase()
  var state = context || ({})
  var agentChatActive = activeTarget(state.activeToplevel) === "agent-chat"

  if (wanted === "fast") {
    if (state.sidebarFocused === true && state.activeProvider === "codex")
      return "sidebar-fast"
    if (agentChatActive) return "agent-chat-fast"
    return "fullscreen"
  }

  if (wanted === "effort") {
    if (state.sidebarFocused === true && state.renameOpen === true)
      return "emoji"
    if (state.sidebarFocused === true) return "sidebar-effort"
    if (agentChatActive) return "agent-chat-effort"
    return "emoji"
  }

  return "invalid"
}
