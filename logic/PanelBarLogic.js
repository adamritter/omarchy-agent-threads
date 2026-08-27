.pragma library

function tooltip(readyThreadCount, fullscreenSuppressed, opened, focused) {
  if (readyThreadCount > 0)
    return readyThreadCount + " agent thread"
      + (readyThreadCount === 1 ? " is" : "s are")
      + " ready · click to open the newest"
  if (fullscreenSuppressed) return "Agent Threads is hidden while fullscreen"
  if (!opened) return "Open Codex thread sidebar"
  return focused
    ? "Codex thread sidebar · focused · click to close"
    : "Codex thread sidebar · click to close"
}
