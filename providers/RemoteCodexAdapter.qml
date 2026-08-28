// Purpose: Implements the Remote Codex Adapter provider integration boundary.
import QtQuick

RemoteProviderAdapter {
  providerType: "codex"
  label: "Codex"
  commandProperty: "codexCommand"
  defaultCommand: "codex"
  forceSsh: false
}
