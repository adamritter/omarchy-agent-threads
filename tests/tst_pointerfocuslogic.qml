// Purpose: Verifies pointerfocuslogic behavior with Qt Quick Test.
import QtQuick
import QtTest
import "../logic/PointerFocusLogic.js" as PointerFocusLogic

TestCase {
  name: "PointerFocusLogic"

  function test_parsesAndRoundsCursorCoordinates() {
    compare(PointerFocusLogic.cursorPoint('{"x":840,"y":679}'), {
      valid: true, x: 840, y: 679
    })
    compare(PointerFocusLogic.cursorPoint('{"x":12.6,"y":24.2}'), {
      valid: true, x: 13, y: 24
    })
  }

  function test_rejectsMissingOrMalformedCoordinates() {
    compare(PointerFocusLogic.cursorPoint("not json"), {
      valid: false, x: -1, y: -1
    })
    compare(PointerFocusLogic.cursorPoint('{"x":12}'), {
      valid: false, x: -1, y: -1
    })
  }
}
