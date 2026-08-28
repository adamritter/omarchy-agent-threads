import QtQuick
import QtTest
import "../logic/CodexConversationLogic.js" as ConversationLogic

TestCase {
  name: "CodexConversationLogic"

  function test_normalizesConversationItems() {
    var messages = ConversationLogic.normalizeThread({
      turns: [{ items: [
        { id: "u1", type: "userMessage", content: [{ type: "text", text: "Solve $x^2=4$." }] },
        { id: "a1", type: "agentMessage", text: "The answers are $x=\\pm2$." },
        { id: "c1", type: "commandExecution", command: "printf test", aggregatedOutput: "test", status: "completed" }
      ] }]
    })

    compare(messages.length, 3)
    compare(messages[0].role, "user")
    compare(messages[0].content, "Solve $x^2=4$.")
    compare(messages[1].role, "assistant")
    compare(messages[2].role, "tool")
    compare(messages[2].title, "printf test")
  }

  function test_streamingDeltaUpdatesStableItem() {
    var messages = ConversationLogic.appendDelta([], "a1", "First", "assistant", "Codex")
    messages = ConversationLogic.appendDelta(messages, "a1", " second", "assistant", "Codex")

    compare(messages.length, 1)
    compare(messages[0].content, "First second")
    compare(messages[0].status, "inProgress")

    messages = ConversationLogic.upsertItem(messages, {
      id: "a1", type: "agentMessage", text: "Final answer", status: "completed"
    })
    compare(messages.length, 1)
    compare(messages[0].content, "Final answer")
    compare(messages[0].status, "completed")
  }

  function test_reconcilesOptimisticUserMessage() {
    var messages = ConversationLogic.optimisticUserMessage([], "Hello")
    compare(messages.length, 1)
    verify(messages[0].id.indexOf("local-user-") === 0)

    messages = ConversationLogic.upsertItem(messages, {
      id: "server-user", type: "userMessage", content: [{ type: "text", text: "Hello" }]
    })
    compare(messages.length, 1)
    compare(messages[0].id, "server-user")
  }

  function test_boundsToolOutput() {
    var large = new Array(31002).join("x")
    var message = ConversationLogic.itemMessage({
      id: "c1", type: "commandExecution", command: "large", aggregatedOutput: large
    })
    verify(message.content.length < large.length)
    verify(message.content.indexOf("[Output truncated]") >= 0)
  }

  function test_rejectsOversizedPromptsBeforeRetention() {
    var limit = ConversationLogic.promptCharacterLimit()
    compare(limit, 200000)
    compare(ConversationLogic.boundedPromptInput("short"), "short")
    compare(ConversationLogic.boundedPromptInput(
      new Array(limit + 2).join("x")).length, limit)
    compare(ConversationLogic.promptValidationError(new Array(limit + 1).join("x")), "")
    verify(ConversationLogic.promptValidationError(
      new Array(limit + 2).join("x")).indexOf("200,000") >= 0)
  }

  function test_rejectsPathologicalProtocolStructures() {
    compare(ConversationLogic.protocolStructureError({
      method: "turn/completed",
      params: { turn: { items: [{ id: "a1", type: "agentMessage", text: "ok" }] } }
    }), "")
    verify(ConversationLogic.protocolStructureError(
      { values: new Array(5001) }).indexOf("array entries") >= 0)

    var textValues = []
    for (var textIndex = 0; textIndex < 5; textIndex++)
      textValues.push(new Array(2 * 1024 * 1024).join("x"))
    verify(ConversationLogic.protocolStructureError(
      { values: textValues }).indexOf("too much text") >= 0)

    var nested = ({})
    var cursor = nested
    for (var i = 0; i < 50; i++) {
      cursor.next = ({})
      cursor = cursor.next
    }
    verify(ConversationLogic.protocolStructureError(nested).indexOf("nesting") >= 0)
  }

  function test_boundsProtocolCollectionsBeforeNormalization() {
    var turns = []
    for (var turnIndex = 0; turnIndex < 205; turnIndex++)
      turns.push({ id: "turn" + turnIndex, items: [{
        id: "message" + turnIndex, type: "agentMessage", text: "message " + turnIndex
      }] })
    var messages = ConversationLogic.normalizeThread({ turns: turns })
    compare(messages.length, 200)
    compare(messages[0].id, "message5")
    compare(messages[199].id, "message204")

    var items = []
    for (var itemIndex = 0; itemIndex < 1100; itemIndex++) items.push({ id: itemIndex })
    var completed = ConversationLogic.completedTurnItems({ items: items })
    compare(completed.length, 1000)
    compare(completed[0].id, 100)

    var modelEntries = []
    for (var modelIndex = 0; modelIndex < 250; ++modelIndex)
      modelEntries.push({ id: "model-" + modelIndex })
    var models = ConversationLogic.boundedModelEntries(modelEntries)
    compare(models.length, 200)
  }

  function test_tracksAndExpiresFiniteRequestDeadlines() {
    var deadlines = ConversationLogic.trackRequestDeadline(
      ({}), 7, "thread start", 1000, 500)
    deadlines = ConversationLogic.trackRequestDeadline(
      deadlines, 8, "configuration", 1000, 1000)
    var first = ConversationLogic.takeExpiredRequestDeadlines(deadlines, 1600)
    compare(first.expired.length, 1)
    compare(first.expired[0].id, 7)
    compare(first.expired[0].label, "thread start")
    verify(first.remaining["8"] !== undefined)

    var cleared = ConversationLogic.clearRequestDeadline(first.remaining, 8)
    compare(Object.keys(cleared).length, 0)
    compare(ConversationLogic.requestTimeoutMs(), 15000)
  }

  function test_boundsRetainedConversationHistory() {
    var messages = []
    for (var i = 0; i < 450; i++)
      messages = ConversationLogic.upsertItem(messages, {
        id: "a" + i, type: "agentMessage", text: "message " + i
      })
    compare(messages.length, 400)
    compare(messages[0].id, "a50")
    compare(messages[399].id, "a449")

    var large = new Array(200002).join("x")
    messages = []
    for (var largeIndex = 0; largeIndex < 60; largeIndex++)
      messages = ConversationLogic.upsertItem(messages, {
        id: "large" + largeIndex, type: "agentMessage", text: large
      })
    verify(messages.length < 60)
    compare(messages[messages.length - 1].id, "large59")
  }

  function test_boundsAggregatedFileParts() {
    var messages = []
    for (var i = 0; i < 40; i++) {
      messages = ConversationLogic.upsertItem(messages, {
        id: "file" + i,
        type: "fileChange",
        status: "completed",
        changes: [{ path: "file" + i, kind: "update", diff: "+value" }]
      }, "turn-files")
    }
    compare(messages.length, 1)
    compare(messages[0].fileParts.length, 32)
    compare(messages[0].sourceIds[0], "file8")
    compare(messages[0].sourceIds[31], "file39")
  }

}
