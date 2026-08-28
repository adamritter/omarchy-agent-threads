// Purpose: Implements the Sidebar Body user-interface component.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "." as Ui

Item {
  id: root

  required property var panel
  property alias threadList: threadListView
  property alias modelEffortSelector: modelEffortSelectorControl
  width: parent.width
  height: Math.max(0, parent.height - y)

  Item {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: codexLimitFooter.top

    Text {
      anchors.centerIn: parent
      width: parent.width - Style.space(40)
      visible: !panel.session.helpOpen && !panel.providerActions.providerLoading()
        && panel.viewRows.length === 0
      text: panel.listActions.totalThreadCount() === 0
        ? "No saved " + panel.providerActions.providerLabel() + " threads"
        : "No threads match this search"
      color: panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
    }

    Ui.ThreadList {
      id: threadListView
      anchors.fill: parent
      panel: root.panel
    }
  }

  Item {
    id: codexLimitFooter
    readonly property string label: panel.providerActions.activeRateLimitText()
    readonly property bool hasSelector: panel.service
      .settings.modelsForProvider(panel.activeProvider).length > 0
    readonly property bool hasFastButton: panel.activeProvider === "codex"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: visible ? Style.space(22) : 0
    visible: (label !== "" || hasSelector || hasFastButton)
      && !panel.session.helpOpen && !panel.session.remoteSetupOpen

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.right: modelEffortSelectorControl.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      visible: parent.label !== ""
      color: Util.alpha(panel.appearance.foreground, 0.42)
      font.family: panel.appearance.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      font.letterSpacing: 0.25
      elide: Text.ElideRight
    }

    Item {
      id: fastModeButton
      readonly property bool fastEnabled: panel.service.settings.fastMode
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      width: visible ? Style.space(18) : 0
      height: Style.space(20)
      visible: codexLimitFooter.hasFastButton

      Text {
        anchors.centerIn: parent
        text: "⚡︎"
        color: fastModeButton.fastEnabled
          ? Color.accent : Util.alpha(panel.appearance.foreground, 0.48)
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: fastModeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.service.settings.toggleFastMode()
      }

      ToolTip.visible: fastModeMouse.containsMouse
      ToolTip.text: fastModeButton.fastEnabled
        ? "Fast responses: on · click or Super+Ctrl+F to turn off"
        : "Fast responses: off · click or Super+Ctrl+F to turn on"
    }

    Ui.ModelEffortSelector {
      id: modelEffortSelectorControl
      anchors.right: fastModeButton.left
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      panel: root.panel
      visible: codexLimitFooter.hasSelector
      width: visible ? implicitWidth : 0
    }
  }
}
