// Purpose: Implements the Remote Provider Registry provider integration boundary.
import QtQuick

Item {
  RemoteCodexAdapter { id: codex }
  RemoteClaudeAdapter { id: claude }
  RemoteOpenCodeAdapter { id: opencode }

  function normalize(providerType) {
    var type = String(providerType || "codex").toLowerCase()
    return type === "claude" || type === "opencode" ? type : "codex"
  }

  function typeForEntry(entry) {
    var type = normalize(entry && entry.providerType)
    return type === "codex" ? "" : type
  }

  function adapter(providerType) {
    var type = normalize(providerType)
    if (type === "claude") return claude
    if (type === "opencode") return opencode
    return codex
  }

  function adapterForEntry(entry) {
    return adapter(typeForEntry(entry) || "codex")
  }
}
