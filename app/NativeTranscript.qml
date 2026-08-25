import QtQuick
import QtQuick.Controls

Item {
  id: root

  required property var messages
  required property var mathRenderer
  property bool busy: false
  property color background: "#171717"
  property color foreground: "#ececec"
  property color muted: "#a2a2a2"
  property color raised: "#222222"
  property color border: "#383838"

  function messageHeight(item) {
    return item ? item.implicitHeight + 26 : 30
  }

  ListView {
    id: list
    anchors.fill: parent
    anchors.leftMargin: Math.max(24, (parent.width - 820) / 2)
    anchors.rightMargin: Math.max(24, (parent.width - 820) / 2)
    topMargin: 30
    bottomMargin: 40
    clip: true
    spacing: 2
    model: root.messages
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    delegate: Item {
      id: messageRow
      required property var modelData
      width: ListView.view.width
      height: root.messageHeight(messageLoader.item)

      Loader {
        id: messageLoader
        width: parent.width
        sourceComponent: {
          var role = String(messageRow.modelData && messageRow.modelData.role || "assistant")
          if (role === "user") return userMessage
          if (role === "tool") return toolMessage
          if (role === "reasoning") return reasoningMessage
          if (role === "error") return errorMessage
          return assistantMessage
        }
      }

      Component {
        id: userMessage
        Item {
          implicitHeight: userBubble.height
          Rectangle {
            id: userBubble
            anchors.right: parent.right
            width: Math.min(parent.width * 0.76, userText.implicitWidth + 30)
            height: userText.implicitHeight + 20
            radius: 18
            color: "#2f2f2f"
            TextEdit {
              id: userText
              anchors.fill: parent
              anchors.margins: 10
              readOnly: true
              selectByMouse: true
              text: String(messageRow.modelData.content || "")
              textFormat: TextEdit.PlainText
              color: root.foreground
              selectionColor: "#396b5f"
              selectedTextColor: "white"
              wrapMode: TextEdit.Wrap
              font.pixelSize: 14
            }
          }
        }
      }

      Component {
        id: assistantMessage
        MarkdownMessage {
          width: parent.width
          renderer: root.mathRenderer
          content: String(messageRow.modelData.content || "")
          foreground: root.foreground
        }
      }

      Component {
        id: toolMessage
        Rectangle {
          property bool expanded: false
          implicitHeight: toolColumn.implicitHeight + 2
          radius: 11
          color: "#1d1d1d"
          border.color: root.border
          Column {
            id: toolColumn
            width: parent.width
            Rectangle {
              width: parent.width
              height: 42
              color: "transparent"
              Label {
                anchors.left: parent.left
                anchors.right: toolChevron.left
                anchors.leftMargin: 13
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: String(messageRow.modelData.title || "Tool")
                color: root.muted
                font.pixelSize: 12
                elide: Text.ElideMiddle
              }
              Label {
                id: toolChevron
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.parent.expanded ? "⌃" : "⌄"
                color: root.muted
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.parent.expanded = !parent.parent.parent.expanded
              }
            }
            TextEdit {
              width: parent.width
              height: visible ? implicitHeight + 22 : 0
              leftPadding: 13
              rightPadding: 13
              topPadding: 8
              bottomPadding: 14
              visible: parent.parent.expanded
              readOnly: true
              selectByMouse: true
              text: String(messageRow.modelData.content || "")
              color: root.foreground
              selectionColor: "#396b5f"
              selectedTextColor: "white"
              wrapMode: TextEdit.WrapAnywhere
              font.family: "monospace"
              font.pixelSize: 12
            }
          }
        }
      }

      Component {
        id: reasoningMessage
        Rectangle {
          property bool expanded: false
          implicitHeight: reasoningColumn.implicitHeight + 2
          radius: 11
          color: "#1b1b1b"
          border.color: root.border
          opacity: 0.86
          Column {
            id: reasoningColumn
            width: parent.width
            Rectangle {
              width: parent.width
              height: 40
              color: "transparent"
              Label {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                text: "Reasoning"
                color: root.muted
                font.pixelSize: 12
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.parent.expanded = !parent.parent.parent.expanded
              }
            }
            MarkdownMessage {
              width: parent.width - 26
              anchors.horizontalCenter: parent.horizontalCenter
              visible: parent.parent.expanded
              implicitHeight: visible ? childrenRect.height + 14 : 0
              renderer: root.mathRenderer
              content: String(messageRow.modelData.content || "")
              foreground: root.muted
            }
          }
        }
      }

      Component {
        id: errorMessage
        Rectangle {
          implicitHeight: errorText.implicitHeight + 22
          radius: 10
          color: "#3d2222"
          border.color: "#7f3939"
          Label {
            id: errorText
            anchors.fill: parent
            anchors.margins: 11
            text: String(messageRow.modelData.content || "")
            color: root.foreground
            wrapMode: Text.Wrap
          }
        }
      }
    }

    footer: Item {
      width: list.width
      height: root.busy ? 34 : 0
      Row {
        visible: root.busy
        spacing: 5
        Repeater {
          model: 3
          Rectangle {
            required property int index
            width: 6
            height: 6
            radius: 3
            color: root.muted
            opacity: pulse.running ? 0.35 + index * 0.2 : 1
          }
        }
      }
    }

    onContentHeightChanged: if (root.busy) scrollToEnd.restart()
  }

  Column {
    anchors.centerIn: parent
    visible: root.messages.length === 0 && !root.busy
    spacing: 10
    Label {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "✦"
      color: root.foreground
      font.pixelSize: 34
    }
    Label {
      text: "What are we building?"
      color: root.foreground
      font.pixelSize: 24
      font.weight: Font.DemiBold
    }
    Label {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Markdown, code, and LaTeX math render locally."
      color: root.muted
      font.pixelSize: 13
    }
  }

  Timer {
    id: scrollToEnd
    interval: 20
    repeat: false
    onTriggered: list.positionViewAtEnd()
  }

  SequentialAnimation {
    id: pulse
    running: root.busy
    loops: Animation.Infinite
    PauseAnimation { duration: 450 }
  }
}
