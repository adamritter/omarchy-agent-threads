.pragma library
// Purpose: Provides deterministic Presentation decisions shared by QML adapters.

function text(value) {
  return String(value || "")
}

function cleanText(value) {
  return text(value).replace(/\s+/g, " ").trim()
}

function providerLabel(choices, providerId) {
  var wanted = text(providerId).toLowerCase()
  var items = Array.isArray(choices) ? choices : []
  for (var i = 0; i < items.length; i++) {
    if (text(items[i] && items[i].id).toLowerCase() === wanted)
      return text(items[i].label)
  }
  return wanted.toUpperCase()
}

function threadTitle(thread, fallbackLabel) {
  var name = cleanText(thread && thread.name)
  if (name !== "") return name
  var preview = cleanText(thread && thread.preview)
  return preview !== "" ? preview
    : "Untitled " + (text(fallbackLabel) || "agent") + " thread"
}

function relativeAge(timestamp, nowMs) {
  var seconds = Math.max(0, Math.floor(Number(nowMs || 0) / 1000
    - Number(timestamp || 0)))
  if (seconds < 60) return ""
  var minutes = Math.floor(seconds / 60)
  if (minutes < 60) return minutes + "m"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  if (days < 30) return days + "d"
  return Math.floor(days / 30) + "mo"
}

function rateLimitWindowText(window) {
  if (!window || window.usedPercent === undefined || window.usedPercent === null)
    return ""
  var minutes = Number(window.windowDurationMins || 0)
  var label = "limit"
  if (minutes === 10080) label = "7d"
  else if (minutes > 0 && minutes % 1440 === 0) label = (minutes / 1440) + "d"
  else if (minutes > 0 && minutes % 60 === 0) label = (minutes / 60) + "h"
  else if (minutes > 0) label = minutes + "m"
  return label + " " + Math.round(Number(window.usedPercent)) + "%"
}

function rateLimitResetText(window, nowMs) {
  if (!window || !window.resetsAt) return ""
  var resetAt = Number(window.resetsAt)
  var resetMs = resetAt > 1000000000000 ? resetAt : resetAt * 1000
  var totalMinutes = Math.max(0, Math.ceil((resetMs - Number(nowMs || 0)) / 60000))
  var days = Math.floor(totalMinutes / 1440)
  var hours = Math.floor((totalMinutes % 1440) / 60)
  var minutes = totalMinutes % 60
  if (days > 0) return days + "d " + hours + "h"
  if (hours > 0) return hours + "h " + minutes + "m"
  return totalMinutes + "m"
}

function rateLimitText(limits, resetCredits, nowMs) {
  var source = limits && typeof limits === "object" ? limits : ({})
  var windows = [
    rateLimitWindowText(source.primary),
    rateLimitWindowText(source.secondary)
  ].filter(function(value) { return value !== "" })
  if (windows.length === 0) return ""
  var weekly = Number(source.primary && source.primary.windowDurationMins) === 10080
    ? source.primary : source.secondary
  var reset = Number(weekly && weekly.windowDurationMins) === 10080
    ? rateLimitResetText(weekly, nowMs) : ""
  var availableResets = Math.max(0, Math.floor(Number(
    resetCredits && resetCredits.availableCount || 0)))
  return windows.join(" · ")
    + (reset !== "" ? " · reset " + reset : "")
    + (availableResets > 0 ? " · reset×" + availableResets : "")
}

function totalThreadCount(activeProvider, localThreads, hosts) {
  var provider = text(activeProvider || "codex").toLowerCase()
  var count = provider === "codex" && Array.isArray(localThreads)
    ? localThreads.length : 0
  var entries = Array.isArray(hosts) ? hosts : []
  if (provider !== "codex") {
    for (var localIndex = 0; localIndex < entries.length; localIndex++) {
      var localHost = entries[localIndex] || ({})
      if (text(localHost.id) === "provider-" + provider) {
        count = Array.isArray(localHost.threads) ? localHost.threads.length : 0
        break
      }
    }
  }
  for (var i = 0; i < entries.length; i++) {
    var host = entries[i] || ({})
    var hostId = text(host.id)
    if (hostId.indexOf("provider-") === 0) continue
    if (text(host.providerType || "codex").toLowerCase() === provider)
      count += Array.isArray(host.threads) ? host.threads.length : 0
  }
  return count
}

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
  if (Number(state.navigationFindDirection || 0) !== 0)
    return text(state.navigationCount)
      + (Number(state.navigationFindDirection) > 0 ? "f…" : "F…")
  if (text(state.navigationCount) !== "")
    return "Count: " + text(state.navigationCount)
  var shown = state.filtered
    ? state.visibleThreadCount + " of " + state.totalThreadCount
    : state.totalThreadCount
  return state.projectCount + " projects · " + shown + " threads · newest first"
}
