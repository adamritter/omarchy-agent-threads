// Purpose: Verifies navigationlogic behavior with Qt Quick Test.
import QtQuick
import QtTest
import "../logic/NavigationLogic.js" as NavigationLogic

TestCase {
  name: "NavigationLogic"

  function test_buildsAndBoundsCounts() {
    compare(NavigationLogic.appendCount("", "0"), "")
    compare(NavigationLogic.appendCount("", "1"), "1")
    compare(NavigationLogic.appendCount("1", "0"), "10")
    compare(NavigationLogic.appendCount("9999", "9"), "9999")
    compare(NavigationLogic.countValue("8"), 8)
    compare(NavigationLogic.countValue(""), 1)
  }

  function test_movesWithinVisibleRows() {
    compare(NavigationLogic.movedIndex(4, 1, 10, 20), 14)
    compare(NavigationLogic.movedIndex(4, -1, 8, 20), 0)
    compare(NavigationLogic.movedIndex(19, 1, 2, 20), 19)
    compare(NavigationLogic.movedIndex(0, 1, 1, 0), -1)
  }

  function test_selectsOneBasedCountedRows() {
    compare(NavigationLogic.countedRowIndex("", 20), 0)
    compare(NavigationLogic.countedRowIndex("1", 20), 0)
    compare(NavigationLogic.countedRowIndex("8", 20), 7)
    compare(NavigationLogic.countedRowIndex("99", 20), 19)
    compare(NavigationLogic.countedRowIndex("8", 0), -1)
  }

  function test_findsThreadRowsByInitial() {
    var rows = [
      { kind: "project", title: "Workspace" },
      { kind: "thread", title: "Alpha" },
      { kind: "thread", title: "write tests" },
      { kind: "remote", title: "Work server" },
      { kind: "thread", title: "Wait for CI" },
      { kind: "thread", title: "work later" },
      { kind: "thread", title: "Fix lint" }
    ]
    function title(row) { return row.title }

    compare(NavigationLogic.matchingThreadIndex(rows, 0, 1, "w", "", title), 2)
    compare(NavigationLogic.matchingThreadIndex(rows, 0, 1, "W", "", title), 4)
    compare(NavigationLogic.matchingThreadIndex(rows, 0, 1, "w", "2", title), 5)
    compare(NavigationLogic.matchingThreadIndex(rows, 6, -1, "W", "", title), 4)
    compare(NavigationLogic.matchingThreadIndex(rows, 6, -1, "w", "", title), 5)
    compare(NavigationLogic.matchingThreadIndex(rows, 6, -1, "w", "2", title), 2)
    compare(NavigationLogic.matchingThreadIndex(rows, 2, 1, "z", "", title), -1)
  }

  function test_calculatesViewportSteps() {
    compare(NavigationLogic.pageStep(4, 13, 0.5), 5)
    compare(NavigationLogic.pageStep(4, 13, 1), 10)
    compare(NavigationLogic.pageStep(-1, -1, 0.5), 1)
  }
}
