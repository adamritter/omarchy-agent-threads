import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "." as Components

Item {
  id: actions

  required property var panel
  required property var rowItem
  readonly property real reservedWidth: rowItem.needsRemoteClaudeAction
    ? Style.space(106) : (rowItem.sectionRow ? Style.space(104) : Style.space(68))

  function openMenu() {
    panel.selectedIndex = rowItem.index
    if (rowItem.remoteRow) remoteMenu.open()
    else if (rowItem.projectRow) projectMenu.open()
    else if (rowItem.threadRow) threadMenu.open()
  }

  Rectangle {
    id: threadMenuButton
    visible: rowItem.threadRow
      && (rowItem.pointerHovered || threadMenuMouse.containsMouse || threadMenu.opened)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(28)
    height: width
    radius: Style.cornerRadius
    color: threadMenuMouse.containsMouse || threadMenu.opened
      ? Util.alpha(panel.foreground, 0.14) : "transparent"

    Text {
      anchors.centerIn: parent
      text: "⋯"
      color: panel.foreground
      font.family: panel.fontFamily
      font.pixelSize: Style.font.title
      verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
      id: threadMenuMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: actions.openMenu()
    }
  }

  Rectangle {
    id: threadPinButton
    visible: rowItem.threadRow
      && (rowItem.pointerHovered || threadPinMouse.containsMouse
        || rowItem.pinned || rowItem.pinning)
    anchors.right: threadMenuButton.left
    anchors.rightMargin: Style.space(2)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(28)
    height: width
    radius: Style.cornerRadius
    color: threadPinMouse.containsMouse
      ? Util.alpha(panel.foreground, 0.14) : "transparent"

    Text {
      anchors.centerIn: parent
      text: "󰐃"
      color: rowItem.pinned ? Color.accent : panel.dim
      opacity: rowItem.pinning ? 0.45 : 1
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: threadPinMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !rowItem.pinning
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        panel.selectedIndex = rowItem.index
        panel.sidebarActions.togglePin(
          rowItem.modelData.remoteId, rowItem.threadData)
      }
    }
  }

  Rectangle {
    id: remoteClaudeActionButton
    visible: rowItem.needsRemoteClaudeAction
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    width: visible ? Style.space(92) : 0
    height: Style.space(30)
    radius: Style.cornerRadius
    color: remoteClaudeActionMouse.containsMouse
      ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.accent, 0.16)
    border.width: 1
    border.color: Color.accent

    Text {
      anchors.centerIn: parent
      text: rowItem.loggingInRemoteClaude ? "OPENING…" : "LOGIN"
      color: Color.accent
      font.family: panel.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      font.bold: true
    }

    MouseArea {
      id: remoteClaudeActionMouse
      anchors.fill: parent
      enabled: !rowItem.presentation.remoteClaudeLoginRunning
      hoverEnabled: enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        panel.selectedIndex = rowItem.index
        panel.sidebarActions.loginRemoteForRow(rowItem.modelData)
      }
    }
  }

  Item {
    id: remoteManageButton
    visible: rowItem.remoteRow && !rowItem.needsRemoteClaudeAction
      && (rowItem.pointerHovered || remoteManageMouse.containsMouse || remoteMenu.opened)
    anchors.right: sectionPinButton.left
    anchors.rightMargin: Style.space(2)
    anchors.verticalCenter: parent.verticalCenter
    width: visible ? Style.space(28) : 0
    height: width

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: remoteManageMouse.containsMouse
        ? Util.alpha(panel.foreground, 0.14) : "transparent"
    }

    Text {
      anchors.centerIn: parent
      text: "⋯"
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.title
    }

    MouseArea {
      id: remoteManageMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: actions.openMenu()
    }
  }

  Item {
    id: sectionPinButton
    visible: rowItem.sectionRow && !rowItem.needsRemoteClaudeAction
      && (rowItem.pointerHovered || sectionPinMouse.containsMouse
        || rowItem.pinnedSection)
    anchors.right: newProjectButton.left
    anchors.rightMargin: Style.space(2)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(28)
    height: width

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: sectionPinMouse.containsMouse
        ? Util.alpha(panel.foreground, 0.14) : "transparent"
    }

    Text {
      anchors.centerIn: parent
      text: "󰐃"
      color: rowItem.pinnedSection ? Color.accent : panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: sectionPinMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        panel.selectedIndex = rowItem.index
        panel.sidebarActions.toggleSectionPinForRow(rowItem.modelData)
      }
    }
  }

  Item {
    id: newProjectButton
    visible: rowItem.sectionRow && !rowItem.needsRemoteClaudeAction
      && (rowItem.pointerHovered || newProjectMouse.containsMouse)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(28)
    height: width

    Text {
      anchors.centerIn: parent
      text: rowItem.presentation.launchingProject ? "…" : "+"
      color: newProjectMouse.containsMouse ? Color.accent : panel.foreground
      font.family: panel.fontFamily
      font.pixelSize: Style.font.title
    }

    MouseArea {
      id: newProjectMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        panel.selectedIndex = rowItem.index
        panel.sidebarActions.createThreadForRow(rowItem.modelData)
      }
    }
  }

  Components.ThreadContextMenu {
    id: threadMenu
    panel: actions.panel
    rowItem: actions.rowItem
  }

  Components.ProjectContextMenu {
    id: projectMenu
    panel: actions.panel
    rowItem: actions.rowItem
  }

  Components.RemoteContextMenu {
    id: remoteMenu
    panel: actions.panel
    rowItem: actions.rowItem
  }
}
