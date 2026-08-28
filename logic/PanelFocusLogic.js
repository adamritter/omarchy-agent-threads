.pragma library
// Purpose: Provides deterministic Panel Focus decisions shared by QML adapters.

function number(value, fallback) {
  var parsed = Number(value)
  return isNaN(parsed) ? Number(fallback || 0) : parsed
}

function summonPoint(screen, margins, barPosition, barSize, cursorPoint,
                     fallbackX) {
  var targetScreen = screen || ({})
  var panelMargins = margins || ({})
  var point = cursorPoint || ({})
  var reservedBarHeight = String(barPosition || "") === "top"
    ? number(barSize, 0) : 0
  return {
    x: Math.round(number(targetScreen.x, 0)
      + number(point.x, fallbackX)),
    y: Math.round(number(targetScreen.y, 0)
      + reservedBarHeight + number(panelMargins.top, 0)
      + number(point.y, 1))
  }
}

function fullscreenState(raw, currentWorkspaceKey, pendingReloadWorkspaceKey) {
  var source
  try { source = typeof raw === "string" ? JSON.parse(raw) : raw }
  catch (error) { return { valid: false } }
  if (!source || typeof source !== "object") return { valid: false }

  var workspaceId = number(source.workspaceId, 0)
  var workspaceKey = String(source.workspaceKey
    || (workspaceId !== 0 ? workspaceId : ""))
  var currentKey = String(currentWorkspaceKey || "")
  var pendingKey = String(pendingReloadWorkspaceKey || "")
  var workspaceChanged = workspaceKey !== "" && workspaceKey !== currentKey
  return {
    valid: true,
    workspaceId: workspaceId,
    workspaceKey: workspaceKey,
    workspaceChanged: workspaceChanged,
    workspaceFullscreen: source.hasfullscreen === true,
    geometryFullscreen: source.geometryFullscreen === true,
    internalState: source.hasfullscreen === true ? 2 : 0,
    clientState: 0,
    cancelReloadFocus: workspaceChanged
      && (currentKey !== "" || pendingKey === "" || pendingKey !== workspaceKey)
  }
}
