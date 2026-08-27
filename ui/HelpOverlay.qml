import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "." as Components

Rectangle {
  id: root

  required property var panel
  anchors.fill: parent
  visible: panel.session.helpOpen && !panel.session.remoteSetupOpen
  color: Color.popups.background
  radius: Style.cornerRadius

  function maximumContentY() {
    return Math.max(helpFlickable.originY,
      helpFlickable.originY + helpFlickable.contentHeight - helpFlickable.height)
  }

  function setBoundedContentY(value) {
    helpFlickable.cancelFlick()
    helpFlickable.contentY = Math.max(helpFlickable.originY,
      Math.min(maximumContentY(), value))
  }

  function scrollRows(direction) {
    setBoundedContentY(helpFlickable.contentY
      + direction * Style.space(24))
  }

  function scrollPage(direction, fraction) {
    setBoundedContentY(helpFlickable.contentY
      + direction * helpFlickable.height * fraction)
  }

  function scrollToEdge(edge) {
    setBoundedContentY(edge < 0 ? helpFlickable.originY : maximumContentY())
  }

  onVisibleChanged: if (visible)
    helpFlickable.contentY = helpFlickable.originY

  Flickable {
    id: helpFlickable
    anchors.fill: parent
    contentWidth: width
    contentHeight: helpContent.implicitHeight + Style.space(20)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Components.FastScrollHandler {
      flickable: helpFlickable
      speedMultiplier: 1.5
    }

    Column {
      id: helpContent
      x: Style.space(10)
      y: Style.space(10)
      width: helpFlickable.width - Style.space(20)
      spacing: Style.space(8)

      Text {
        width: parent.width
        text: "KEYBOARD"
        color: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Column {
        width: parent.width
        spacing: 0

        Repeater {
          model: panel.helpItems

          delegate: Item {
            required property var modelData
            width: parent.width
            height: Math.max(helpKey.implicitHeight,
              helpDescription.implicitHeight)

            Text {
              id: helpKey
              width: Style.space(120)
              text: parent.modelData.keys
              color: panel.appearance.foreground
              font.family: panel.appearance.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              id: helpDescription
              anchors.left: helpKey.right
              anchors.right: parent.right
              text: parent.modelData.description
              color: panel.appearance.dim
              font.family: panel.appearance.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
            }
          }
        }
      }

      PanelSeparator { width: parent.width }

      Text {
        width: parent.width
        text: "HIGHLIGHTS"
        color: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        width: parent.width
        text: "Strong blue: active thread\nFaint: keyboard selection or pointer hover"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        lineHeight: 1.2
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        text: "Close with ?, Enter, or Esc."
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        text: "Documentation: <a href=\"https://github.com/adamritter/omarchy-agent-threads\">github.com/adamritter/omarchy-agent-threads</a>"
        textFormat: Text.StyledText
        color: panel.appearance.dim
        linkColor: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        onLinkActivated: function(link) { Qt.openUrlExternally(link) }
      }
    }
  }
}
