import QtQuick
import QtTest
import "../logic/GlobalActionLogic.js" as GlobalActionLogic

TestCase {
  name: "GlobalActionLogic"

  function route(action, overrides) {
    var context = {
      sidebarFocused: false,
      activeProvider: "codex",
      renameOpen: false,
      activeToplevel: { appId: "fixture", title: "Fixture" }
    }
    var source = overrides || ({})
    for (var key in source) context[key] = source[key]
    return GlobalActionLogic.route(action, context)
  }

  function test_routesFastByFocusedSurface() {
    compare(route("fast", { sidebarFocused: true }), "sidebar-fast")
    compare(route("fast", {
      sidebarFocused: true,
      activeProvider: "claude"
    }), "fullscreen")
    compare(route("fast", {
      activeToplevel: { appId: "org.omarchy.agent-chat", title: "Agent Chat" }
    }), "agent-chat-fast")
    compare(route("fast", {
      activeToplevel: { appId: "org.quickshell", title: "Agent Chat · thread" }
    }), "agent-chat-fast")
    compare(route("fast"), "fullscreen")
  }

  function test_routesEffortAndPreservesRenameFallback() {
    compare(route("effort", { sidebarFocused: true }), "sidebar-effort")
    compare(route("effort", {
      sidebarFocused: true,
      renameOpen: true,
      activeToplevel: { appId: "org.omarchy.agent-chat", title: "Agent Chat" }
    }), "emoji")
    compare(route("effort", {
      activeToplevel: { appId: "org.omarchy.agent-chat", title: "Agent Chat" }
    }), "agent-chat-effort")
    compare(route("effort"), "emoji")
    compare(route("unknown"), "invalid")
  }
}
