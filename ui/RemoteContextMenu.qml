import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Popup {
  id: remoteMenu

  required property var panel
  required property var rowItem
  x: Math.max(0, rowItem.width - width - Style.space(6))
  y: rowItem.height - Style.space(4)
  width: Style.space(210)
  padding: Style.space(4)
  modal: true
  dim: false
  focus: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  readonly property bool testingThis: panel.service.remoteTestRunning
    && panel.service.remoteTestHostId === String(rowItem.modelData.remoteId || "")
  readonly property bool hasTestResult: panel.service.remoteTestHostId
      === String(rowItem.modelData.remoteId || "")
    && String(panel.service.remoteTestMessage || "") !== ""

  background: BorderSurface {
    color: Color.background
    borderSpec: Border.flat(panel.dim, 1)
    radius: Style.cornerRadius
  }

  contentItem: Column {
    spacing: 0

    Repeater {
      model: [
        { label: "Open terminal", action: "terminal" },
        { label: remoteMenu.testingThis ? "Testing…" : "Test connection", action: "test" },
        { label: "Edit connection…", action: "edit" },
        { label: "Disable remote", action: "disable" }
      ]

      delegate: Rectangle {
        id: remoteMenuChoice
        required property var modelData
        width: parent.width
        height: Style.space(38)
        radius: Style.cornerRadius
        color: remoteMenuChoiceMouse.containsMouse ? panel.faint : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: remoteMenuChoice.modelData.label
          color: remoteMenuChoice.modelData.action === "disable"
            ? Color.urgent : panel.foreground
          font.family: panel.fontFamily
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: remoteMenuChoiceMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: remoteMenuChoice.modelData.action !== "test"
            || !remoteMenu.testingThis
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            var action = String(remoteMenuChoice.modelData.action || "")
            if (action === "test") {
              panel.sidebarActions.testRemoteForRow(rowItem.modelData)
              return
            }
            remoteMenu.close()
            if (action === "terminal")
              panel.sidebarActions.openSelectedTerminal()
            else if (action === "edit")
              panel.sidebarActions.manageRemoteForRow(rowItem.modelData)
            else if (action === "disable")
              panel.sidebarActions.disableRemoteForRow(rowItem.modelData)
          }
        }
      }
    }

    Text {
      visible: remoteMenu.hasTestResult
      width: parent.width
      topPadding: Style.space(5)
      leftPadding: Style.space(10)
      rightPadding: Style.space(10)
      bottomPadding: Style.space(7)
      text: panel.service.remoteTestMessage
      textFormat: Text.PlainText
      color: remoteMenu.testingThis ? panel.dim
        : (panel.service.remoteTestSucceeded ? Color.accent : Color.urgent)
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }
}
