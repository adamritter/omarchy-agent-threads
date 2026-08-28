// Purpose: Implements the Thread List user-interface component.
import QtQuick
import QtQuick.Controls
import "." as Components

ListView {
  id: root

  required property var panel

  function renderSnapshot() {
    var rendered = []
    for (var index = 0; index < count; index++) {
      var item = itemAtIndex(index)
      rendered.push(item ? item.renderSnapshot() : {
        index: index,
        instantiated: false
      })
    }
    return rendered
  }

  anchors.fill: parent
  visible: !panel.session.helpOpen
  model: panel.viewRows
  clip: true
  spacing: 0
  currentIndex: panel.selectedIndex
  boundsBehavior: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Components.FastScrollHandler {
    flickable: root
    speedMultiplier: 2
  }

  delegate: Components.ThreadListRow {
    panel: root.panel
  }
}
