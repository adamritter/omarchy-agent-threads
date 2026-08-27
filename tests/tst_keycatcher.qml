import QtQuick
import QtTest
import "../ui" as Ui

TestCase {
  name: "SidebarKeyCatcher"
  when: windowShown
  width: 320
  height: 240

  Ui.SidebarKeyCatcher {
    id: catcher
    anchors.fill: parent
  }

  SignalSpy { id: moveSpy; target: catcher; signalName: "moveRequested" }
  SignalSpy { id: pageSpy; target: catcher; signalName: "pageRequested" }
  SignalSpy { id: edgeSpy; target: catcher; signalName: "edgeRequested" }
  SignalSpy { id: textSpy; target: catcher; signalName: "textKey" }
  SignalSpy { id: activateSpy; target: catcher; signalName: "activateRequested" }
  SignalSpy { id: terminalSpy; target: catcher; signalName: "terminalRequested" }
  SignalSpy { id: fastSpy; target: catcher; signalName: "fastToggleRequested" }
  SignalSpy { id: frontendSpy; target: catcher; signalName: "frontendToggleRequested" }

  function init() {
    moveSpy.clear()
    pageSpy.clear()
    edgeSpy.clear()
    textSpy.clear()
    activateSpy.clear()
    terminalSpy.clear()
    fastSpy.clear()
    frontendSpy.clear()
    catcher.forceActiveFocus()
    verify(catcher.activeFocus)
  }

  function test_superCtrlFTogglesFastWithoutPaging() {
    keyClick(Qt.Key_F, Qt.ControlModifier | Qt.MetaModifier)
    compare(fastSpy.count, 1)
    compare(pageSpy.count, 0)

    keyClick(Qt.Key_F, Qt.ControlModifier)
    compare(fastSpy.count, 1)
    compare(pageSpy.count, 1)
  }

  function test_frontendToggleRequiresSuperCtrlA() {
    keyClick(Qt.Key_A)
    compare(frontendSpy.count, 0)
    compare(textSpy.count, 1)

    keyClick(Qt.Key_A, Qt.ControlModifier | Qt.MetaModifier)
    compare(frontendSpy.count, 1)
    compare(textSpy.count, 1)
  }

  function test_shiftEnterRequestsTerminalWithoutActivation() {
    keyClick(Qt.Key_Return, Qt.ShiftModifier)
    compare(terminalSpy.count, 1)
    compare(activateSpy.count, 0)

    keyClick(Qt.Key_Return)
    compare(terminalSpy.count, 1)
    compare(activateSpy.count, 1)
  }

  function test_emitsMovementRequests() {
    keyClick(Qt.Key_J)
    compare(moveSpy.count, 1)
    compare(moveSpy.signalArguments[0][0], 0)
    compare(moveSpy.signalArguments[0][1], 1)
  }

  function test_emitsHalfAndFullPageRequests() {
    keyClick(Qt.Key_D, Qt.ControlModifier)
    compare(pageSpy.count, 1)
    compare(pageSpy.signalArguments[0][0], 1)
    compare(pageSpy.signalArguments[0][1], 0.5)

    keyClick(Qt.Key_B, Qt.ControlModifier)
    compare(pageSpy.count, 2)
    compare(pageSpy.signalArguments[1][0], -1)
    compare(pageSpy.signalArguments[1][1], 1)

    keyClick(Qt.Key_PageUp)
    compare(pageSpy.count, 3)
    compare(pageSpy.signalArguments[2][0], -1)
  }

  function test_emitsEdgeAndTextRequests() {
    keyClick(Qt.Key_Home)
    keyClick(Qt.Key_End)
    compare(edgeSpy.count, 2)
    compare(edgeSpy.signalArguments[0][0], -1)
    compare(edgeSpy.signalArguments[1][0], 1)

    keyClick(Qt.Key_Q)
    compare(textSpy.count, 1)
    compare(textSpy.signalArguments[0][0], "q")
  }
}
