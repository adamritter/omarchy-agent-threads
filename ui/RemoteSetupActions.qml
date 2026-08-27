import QtQuick
import qs.Commons

Row {
  required property var panel
  required property var setup
  width: parent.width
  spacing: Style.space(8)

  Rectangle {
    width: (parent.width - Style.space(8)) / 2
    height: Style.space(36)
    radius: Style.cornerRadius
    color: cancelRemoteMouse.containsMouse ? panel.appearance.faint : "transparent"
    border.width: 1
    border.color: panel.appearance.dim

    Text {
      anchors.centerIn: parent
      text: "Cancel"
      color: panel.appearance.foreground
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: cancelRemoteMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.overlayActions.closeRemoteSetup()
    }
  }

  Rectangle {
    width: (parent.width - Style.space(8)) / 2
    height: Style.space(36)
    radius: Style.cornerRadius
    color: addRemoteMouse.containsMouse
      ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.accent, 0.18)
    border.width: 1
    border.color: Color.accent

    Text {
      anchors.centerIn: parent
      text: setup.editing ? "Save" : "Add"
      color: Color.accent
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    MouseArea {
      id: addRemoteMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: panel.overlayActions.saveRemoteSetup()
    }
  }
}
