// Purpose: Implements the Sidebar Provider Menu user-interface component.
import QtQuick
import QtQuick.Controls
import qs.Commons

Popup {
  required property var panel
  id: providerMenu
  property int selectedIndex: 0
  x: 0
  y: parent.height - Style.space(2)
  width: Math.min(parent.width - Style.space(8), Style.space(176))
  height: providerChoicesColumn.implicitHeight + Style.space(8)
  padding: Style.space(4)
  modal: false
  dim: false
  focus: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  function resetSelection() {
    selectedIndex = 0
    for (var i = 0; i < panel.providerChoices.length; i++) {
      if (panel.providerChoices[i].id === panel.activeProvider) {
        selectedIndex = i
        return
      }
    }
  }

  function moveSelection(direction) {
    var count = panel.providerChoices.length
    if (count === 0) return
    selectedIndex = (selectedIndex + direction + count) % count
  }

  function activateSelection() {
    if (selectedIndex < 0 || selectedIndex >= panel.providerChoices.length) return
    panel.providerActions.selectProvider(panel.providerChoices[selectedIndex].id)
  }

  onOpened: resetSelection()

  background: Rectangle {
    color: Color.popups.background
    border.color: panel.appearance.faint
    border.width: Math.max(1, Style.space(1))
    radius: Style.cornerRadius
  }

  contentItem: Column {
    id: providerChoicesColumn
    spacing: 0

    Repeater {
      model: panel.providerChoices

      Rectangle {
        required property var modelData
        required property int index
        width: providerMenu.availableWidth
        height: Style.space(30)
        radius: Math.max(2, Style.cornerRadius - Style.space(2))
        color: providerChoiceMouse.containsMouse
          || index === providerMenu.selectedIndex
          ? panel.appearance.faint : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.label
          color: modelData.id === panel.activeProvider
            ? Color.accent : panel.appearance.foreground
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.body
          font.bold: modelData.id === panel.activeProvider
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          visible: modelData.id === panel.activeProvider
          text: "●"
          color: Color.accent
          font.family: panel.appearance.fontFamily
          font.pixelSize: Math.max(7, Style.font.caption - 2)
        }

        MouseArea {
          id: providerChoiceMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onContainsMouseChanged: {
            if (containsMouse) providerMenu.selectedIndex = parent.index
          }
          onClicked: panel.providerActions.selectProvider(modelData.id)
        }
      }
    }
  }
}
