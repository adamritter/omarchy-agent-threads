import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  required property var window
  required property var client
  property bool rememberApproval: false
  anchors.fill: parent
  visible: client.approvalRequest !== null
  color: "#99000000"
  z: 20

  MouseArea { anchors.fill: parent }

  Rectangle {
    anchors.centerIn: parent
    width: Math.min(560, parent.width - 60)
    height: approvalColumn.implicitHeight + 40
    radius: 16
    color: window.raised
    border.color: window.border

    ColumnLayout {
      id: approvalColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 20
      spacing: 14

      Label {
        Layout.fillWidth: true
        text: client.approvalRequest
          ? String(client.approvalRequest.title || "Approval") : ""
        color: window.foreground
        font.pixelSize: 18
        font.weight: Font.DemiBold
      }

      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(220, approvalDetail.implicitHeight + 20)
        Label {
          id: approvalDetail
          width: parent.width
          text: client.approvalRequest
            ? String(client.approvalRequest.detail || "") : ""
          color: window.muted
          font.family: "monospace"
          font.pixelSize: 12
          wrapMode: Text.WrapAnywhere
        }
      }

      CheckBox {
        visible: client.approvalRequest
          && client.approvalRequest.kind !== "unknown"
        text: "Remember for this session"
        checked: rememberApproval
        onToggled: rememberApproval = checked
        palette.text: window.foreground
      }

      RowLayout {
        Layout.alignment: Qt.AlignRight
        Button {
          text: "Decline"
          onClicked: {
            client.answerApproval(false, false)
            rememberApproval = false
          }
        }
        Button {
          text: "Approve"
          highlighted: true
          onClicked: {
            client.answerApproval(true, rememberApproval)
            rememberApproval = false
          }
        }
      }
    }
  }
}
