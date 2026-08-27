import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../logic/PresentationLogic.js" as PresentationLogic

Item {
  id: root
  required property var panel
  property alias providerMenu: providerMenuControl
  width: parent.width
  height: Style.space(36)

  Text {
    id: headerTitle
    anchors.left: parent.left
    anchors.right: sidebarScopeButton.left
    anchors.rightMargin: Style.space(8)
    height: parent.height
    text: PresentationLogic.headerTitle({
      projectPickerOpen: false,
      remoteSetupOpen: panel.session.remoteSetupOpen,
      renameOpen: panel.session.renameOpen,
      helpOpen: panel.session.helpOpen,
      providerLabel: panel.providerActions.providerLabel()
    })
    color: panel.appearance.foreground
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter

    MouseArea {
      anchors.fill: parent
      enabled: !panel.session.remoteSetupOpen && !panel.session.renameOpen && !panel.session.helpOpen
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (providerMenuControl.opened) providerMenuControl.close()
        else providerMenuControl.open()
      }
    }
  }

  PanelActionButton {
    id: sidebarScopeButton
    visible: !panel.session.remoteSetupOpen && !panel.session.renameOpen && !panel.session.helpOpen
    anchors.right: newThreadButton.left
    anchors.rightMargin: Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: visible ? implicitWidth : 0
    size: Style.space(24)
    iconText: panel.service.sidebarScope === "global" ? "󰖟" : "󰍹"
    tooltipText: panel.service.sidebarScope === "global"
      ? "Sidebar scope: all workspaces"
      : "Sidebar scope: this workspace"
    foreground: panel.service.sidebarScope === "global" ? Color.accent : panel.appearance.dim
    hoverColor: Color.accent
    fontFamily: panel.appearance.fontFamily
    fontSize: Style.font.body
    onClicked: panel.focusActions.toggleSidebarScope()
  }

  SidebarProviderMenu {
    id: providerMenuControl
    panel: root.panel
  }

  Item {
    id: newThreadButton
    visible: !panel.session.remoteSetupOpen && !panel.session.renameOpen && !panel.session.helpOpen
    anchors.right: searchButton.left
    anchors.rightMargin: Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: visible ? Style.space(18) : 0
    height: Style.space(24)

    Text {
      anchors.centerIn: parent
      text: "+"
      color: newThreadMouse.containsMouse ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: newThreadMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.sidebarActions.newSelectedThread()
    }
  }

  Item {
    id: searchButton
    visible: !panel.session.remoteSetupOpen && !panel.session.renameOpen && !panel.session.helpOpen
    anchors.right: notificationButton.left
    anchors.rightMargin: Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: visible ? Style.space(24) : 0
    height: Style.space(24)

    Text {
      anchors.centerIn: parent
      text: "󰍉"
      color: searchMouse.containsMouse ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: searchMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.overlayActions.startSearch()
    }

    ToolTip.visible: searchMouse.containsMouse
    ToolTip.text: "Search threads and projects · /"
  }

  Item {
    id: notificationButton
    visible: !panel.session.remoteSetupOpen && !panel.session.renameOpen && !panel.session.helpOpen
    anchors.right: remoteButton.left
    anchors.rightMargin: Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: visible ? Style.space(20) : 0
    height: Style.space(24)

    Text {
      anchors.centerIn: parent
      text: panel.service.notificationsEnabled ? "󰂚" : "󰂛"
      color: notificationMouse.containsMouse
        ? Color.accent
        : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: notificationMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.service.settings.toggleNotifications()
    }

    ToolTip.visible: notificationMouse.containsMouse
    ToolTip.text: panel.service.notificationsEnabled
      ? "Thread notifications: on · click to turn off"
      : "Thread notifications: off · click to turn on"
  }

  Item {
    id: remoteButton
    visible: !panel.session.renameOpen && !panel.session.helpOpen
      && (panel.activeProvider === "codex"
      || panel.activeProvider === "claude" || panel.activeProvider === "opencode")
    anchors.right: helpButton.left
    anchors.rightMargin: Style.space(4)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: visible ? Style.space(20) : 0
    height: Style.space(24)

    Column {
      anchors.centerIn: parent
      spacing: -Style.space(5)

      Text {
        text: "→"
        color: panel.session.remoteSetupOpen || remoteMouse.containsMouse
          ? Color.accent : panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(9, Style.font.caption - 1)
      }

      Text {
        text: "←"
        color: panel.session.remoteSetupOpen || remoteMouse.containsMouse
          ? Color.accent : panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(9, Style.font.caption - 1)
      }
    }

    MouseArea {
      id: remoteMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (panel.session.remoteSetupOpen) panel.overlayActions.closeRemoteSetup()
        else panel.overlayActions.openRemoteSetup()
      }
    }
  }

  Item {
    id: helpButton
    anchors.right: parent.right
    anchors.rightMargin: -Style.space(6)
    anchors.top: parent.top
    anchors.topMargin: -Style.space(6)
    width: Style.space(18)
    height: Style.space(24)

    Text {
      anchors.centerIn: parent
      text: "?"
      color: panel.session.helpOpen || helpMouse.containsMouse ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: helpMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.session.helpOpen = !panel.session.helpOpen
    }
  }
}
