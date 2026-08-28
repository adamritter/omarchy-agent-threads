.pragma library
// Purpose: Provides deterministic Panel Help decisions shared by QML adapters.

function items(threadFrontend, fastMode, effort) {
  return [
    { keys: "↑ ↓ / [count]j k", description: "Move selection" },
    { keys: "← →  /  h l", description: "Collapse or expand project" },
    { keys: "Enter / o", description: "Open thread or toggle project" },
    { keys: "t / Shift+Enter", description: "Open terminal here" },
    { keys: "/", description: "Search threads and projects" },
    { keys: "P", description: "Select provider" },
    { keys: "Tab / Shift+Tab", description: "Switch between panels" },
    { keys: "n", description: "New thread in the selected directory" },
    { keys: "p", description: "Pin or unpin selected item" },
    { keys: "r", description: "Rename selected thread" },
    { keys: "y", description: "Archive selected thread" },
    { keys: "R", description: "Add remote host (SSH or App Server)" },
    { keys: "s", description: "Toggle this-workspace or global sidebar" },
    {
      keys: "Super+Ctrl+A",
      description: threadFrontend === "agent-chat"
        ? "Toggle how Codex threads open · Agent Chat is on"
        : "Toggle how Codex threads open · Agent Chat is off (terminal)"
    },
    {
      keys: "Super+Ctrl+F",
      description: fastMode
        ? "Toggle Fast responses · Fast is on"
        : "Toggle Fast responses · Fast is off"
    },
    {
      keys: "Super+Ctrl+E",
      description: "Cycle reasoning effort · " + (effort || "default")
    },
    { keys: "Ctrl+U / Ctrl+D", description: "Move half a page" },
    { keys: "Ctrl+B / Ctrl+F", description: "Move a full page" },
    { keys: "PgUp / PgDn", description: "Move a full page" },
    { keys: "[count]g / G", description: "Go to numbered or last row" },
    { keys: "Home / End", description: "Go to first or last row" },
    { keys: "[count]f… / F…", description: "Find thread by name initial" },
    { keys: "?", description: "Open or close help" },
    { keys: "Esc / q", description: "Close help or release focus" }
  ]
}
