import QtQuick

Item {
  id: root

  property bool blocked: false

  signal moveRequested(int dx, int dy)
  signal pageRequested(int direction, real fraction)
  signal edgeRequested(int edge)
  signal activateRequested()
  signal terminalRequested()
  signal returnRequested()
  signal closeRequested()
  signal deleteRequested()
  signal tabRequested(int direction)
  signal textKey(string text)

  focus: true
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (blocked) return

    var control = event.modifiers & Qt.ControlModifier
    if (control && (event.key === Qt.Key_D || event.key === Qt.Key_U)) {
      pageRequested(event.key === Qt.Key_D ? 1 : -1, 0.5)
      event.accepted = true
      return
    }
    if (control && (event.key === Qt.Key_F || event.key === Qt.Key_B)) {
      pageRequested(event.key === Qt.Key_F ? 1 : -1, 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
      pageRequested(event.key === Qt.Key_PageDown ? 1 : -1, 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
      edgeRequested(event.key === Qt.Key_Home ? -1 : 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Escape) {
      closeRequested(); event.accepted = true; return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      tabRequested((event.modifiers & Qt.ShiftModifier)
        || event.key === Qt.Key_Backtab ? -1 : 1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down || event.text === "j") {
      moveRequested(0, 1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Up || event.text === "k") {
      moveRequested(0, -1); event.accepted = true; return
    }
    if (event.key === Qt.Key_Right || event.text === "l") {
      moveRequested(1, 0); event.accepted = true; return
    }
    if (event.key === Qt.Key_Left || event.text === "h") {
      moveRequested(-1, 0); event.accepted = true; return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (event.modifiers & Qt.ShiftModifier) {
        terminalRequested(); event.accepted = true; return
      }
      returnRequested()
      activateRequested(); event.accepted = true; return
    }
    if (event.key === Qt.Key_Space) {
      activateRequested(); event.accepted = true; return
    }
    if (event.text === "x" || event.text === "X") {
      deleteRequested(); event.accepted = true; return
    }
    if (event.text && event.text.length === 1) {
      textKey(event.text)
      event.accepted = true
    }
  }
}
