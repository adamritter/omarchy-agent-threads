//@ pragma AppId org.omarchy.agent-chat
// Purpose: Bootstraps the standalone Agent Chat window and its provider wiring.

import QtQuick
import Quickshell
import "chat/ui" as AgentChat

ShellRoot {
  AgentChat.ChatWindow {}
}
