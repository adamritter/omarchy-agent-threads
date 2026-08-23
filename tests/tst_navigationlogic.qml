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

  function test_calculatesViewportSteps() {
    compare(NavigationLogic.pageStep(4, 13, 0.5), 5)
    compare(NavigationLogic.pageStep(4, 13, 1), 10)
    compare(NavigationLogic.pageStep(-1, -1, 0.5), 1)
  }
}
