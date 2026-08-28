// Purpose: Implements the Project Context Menu user-interface component.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Popup {
  id: projectMenu

  required property var panel
  required property var rowItem
  x: Math.max(0, rowItem.width - width - Style.space(6))
  y: rowItem.height - Style.space(4)
  width: Style.space(220)
  padding: Style.space(4)
  modal: true
  dim: false
  focus: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  background: BorderSurface {
    color: Color.background
    borderSpec: Border.flat(panel.appearance.dim, 1)
    radius: Style.cornerRadius
  }

  contentItem: Column {
    spacing: 0

    Repeater {
      model: [
        { label: "Open terminal", hint: "t / Shift+Enter", action: "terminal" },
        { label: "New thread here", hint: "n", action: "new" },
        { label: rowItem.pinnedSection ? "Unpin project" : "Pin project",
          hint: "p", action: "pin" }
      ]

      delegate: Rectangle {
        id: projectMenuChoice
        required property var modelData
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: projectMenuMouse.containsMouse ? panel.appearance.faint : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: projectMenuChoice.modelData.label
          color: panel.appearance.foreground
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: projectMenuChoice.modelData.hint
          color: panel.appearance.dim
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: projectMenuMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var action = String(projectMenuChoice.modelData.action || "")
            projectMenu.close()
            if (action === "terminal")
              panel.sidebarActions.actions.openSelectedTerminal()
            else if (action === "new")
              panel.sidebarActions.actions.createThreadForRow(rowItem.modelData)
            else if (action === "pin")
              panel.sidebarActions.actions.toggleSectionPinForRow(rowItem.modelData)
          }
        }
      }
    }
  }
}
