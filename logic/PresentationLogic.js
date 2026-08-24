.pragma library

function headerTitle(state) {
  if (state.projectPickerOpen) return "NEW PROJECT"
  if (state.remoteSetupOpen) return "ADD REMOTE"
  if (state.renameOpen) return "RENAME THREAD"
  if (state.helpOpen) return String(state.providerLabel || "") + " · HELP"
  return String(state.providerLabel || "") + "  ▾"
}

function hierarchyIndent(depth) {
  var value = Number(depth)
  if (!isFinite(value) || value <= 0) return 0
  return Math.round(value) * 32
}

function threadIndent(grouped, depth) {
  if (!grouped) return 0
  var value = Number(depth)
  return hierarchyIndent(isFinite(value) && value > 0 ? value : 1)
}

function rowBackgroundRole(activeThread, hovered, selected, focused) {
  if (selected) return focused ? "focused-selection" : "unfocused-selection"
  if (activeThread) return "active"
  if (hovered) return "hover"
  return "none"
}

function statusText(state) {
  if (state.providerError !== "") return state.providerError
  if (state.activeProvider === "codex" && !state.providerReady)
    return "Connecting to the local Codex App Server…"
  if (state.providerLoading && state.totalThreadCount === 0)
    return "Loading saved " + state.providerLabel + " threads…"
  if (state.activeProvider === "codex" && state.movingThread)
    return "Moving thread to project…"
  if (state.renamingThread) return "Renaming thread…"
  if (state.activeProvider === "codex" && state.archivingThread)
    return "Archiving thread…"
  if (state.activeProvider === "codex" && state.pinningThread)
    return "Updating pin…"
  var shown = state.filtered
    ? state.visibleThreadCount + " of " + state.totalThreadCount
    : state.totalThreadCount
  return state.projectCount + " projects · " + shown + " threads · newest first"
}
