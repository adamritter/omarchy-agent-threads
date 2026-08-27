.pragma library

function text(value) {
  return String(value || "")
}

function operationMatches(threadId, remoteId, operationThreadId, operationRemoteId) {
  return threadId !== "" && threadId === text(operationThreadId)
    && remoteId === text(operationRemoteId)
}

function threadTitle(title, state) {
  var value = text(title) || "Untitled agent thread"
  if (state.renaming) return "Renaming…  " + value
  if (state.pinning) return "Updating pin…  " + value
  if (state.moving) return "Moving…  " + value
  if (state.archiving) return "Archiving…  " + value
  return (state.pinned ? "󰐃  " : "") + value
}

function sectionSubtitle(row, needsRemoteAction) {
  var entry = row || ({})
  var host = entry.host || ({})
  if (entry.kind !== "remote") return text(entry.path)
  if (needsRemoteAction) return "CLAUDE"
  if (text(host.error) !== "") return text(host.error)
  if (text(host.providerType) !== "") return text(host.providerType).toUpperCase()
  return host.type === "ssh" ? "SSH" : "APP SERVER"
}

function presentation(input) {
  var state = input && typeof input === "object" ? input : ({})
  var row = state.row || ({})
  var kind = text(row.kind || "thread")
  var remoteRow = kind === "remote"
  var projectRow = kind === "project"
  var moreRow = kind === "more"
  var sectionRow = remoteRow || projectRow
  var threadRow = !sectionRow && !moreRow
  var thread = threadRow ? row.thread || null : null
  var threadId = text(thread && thread.id)
  var remoteId = text(row.remoteId)
  var host = row.host || ({})
  var loginableRemoteClaude = remoteRow
    && text(host.providerType) === "claude"
    && host.available !== false
    && host.authenticated === false
  var loggingInRemoteClaude = loginableRemoteClaude
    && text(state.remoteClaudeLoginHostId) === remoteId
    && state.remoteClaudeLoginRunning === true
  var activeThread = threadRow && threadId !== ""
    && threadId === text(state.activeThreadId)
    && remoteId === text(state.activeThreadScope)
  var activeProject = projectRow && remoteId === ""
    && text(state.activeProjectPath) !== ""
    && text(state.activeProjectPath) === text(row.path)
  var status = text(state.threadStatus || "done")
  var operationRemoteId = text(state.operationRemoteId)
  var archiving = threadRow && operationMatches(
    threadId, remoteId, state.archivingThreadId, operationRemoteId)
  var pinning = threadRow && operationMatches(
    threadId, remoteId, state.pinningThreadId, operationRemoteId)
  var renaming = threadRow && operationMatches(
    threadId, remoteId, state.renamingThreadId, operationRemoteId)
  var moving = threadRow && remoteId === ""
    && threadId === text(state.movingThreadId)
  var pinned = threadRow && thread && thread.isPinned === true
  var collapsed = state.collapsed === true
  var result = {
    remoteRow: remoteRow,
    projectRow: projectRow,
    moreRow: moreRow,
    sectionRow: sectionRow,
    threadRow: threadRow,
    threadData: thread,
    groupedThread: threadRow && row.grouped === true,
    loginableRemoteClaude: loginableRemoteClaude,
    loggingInRemoteClaude: loggingInRemoteClaude,
    remoteClaudeLoginRunning: state.remoteClaudeLoginRunning === true,
    needsRemoteClaudeAction: loginableRemoteClaude,
    activeThread: activeThread,
    activeProject: activeProject,
    busy: threadRow && status === "busy",
    blocked: threadRow && status === "blocked",
    unread: threadRow && state.unread === true,
    pinned: pinned,
    pinnedSection: sectionRow && state.pinnedSection === true,
    archiving: archiving,
    pinning: pinning,
    renaming: renaming,
    moving: moving,
    collapsed: collapsed,
    sectionIndicator: remoteRow ? (collapsed ? "▸" : "▾")
      : (collapsed ? "\uf07b" : "\uf07c"),
    sectionSubtitle: sectionSubtitle(row, loginableRemoteClaude),
    launchingProject: sectionRow
      && text(state.launchingProjectPath) === text(row.path)
  }
  result.threadTitle = threadTitle(state.threadTitle, result)
  return result
}
