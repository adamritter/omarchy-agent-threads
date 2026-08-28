// Purpose: Implements the Remote Claude Adapter provider integration boundary.
import QtQuick

RemoteProviderAdapter {
  providerType: "claude"
  label: "Claude"
  commandProperty: "claudeCommand"
  defaultCommand: "claude"
}
