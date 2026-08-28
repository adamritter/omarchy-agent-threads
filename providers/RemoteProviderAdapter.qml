// Purpose: Implements the Remote Provider Adapter provider integration boundary.
import QtQuick

Item {
  required property string providerType
  required property string label
  required property string commandProperty
  required property string defaultCommand
  property bool forceSsh: true
  property int defaultPort: 0

  function connectionType(requestedType) {
    return forceSsh ? "ssh" : (requestedType === "app-server" ? "app-server" : "ssh")
  }

  function applyProviderFields(entry, existing, connectionType) {
    var result = entry
    if (providerType === "codex") delete result.providerType
    else result.providerType = providerType

    delete result.codexCommand
    delete result.claudeCommand
    delete result.opencodeCommand
    delete result.opencodePort
    if (connectionType === "ssh") {
      result[commandProperty] = String(existing && existing[commandProperty] || defaultCommand)
      if (defaultPort > 0)
        result.opencodePort = Number(existing && existing.opencodePort || defaultPort)
    }
    return result
  }
}
