import QtQuick
import Quickshell

QtObject {
  readonly property string homePath: Quickshell.env("HOME") || "/tmp"
  readonly property string workPath: homePath + "/Work"
  readonly property string codexScratchRoot: homePath + "/Documents/Codex/"
  readonly property string workspaceStateHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-agent-workspace-state").toString().replace(/^file:\/\//, "")
}
