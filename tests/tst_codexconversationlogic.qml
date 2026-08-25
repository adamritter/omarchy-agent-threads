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

  function test_describesApprovalsWithoutTrustingMarkup() {
    var summary = ConversationLogic.approvalSummary(
      "item/commandExecution/requestApproval", { command: "rm example" })
    compare(summary.title, "Run command?")
    compare(summary.detail, "rm example")
    compare(summary.kind, "command")
  }
}
