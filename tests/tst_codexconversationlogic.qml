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

  function test_preservesStructuredFileDiffs() {
    var message = ConversationLogic.itemMessage({
      id: "f1",
      type: "fileChange",
      status: "completed",
      changes: [{
        path: "src/app.js",
        kind: { type: "update", move_path: null },
        diff: "@@ -1 +1 @@\n-old value\n+new value"
      }]
    })
    compare(message.kind, "file")
    verify(message.content.indexOf("UPDATE  src/app.js") === 0)
    verify(message.content.indexOf("@@ -1 +1 @@") >= 0)
    verify(message.content.indexOf("-old value") >= 0)
    verify(message.content.indexOf("+new value") >= 0)
  }

  function test_collectsInlineGitApplyPatches() {
    var command = ["/usr/bin/bash", "-lc",
      "git apply <<'PATCH'\n"
        + "diff --git a/one.txt b/one.txt\n--- a/one.txt\n+++ b/one.txt\n"
        + "@@ -1 +1 @@\n-old one\n+new one\nPATCH\n\n"
        + "git apply <<'NEXT'\n"
        + "diff --git a/two.txt b/two.txt\n--- a/two.txt\n+++ b/two.txt\n"
        + "@@ -1 +1 @@\n-old two\n+new two\nNEXT"]
    var message = ConversationLogic.itemMessage({
      id: "c1", type: "commandExecution", command: command,
      aggregatedOutput: "error: corrupt patch at <stdin>:14\n", status: "failed"
    })

    compare(message.kind, "file")
    compare(message.title, "Patch failed")
    verify(message.content.indexOf("diff --git a/one.txt b/one.txt") >= 0)
    verify(message.content.indexOf("diff --git a/two.txt b/two.txt") >= 0)
    verify(message.content.indexOf("git apply") < 0)
    compare(message.output, "error: corrupt patch at <stdin>:14\n")

    var wrapped = ConversationLogic.itemMessage({
      id: "c2", type: "commandExecution",
      command: "/usr/bin/bash -lc 'git apply <<'\\''PATCH'\\''\n"
        + "diff --git a/app.js b/app.js\n--- a/app.js\n+++ b/app.js\n"
        + "@@ -1 +1 @@\n-old\n+new\nPATCH'",
      aggregatedOutput: "", status: "completed"
    })
    compare(wrapped.kind, "file")
    compare(wrapped.title, "File changes")
    verify(wrapped.content.indexOf("diff --git a/app.js b/app.js") >= 0)

    var stdinPatch = ConversationLogic.itemMessage({
      id: "c3", type: "commandExecution", command: "/usr/bin/bash -lc 'git apply -'",
      aggregatedOutput: "diff --git a/new.txt b/new.txt\n--- /dev/null\n+++ b/new.txt\n"
        + "@@ -0,0 +1 @@\n+hello\n",
      status: "completed"
    })
    compare(stdinPatch.kind, "file")
    verify(stdinPatch.content.indexOf("diff --git a/new.txt b/new.txt") >= 0)
    compare(stdinPatch.output, "")

    var temporaryPatch = ConversationLogic.itemMessage({
      id: "c4", type: "commandExecution", status: "completed",
      command: "diff -u --label a/Panel.qml --label b/Panel.qml Panel.qml next > change.patch; git apply change.patch",
      aggregatedOutput: ""
    })
    compare(temporaryPatch.kind, "file")
    verify(temporaryPatch.content.indexOf("UPDATE  Panel.qml") >= 0)
    verify(temporaryPatch.content.indexOf("Diff unavailable") >= 0)

    var cachedPatch = ConversationLogic.itemMessage({
      id: "c5", type: "commandExecution", status: "completed",
      command: "git apply --cached staged.patch; git diff --cached --stat",
      aggregatedOutput: " AGENTS.md | 4 +\n Panel.qml | 2 +-\n"
    })
    compare(cachedPatch.kind, "file")
    verify(cachedPatch.content.indexOf("UPDATE  AGENTS.md") >= 0)
    verify(cachedPatch.content.indexOf("UPDATE  Panel.qml") >= 0)
  }

  function test_groupsSuccessfulFileChangesByTurn() {
    var first = {
      id: "p1", type: "commandExecution", status: "completed", aggregatedOutput: "",
      command: "git apply <<'PATCH'\ndiff --git a/one b/one\n--- a/one\n+++ b/one\n"
        + "@@ -1 +1 @@\n-old\n+new\nPATCH"
    }
    var second = {
      id: "f2", type: "fileChange", status: "completed",
      changes: [{ path: "two", kind: "update", diff: "@@ -1 +1 @@\n-before\n+after" }]
    }
    var failed = Object.assign({}, first, {
      id: "p3", status: "failed", aggregatedOutput: "corrupt patch"
    })
    var messages = ConversationLogic.upsertItem([], first, "turn-1")
    messages = ConversationLogic.upsertItem(messages, second, "turn-1")
    messages = ConversationLogic.upsertItem(messages, failed, "turn-1")

    compare(messages.length, 2)
    compare(messages[0].id, "turn-file-changes-turn-1")
    compare(messages[0].sourceIds.length, 2)
    verify(messages[0].content.indexOf("a/one") >= 0)
    verify(messages[0].content.indexOf("UPDATE  two") >= 0)
    compare(messages[1].title, "Patch failed")
  }

  function test_interruptedThreadIsNotBusy() {
    compare(ConversationLogic.threadActivity({ turns: [
      { id: "turn-1", status: "completed" },
      { id: "turn-2", status: "interrupted" }
    ] }).busy, false)
    var activity = ConversationLogic.threadActivity({ turns: [
      { id: "turn-3", status: "inProgress" }
    ] })
    compare(activity.busy, true)
    compare(activity.turnId, "turn-3")
  }

  function test_omitsEmptyReasoningAndFileChanges() {
    compare(ConversationLogic.itemMessage({
      id: "r1", type: "reasoning", summary: [], content: []
    }), null)
    compare(ConversationLogic.itemMessage({
      id: "f1", type: "fileChange", changes: []
    }), null)
  }

  function test_describesApprovalsWithoutTrustingMarkup() {
    var summary = ConversationLogic.approvalSummary(
      "item/commandExecution/requestApproval", { command: "rm example" })
    compare(summary.title, "Run command?")
    compare(summary.detail, "rm example")
    compare(summary.kind, "command")

    var large = new Array(31002).join("x")
    summary = ConversationLogic.approvalSummary(
      "item/commandExecution/requestApproval", { command: large })
    verify(summary.detail.length < large.length)
    verify(summary.detail.indexOf("[Output truncated]") >= 0)
  }
}
