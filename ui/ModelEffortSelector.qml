import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var panel
  implicitWidth: Style.space(148)
  implicitHeight: Style.space(22)
  readonly property var service: panel.service
  readonly property string providerType: panel.activeProvider
  readonly property var contextHost: {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    if (providerType !== "codex" && row && row.host
        && String(row.host.providerType || "") === providerType) return row.host
    return providerType !== "codex" ? panel.activeProviderHost : null
  }
  readonly property string contextPath: {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    return String(row && row.path || "")
  }

  ModelEffortOptions {
    id: options
    panel: root.panel
    service: root.service
    providerType: root.providerType
    contextHost: root.contextHost
    contextPath: root.contextPath
  }

  Text {
    id: selectorLabel
    anchors.fill: parent
    text: options.selectorText()
    textFormat: Text.PlainText
    color: selectorMouse.containsMouse || picker.opened
      ? panel.appearance.foreground : Util.alpha(panel.appearance.foreground, 0.48)
    font.family: panel.appearance.fontFamily
    font.pixelSize: Math.max(8, Style.font.caption - 1)
    horizontalAlignment: Text.AlignRight
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideLeft
  }

  MouseArea {
    id: selectorMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: picker.opened ? picker.close() : picker.open()
  }

  HyprlandFocusGrab {
    active: picker.opened
    windows: root.QsWindow.window ? [root.QsWindow.window] : []
    onCleared: picker.close()
  }

  Popup {
    id: picker
    x: root.width - width
    y: -height - Style.space(4)
    width: Style.space(230)
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

      Text {
        width: parent.width
        height: Style.space(26)
        leftPadding: Style.space(9)
        text: "MODEL"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: options.modelChoices()

        delegate: Rectangle {
          id: modelChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: modelMouse.containsMouse ? panel.appearance.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.right: modelCheck.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: modelChoice.modelData.label
              + (modelChoice.modelData.isDefault ? "  · recommended" : "")
            textFormat: Text.PlainText
            color: options.selectedModel() === modelChoice.modelData.id
              ? Color.accent : panel.appearance.foreground
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: modelCheck
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: options.selectedModel() === modelChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: modelMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.service.providers.setModelForProvider(
              root.providerType, modelChoice.modelData.id)
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: panel.appearance.faint
      }

      Text {
        width: parent.width
        height: Style.space(26)
        leftPadding: Style.space(9)
        text: "EFFORT"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: options.effortChoices()

        delegate: Rectangle {
          id: effortChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: effortMouse.containsMouse ? panel.appearance.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: effortChoice.modelData.label
            textFormat: Text.PlainText
            color: options.selectedEffort() === effortChoice.modelData.id
              ? Color.accent : panel.appearance.foreground
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: options.selectedEffort() === effortChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: effortMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.service.providers.setEffortForProvider(
                root.providerType, effortChoice.modelData.id)
              picker.close()
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: options.hasAgentChoices() ? 1 : 0
        visible: options.hasAgentChoices()
        color: panel.appearance.faint
      }

      Text {
        width: parent.width
        height: visible ? Style.space(26) : 0
        visible: options.hasAgentChoices()
        leftPadding: Style.space(9)
        text: "AGENT"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: options.hasAgentChoices() ? options.agentChoices() : []

        delegate: Rectangle {
          id: agentChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: agentMouse.containsMouse ? panel.appearance.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: agentChoice.modelData.label
            textFormat: Text.PlainText
            color: options.selectedAgent() === agentChoice.modelData.id
              ? Color.accent : panel.appearance.foreground
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: options.selectedAgent() === agentChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.appearance.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: agentMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.service.providers.setAgentForProvider(
                root.providerType, agentChoice.modelData.id)
              picker.close()
            }
          }
        }
      }
    }
  }
}
