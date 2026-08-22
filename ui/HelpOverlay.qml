import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  required property var panel
  anchors.fill: parent
  visible: panel.helpOpen && !panel.remoteSetupOpen
  color: Color.popups.background
  radius: Style.cornerRadius

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(10)

    Text {
      width: parent.width
      text: "KEYBOARD"
      color: Color.accent
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Repeater {
      model: panel.helpItems

      delegate: Item {
        required property var modelData
        width: parent.width
        height: Math.max(helpKey.implicitHeight, helpDescription.implicitHeight)

        Text {
          id: helpKey
          width: Style.space(120)
          text: parent.modelData.keys
          color: panel.foreground
          font.family: panel.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          id: helpDescription
          anchors.left: helpKey.right
          anchors.right: parent.right
          text: parent.modelData.description
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
        }
      }
    }

    PanelSeparator { width: parent.width }

    Text {
      width: parent.width
      text: "HIGHLIGHTS"
      color: Color.accent
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      width: parent.width
      text: "Strong blue: active thread\nFaint: keyboard selection or pointer hover"
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
      lineHeight: 1.35
      wrapMode: Text.Wrap
    }

    Item { width: 1; height: Style.space(4) }

    Text {
      width: parent.width
      text: "Close with ?, Enter, or Esc."
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }
}
