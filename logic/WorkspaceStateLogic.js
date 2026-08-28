.pragma library

function number(value, fallback) {
  var parsed = Number(value)
  return isNaN(parsed) ? Number(fallback || 0) : parsed
}

function list(value) {
  return Array.isArray(value) ? value : []
}

function workspaceById(workspaces, id) {
  var values = list(workspaces)
  for (var index = 0; index < values.length; index++) {
    if (number(values[index] && values[index].id, 0) === id)
      return values[index]
  }
  return null
}

function geometryFullscreen(client, workspaceId, monitor) {
  var source = client || ({})
  var workspace = source.workspace || ({})
  var at = list(source.at)
  var size = list(source.size)
  var scale = Math.max(number(monitor.scale, 1), 0.01)
  var logicalWidth = number(monitor.width, 0) / scale
  var logicalHeight = number(monitor.height, 0) / scale
  return number(workspace.id, 0) === workspaceId
    && number(source.monitor, -1) === number(monitor.id, -2)
    && source.floating === true
    && number(at[0], 999999) <= number(monitor.x, 0) + 3
    && number(at[1], 999999) <= number(monitor.y, 0) + 3
    && number(size[0], 0) >= logicalWidth - 4
    && number(size[1], 0) >= logicalHeight - 4
}

function derive(activeWorkspace, focusedMonitor, workspaces, clients) {
  var active = activeWorkspace || ({})
  var monitor = focusedMonitor || ({})
  var special = monitor.specialWorkspace || ({})
  var specialId = number(special.id, 0)
  var isSpecial = specialId !== 0
  var workspaceId = isSpecial ? specialId : number(active.id, 0)
  var workspaceKey = isSpecial
    ? String(special.name || workspaceId)
    : (workspaceId !== 0 ? String(workspaceId) : "")
  var effective = workspaceById(workspaces, workspaceId) || active
  var geometry = false
  var clientValues = list(clients)
  for (var index = 0; index < clientValues.length; index++) {
    if (geometryFullscreen(clientValues[index], workspaceId, monitor)) {
      geometry = true
      break
    }
  }
  var nativeFullscreen = effective.hasfullscreen === true
    || effective.hasFullscreen === true
  return {
    workspaceId: workspaceId,
    workspaceKey: workspaceKey,
    workspaceName: String(effective.name || workspaceKey),
    specialWorkspace: isSpecial,
    nativeFullscreen: nativeFullscreen,
    geometryFullscreen: geometry,
    hasfullscreen: nativeFullscreen || geometry
  }
}
