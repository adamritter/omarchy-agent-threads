import QtQuick
import QtTest
import "../logic/ProjectPickerLogic.js" as PickerLogic

TestCase {
  name: "ProjectPickerLogic"

  function test_buildsBrowsableRows() {
    var rows = PickerLogic.rows("/work/app", "/work", [
      { name: "src", path: "/work/app/src" }
    ], true)
    compare(rows.length, 3)
    compare(rows[0].kind, "use")
    compare(rows[1].kind, "parent")
    compare(rows[2].path, "/work/app/src")
  }

  function test_hidesParentForAppServer() {
    var rows = PickerLogic.rows("/work/app", "/work", [], false)
    compare(rows.length, 1)
    compare(rows[0].kind, "use")
  }

  function test_wrapsSelection() {
    compare(PickerLogic.wrappedIndex(0, -1, 3), 2)
    compare(PickerLogic.wrappedIndex(2, 1, 3), 0)
    compare(PickerLogic.wrappedIndex(5, 1, 0), 0)
  }

  function test_buildsLocalAndSshCommands() {
    compare(PickerLogic.command("/helper", false, "ignored", "list", "/work", ""),
      ["/helper", "local", "-", "list", "/work", ""])
    compare(PickerLogic.command("/helper", true, "dev", "mkdir", "/work", "app"),
      ["/helper", "ssh", "dev", "mkdir", "/work", "app"])
  }

  function test_parsesSuccessfulResult() {
    var result = PickerLogic.parseResult(
      '{"path":"/work","parent":"/","entries":[{"name":"app","path":"/work/app"}]}',
      "", 0, "/old")
    verify(result.ok)
    compare(result.path, "/work")
    compare(result.parent, "/")
    compare(result.entries.length, 1)
  }

  function test_reportsHelperAndMalformedErrors() {
    var helperError = PickerLogic.parseResult('{"error":"No such directory"}', "", 1, "/old")
    verify(!helperError.ok)
    compare(helperError.error, "No such directory")

    var malformed = PickerLogic.parseResult("not-json", "broken output", 0, "/old")
    verify(!malformed.ok)
    compare(malformed.error, "broken output")
  }
}
