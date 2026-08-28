import QtQuick
import Quickshell
import Quickshell.Wayland
import "../logic/GlobalActionLogic.js" as GlobalActionLogic

QtObject {
  required property var panel

  function route(action) {
    var toplevel = ToplevelManager.activeToplevel
    var destination = GlobalActionLogic.route(action, {
      sidebarFocused: panel.sidebarFocused,
      activeProvider: panel.activeProvider,
      renameOpen: panel.session.renameOpen,
      activeToplevel: {
        appId: toplevel ? String(toplevel.appId || "") : "",
        title: toplevel ? String(toplevel.title || "") : ""
      }
    })
    if (destination === "sidebar-fast") {
      panel.service.settings.toggleFastMode()
      return panel.service.settings.fastMode ? "on" : "off"
    }
    if (destination === "sidebar-effort")
      return panel.providerActions.cycleEffort()
    if (destination === "agent-chat-fast" || destination === "agent-chat-effort") {
      Quickshell.execDetached([
        "quickshell", "ipc", "--path", panel.environment.agentChatPath,
        "call", "agentChat",
        destination === "agent-chat-fast" ? "fast" : "effort",
        destination === "agent-chat-fast" ? "toggle" : "cycle"
      ])
      return "agent-chat"
    }
    if (destination === "fullscreen") {
      Quickshell.execDetached(["omarchy-hyprland-window-tiled-fullscreen-toggle"])
      return "fullscreen"
    }
    if (destination === "emoji") {
      Quickshell.execDetached([
        "omarchy-shell", "shell", "toggle", "omarchy.emojis"
      ])
      return "emoji"
    }
    return "invalid"
  }
}
