.pragma library
.import "ConversationProtocolLogic.js" as Protocol
.import "ConversationItemLogic.js" as Items
.import "ConversationMessageLogic.js" as Messages
.import "ConversationApprovalLogic.js" as Approval

function text(value) {
  return Protocol.text(value)
}

function bounded(value, limit) {
  return Protocol.bounded(value, limit)
}

function promptCharacterLimit() {
  return Protocol.promptCharacterLimit()
}

function boundedPromptInput(value) {
  return Protocol.boundedPromptInput(value)
}

function promptValidationError(value) {
  return Protocol.promptValidationError(value)
}

function protocolStructureError(value) {
  return Protocol.protocolStructureError(value)
}

function requestTimeoutMs() {
  return Protocol.requestTimeoutMs()
}

function trackRequestDeadline(deadlines, requestId, label, now, timeoutMs) {
  return Protocol.trackRequestDeadline(deadlines, requestId, label, now, timeoutMs)
}

function clearRequestDeadline(deadlines, requestId) {
  return Protocol.clearRequestDeadline(deadlines, requestId)
}

function takeExpiredRequestDeadlines(deadlines, now) {
  return Protocol.takeExpiredRequestDeadlines(deadlines, now)
}

function inputText(inputs) {
  return Items.inputText(inputs)
}

function commandText(command) {
  return Items.commandText(command)
}

function embeddedGitPatches(command) {
  return Items.embeddedGitPatches(command)
}

function outputGitPatch(output) {
  return Items.outputGitPatch(output)
}

function opaqueGitPatchSummary(command, output) {
  return Items.opaqueGitPatchSummary(command, output)
}

function commandTitle(item) {
  return Items.commandTitle(item)
}

function fileChangeText(item) {
  return Items.fileChangeText(item)
}

function itemMessage(item) {
  return Items.itemMessage(item)
}

function aggregateFileParts(parts, turnId) {
  return Messages.aggregateFileParts(parts, turnId)
}

function retainedMessageSize(message) {
  return Messages.retainedMessageSize(message)
}

function retainRecentMessages(messages) {
  return Messages.retainRecentMessages(messages)
}

function copyMessages(messages) {
  return Messages.copyMessages(messages)
}

function upsertItem(messages, item, turnId) {
  return Messages.upsertItem(messages, item, turnId)
}

function appendDelta(messages, itemId, delta, role, title) {
  return Messages.appendDelta(messages, itemId, delta, role, title)
}

function normalizeThread(thread) {
  return Messages.normalizeThread(thread)
}

function completedTurnItems(turn) {
  return Messages.completedTurnItems(turn)
}

function boundedModelEntries(entries) {
  return Messages.boundedModelEntries(entries)
}

function threadActivity(thread) {
  return Messages.threadActivity(thread)
}

function optimisticUserMessage(messages, content) {
  return Messages.optimisticUserMessage(messages, content)
}

function approvalSummary(method, params) {
  return Approval.approvalSummary(method, params)
}
