import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Popup {
  id: threadMenu

  required property var panel
  required property var rowItem
  x: parent ? parent.width - width : 0
  y: parent ? parent.height + Style.space(4) : 0
  width: Style.space(240)
  padding: Style.space(4)
  property bool choosingProject: false
  // A modal, non-dimming overlay reliably observes clicks
  // outside the menu and uses them only to dismiss it.
  modal: true
  dim: false
  focus: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  onClosed: choosingProject = false

  background: BorderSurface {
    color: Color.background
    borderSpec: Border.flat(panel.appearance.dim, 1)
    radius: Style.cornerRadius
  }

  contentItem: Column {
    spacing: 0

    Repeater {
      visible: !threadMenu.choosingProject
      model: rowItem.modelData.remoteId ? [
        { label: rowItem.pinned ? "Unpin thread" : "Pin thread", hint: "p", action: "pin" },
        { label: "Open thread", hint: "Enter / o", action: "open" },
        { label: "Open terminal", hint: "t / Shift+Enter", action: "terminal" },
        { label: "Rename…", hint: "r", action: "rename" },
        { label: "New thread here", hint: "n", action: "new" },
        { label: "Archive", hint: "y", action: "archive" }
      ] : [
        { label: rowItem.pinned ? "Unpin thread" : "Pin thread", hint: "p", action: "pin" },
        { label: "Open thread", hint: "Enter / o", action: "open" },
        { label: "Open terminal", hint: "t / Shift+Enter", action: "terminal" },
        { label: "Rename…", hint: "r", action: "rename" },
        { label: "New thread here", hint: "n", action: "new" },
        { label: "Move to…", hint: "›", action: "move" },
        { label: "Archive", hint: "y", action: "archive" }
      ]

      delegate: Rectangle {
        id: menuChoice
        required property var modelData
        visible: !threadMenu.choosingProject
        width: parent.width
        height: visible ? Style.space(38) : 0
        radius: Style.cornerRadius
        color: menuChoiceMouse.containsMouse ? panel.appearance.faint : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: menuChoice.modelData.label
          color: menuChoice.modelData.action === "archive"
            ? Color.urgent : panel.appearance.foreground
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: menuChoice.modelData.hint
          color: panel.appearance.dim
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: menuChoiceMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var action = String(menuChoice.modelData.action || "")
            if (action === "move") {
              threadMenu.choosingProject = true
              return
            }
            threadMenu.close()
            if (action === "pin") {
              panel.sidebarActions.actions.togglePin(
                rowItem.modelData.remoteId, rowItem.threadData)
            } else if (action === "open") {
              panel.sidebarActions.actions.openSelected("context-menu")
            } else if (action === "terminal") {
              panel.sidebarActions.actions.openSelectedTerminal()
            } else if (action === "rename") {
              panel.sidebarActions.actions.renameRow(rowItem.modelData)
            } else if (action === "new") {
              panel.sidebarActions.actions.createThreadForRow(rowItem.modelData)
            } else if (action === "archive") {
              panel.sidebarActions.actions.archiveRow(rowItem.modelData)
            }
          }
        }
      }
    }

    Column {
      visible: threadMenu.choosingProject && !rowItem.modelData.remoteId
      width: parent.width
      spacing: 0

      Rectangle {
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: moveBackMouse.containsMouse ? panel.appearance.faint : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: "‹  Move to project"
          color: panel.appearance.foreground
          font.family: panel.appearance.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        MouseArea {
          id: moveBackMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: threadMenu.choosingProject = false
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: panel.appearance.faint
      }

      Repeater {
        model: rowItem.modelData.remoteId ? [] : panel.providerActions.projectMoveTargets(rowItem.threadData)

        delegate: Rectangle {
          id: projectChoice
          required property var modelData
          width: parent.width
          height: Style.space(48)
          radius: Style.cornerRadius
          color: projectChoiceMouse.containsMouse ? panel.appearance.faint : "transparent"

          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
              width: parent.width
              text: projectChoice.modelData.name
              textFormat: Text.PlainText
              color: panel.appearance.foreground
              font.family: panel.appearance.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: projectChoice.modelData.path
              textFormat: Text.PlainText
              color: panel.appearance.dim
              font.family: panel.appearance.fontFamily
              font.pixelSize: Math.max(9, Style.font.caption - 1)
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: projectChoiceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              threadMenu.close()
              panel.sidebarActions.actions.moveRowToProject(
                rowItem.modelData, projectChoice.modelData)
            }
          }
        }
      }

      Text {
        visible: panel.providerActions.projectMoveTargets(rowItem.threadData).length === 0
        width: parent.width
        height: Style.space(42)
        text: "No other projects"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
