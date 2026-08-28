// Purpose: Implements the Remote Open Code Adapter provider integration boundary.
import QtQuick

RemoteProviderAdapter {
  providerType: "opencode"
  label: "OpenCode"
  commandProperty: "opencodeCommand"
  defaultCommand: "opencode"
  defaultPort: 43962
}
