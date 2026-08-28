import QtQuick
import Quickshell

QtObject {
  readonly property string homePath: Quickshell.env("HOME")
  readonly property string workPath: homePath + "/Work"
  readonly property string codexScratchRoot: homePath + "/Documents/Codex/"
  readonly property string agentChatPath: Qt.resolvedUrl(
    "../agent-chat.qml").toString().replace(/^file:\/\//, "")
}
