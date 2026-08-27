.pragma library

var snapshotVersion = 1

function focusTarget(value) {
  return String(value || "") === "search" ? "search" : "list"
}

function plainObject(value) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? Object.assign({}, value) : ({})
}

function coordinate(value) {
  var number = Number(value)
  return isNaN(number) ? -1 : number
}

function encode(state, processId, instanceId, nowMs) {
  try {
    var source = state || ({})
    return JSON.stringify({
      version: snapshotVersion,
      processId: Number(processId || 0),
      instanceId: String(instanceId || ""),
      savedAt: Number(nowMs || Date.now()),
      selectedRowKey: String(source.selectedRowKey || ""),
      keyboardFocusRequested: source.keyboardFocusRequested === true,
      focusTarget: focusTarget(source.focusTarget),
      searchText: String(source.searchText || ""),
      searchOpen: source.searchOpen === true,
      expandedGroups: plainObject(source.expandedGroups),
      cursorReturnX: coordinate(source.cursorReturnX),
      cursorReturnY: coordinate(source.cursorReturnY)
    })
  } catch (error) {
    return ""
  }
}

function decode(raw, processId, instanceId, nowMs, maxAgeMs) {
  var parsed
  try { parsed = JSON.parse(String(raw || "")) }
  catch (error) { return null }
  if (!parsed || Number(parsed.version || 0) !== snapshotVersion) return null
  if (Number(parsed.processId || 0) !== Number(processId || 0)) return null
  if (String(parsed.instanceId || "") !== String(instanceId || "")) return null

  var now = Number(nowMs || Date.now())
  var savedAt = Number(parsed.savedAt || 0)
  var age = now - savedAt
  if (savedAt <= 0 || age < -1000 || age > Number(maxAgeMs || 0)) return null

  return {
    selectedRowKey: String(parsed.selectedRowKey || ""),
    keyboardFocusRequested: parsed.keyboardFocusRequested === true,
    focusTarget: focusTarget(parsed.focusTarget),
    searchText: String(parsed.searchText || ""),
    searchOpen: parsed.searchOpen === true,
    expandedGroups: plainObject(parsed.expandedGroups),
    cursorReturnX: coordinate(parsed.cursorReturnX),
    cursorReturnY: coordinate(parsed.cursorReturnY)
  }
}
