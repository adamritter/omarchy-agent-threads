# Agent Threads for Omarchy

A keyboard-first Omarchy Shell sidebar for browsing, opening, organizing, and
monitoring local and remote coding-agent sessions.

![Agent Threads preview](agent-threads-preview-v0.1.0.png)

## Highlights

- Browse Codex, Claude Code, and OpenCode sessions in one project-grouped list.
- Show Codex usage windows and Claude subscription `5h` / `7d` usage in the
  footer when the provider exposes them.
- Open an existing session or focus its already-running terminal window.
- Create a new thread from the current project, remote, or selected thread with
  the global `n` shortcut or a visible `+` button.
- Create a project with `N` by choosing or creating a local or SSH directory.
- See live session state and a distinct highlight for the active thread.
- Temporarily hide while the active window is in true fullscreen mode.
- Search threads and projects without leaving the keyboard.
- Pin threads, projects, and remotes; pinned items stay at the front.
- Collapse projects and remotes, with their state restored after a Shell
  restart.
- Keep large groups compact with a ten-thread preview and an explicit
  **Show all** row. Show-all expansion is intentionally reset on restart.
- Choose provider-specific model, reasoning effort, and agent values. Selections
  are remembered per provider. Press `Super+Ctrl+E` to cycle reasoning effort
  in Agent Threads or Agent Chat; during thread rename it keeps opening Omarchy's
  emoji picker.
- Toggle Codex Fast responses from the sidebar footer. The persisted setting is
  forwarded to newly launched local, SSH, and App Server Codex sessions,
  including Agent Chat. Click the lightning icon or press `Super+Ctrl+F`.
- Pin, open, create beside, move between local Codex projects, or archive a
  thread from its overflow/right-click menu.
- Use direct thread, project, and remote pin buttons without opening a menu.
- Test, edit, or disable a configured remote from its small overflow/right-click
  menu.

## Providers

| Provider | Local sessions | Remote sessions | Selection support | Usage footer |
| --- | --- | --- | --- | --- |
| Codex | Yes | SSH or App Server | Model and reasoning effort | `5h` / `7d` windows |
| Claude Code | Yes | SSH | Model and reasoning effort when available | `5h` / `7d` when exposed |
| OpenCode | Yes | SSH | Model, variant, and agent | Not exposed by the OpenCode API |

Optional providers remain inactive until selected, so they do not continuously
poll or start their helper server in the background.

### AgentProvider library

`providers/AgentProviderLibrary.qml` is the reusable frontend boundary. It owns
the existing Codex App Server client, local Claude/OpenCode providers, and all
remote transports, then exposes them as normalized hosts. Provider and
connection are separate fields:

```text
providerType:   codex | claude | opencode
connectionType: local | ssh | app-server
```

`allHosts` contains every local and remote host. Each host has normalized
`threads`, `projects`, `models`, `agents`, and `capabilities` fields. Frontends
route operations through `refreshHost`, `openThread`, `createThread`,
`renameThread`, `archiveThread`, and `toggleThreadPin` instead of selecting a
provider-specific implementation. `supplementalHosts` omits the local Codex
host and exists for the sidebar's legacy view model.

The library still uses the existing provider-native transports: local stdio,
SSH, direct Codex App Server WebSocket, and the OpenCode headless API. It does
not proxy or translate their wire protocols into a new daemon.

### Standalone Agent Chat

The plugin also includes a separate, single-conversation QuickShell application
with a regular desktop window. It is intentionally a Codex GUI rather than a
second thread browser, so it has no host or thread-list sidebar:

```bash
~/.config/omarchy/plugins/agent-threads/bin/omarchy-agent-chat
~/.config/omarchy/plugins/agent-threads/bin/omarchy-agent-chat \
  -C ~/src/project -m gpt-5.6-terra --effort high --fast --approve-for-me
~/.config/omarchy/plugins/agent-threads/bin/omarchy-agent-chat \
  resume THREAD_ID "Continue the task"
~/.config/omarchy/plugins/agent-threads/bin/omarchy-agent-chat \
  --remote wss://agent.example.test \
  --remote-auth-token-env CODEX_REMOTE_TOKEN resume THREAD_ID
```

The launcher accepts a thread ID, local or remote App Server endpoint, model,
reasoning effort, Fast service tier, approval policy, sandbox mode, working
directory, and repeatable Codex `-c KEY=VALUE` overrides. Run it with `--help`
for the complete list. Calling the launcher again focuses the existing window;
explicit options are handed to that process over QuickShell IPC, so a second
window is not created.

For local Codex threads, Agent Threads can also use Agent Chat as its default
thread frontend. Click the terminal/Agent Chat button in the sidebar header to
switch. The setting is persisted, remains off by default, and does not change
how remote Codex, Claude, or OpenCode threads are opened.

Local Codex conversations open inline through the Codex App Server, with full
history loading, streaming assistant and tool output, Stop, approval prompts,
and runtime model/reasoning-effort/Fast/approval controls. Remote `ws://`,
`wss://`, and `unix://` App Server transports reuse the plugin's existing
remoting helpers.

The conversation transcript uses one local-only Qt WebEngine view. Markdown is
sanitized before insertion, and MathJax CHTML renders inline `$...$` /
`\\(...\\)` math and display `$$...$$` / `\\[...\\]` math with real selectable
webfont glyphs instead of images. Scripts, fonts, and the Marked parser are
vendored under `app/web/vendor/`, so rendering does not require network access.
The view blocks remote requests, persistent storage, plugins, and popup windows.
App Server request and response lines are checked as raw bytes before QML sees
them: stdin and stdout are limited to 16 MiB per line, stderr to 256 KiB, and a
transport that exceeds a limit is terminated without forwarding the oversized
line. Agent Chat retains at most 400 recent messages, 8 MiB of message text,
and 32 file-change parts per aggregate entry.

Qt WebEngine must initialize before QuickShell creates its application object,
while QuickShell currently creates that object with an empty argument list. The
launcher builds a small user-cache compatibility shim from
`native/webengine-preload.cpp` and loads it only into the Agent Chat process. It
does not replace or modify the system QuickShell binary, and removes itself from
the environment before provider child processes start.

When OpenCode is selected, the plugin starts a localhost-only headless server
for session discovery and creates each new session before opening its TUI. This
makes window mapping immediate and reliable even before the first prompt. Model,
variant, and primary-agent choices are passed through OpenCode's native CLI
flags, while live status is read from the TUI's per-session server.

Local Claude discovery refreshes every five seconds and uses fixed directory,
file-count, per-file, and 32 MiB total read limits so a large transcript history
cannot block the long-running Shell process.

## Requirements

- A current Omarchy release with the Shell plugin system.
- Codex CLI available as `codex`.
- Node.js 22 or newer, `jq`, `inotifywait`, `hyprctl`, and standard procps tools.
- Qt 6 WebEngine with development headers, `pkg-config`, and a C++ compiler for
  the standalone Agent Chat compatibility shim.
- `ssh` for SSH remotes and `curl` plus `ss` for OpenCode integration.
- Claude Code and OpenCode CLIs are optional and only required for their
  respective providers.

## Installation

Install and enable the plugin from its public Git repository:

```bash
omarchy plugin add https://github.com/adamritter/omarchy-agent-threads.git --enable
```

For local development, place the repository at
`~/.config/omarchy/plugins/adam.codex-threads`, then run:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/adam.codex-threads
omarchy-shell shell rescanPlugins
omarchy plugin enable adam.codex-threads --section left
```

## Recommended shortcuts

Add these bindings to `~/.config/hypr/bindings.lua`:

```lua
-- Open Agent Threads, follow the active session, and give the sidebar keyboard focus.
o.bind("SUPER + A", "Focus Agent Threads", "omarchy-shell -q adam.codex-threads focusSidebar")

-- SUPER + S defaults to the scratchpad; SUPER + grave already opens scratchpad/Quakes.
hl.unbind("SUPER + S")
o.bind("SUPER + S", "Toggle Agent Threads", "omarchy-shell -q adam.codex-threads toggle")

-- Select only thread rows, skipping project/remote headers and wrapping at the ends.
o.bind("SUPER + CTRL + DOWN", "Next agent thread", "omarchy-shell -q adam.codex-threads nextThread")
o.bind("SUPER + CTRL + UP", "Previous agent thread", "omarchy-shell -q adam.codex-threads previousThread")
```

`Super+A` is the fast keyboard-navigation entry point. `Super+S` only opens or
closes the sidebar and does not force keyboard focus. Rebinding `Super+S`
replaces its default scratchpad action. Current Omarchy releases already expose
the scratchpad/Quakes with `Super+grave`, so that function remains available.
The `nextThread` and `previousThread` IPC actions switch from the active thread
to the next or previous visible thread. They also update the sidebar selection,
and skip project, remote, and “show more” rows. `nextThread` wraps from the last
thread to the first; `previousThread` stops at the first thread.

## Controls

| Key | Action |
| --- | --- |
| `[count]j` / `[count]k`, arrows | Move selection, optionally by a count |
| `h` / `l`, left/right | Collapse or expand |
| `Enter` / `o` | Open a thread or toggle a group |
| `t` / `Shift+Enter` | Open a terminal in the selected local or SSH directory |
| `/` | Search |
| `P` | Select provider |
| `Tab` / `Shift+Tab` | Switch between sidebar panels |
| `n` | Create a thread in the selected directory |
| `N` | Create a project from a local or remote directory |
| `p` | Pin or unpin the selected item |
| `r` | Rename the selected thread |
| `y` | Archive the selected thread |
| `R` | Add an SSH or App Server remote |
| `s` | Toggle this-workspace or global sidebar scope |
| `Ctrl+U` / `Ctrl+D` | Move half a page |
| `Ctrl+B` / `Ctrl+F`, Page Up / Page Down | Move a full page |
| `[count]g` / `G`, Home / End | Jump to a numbered row or the last row |
| `[count]f<char>` / `[count]F<char>` | Find next/previous thread by name initial |
| `?` | Help |
| `Esc` / `q` | Close the current overlay or release focus |

Thread rows also provide direct pin and overflow buttons. Project and remote
headers provide pin and new-thread buttons. The project picker supports keyboard
navigation, direct paths, new folders, and remote browsing over SSH. Direct App
Server connections accept a manually entered remote path because they do not
provide filesystem access. A strong accent marks the active thread; the lighter
highlight is the keyboard selection or pointer hover.

## Remote hosts

Press `R` or use the two-arrow header icon. The selected provider determines
whether a Codex, Claude Code, or OpenCode remote is added. Existing aliases from
`~/.ssh/config` can be enabled with one click. SSH uses `BatchMode=yes`, so a
working key-based login is required; the SSH config continues to control keys,
ports, jump hosts, and other connection options.

Remote Codex supports SSH and direct App Server connections. Remote Claude uses
SSH and installs a small per-user status bridge on the remote host so active
sessions can be tracked. If Claude Code is missing, the remote row offers a
**INSTALL** button that installs Anthropic's official npm package over SSH and
then retests the host automatically. If Claude is installed but signed out, a
**LOGIN** button opens `claude auth login` on that machine in a terminal; the
OAuth page opens automatically in the local browser, and the remote updates
automatically after sign-in. Remote OpenCode uses SSH and maintains a localhost-only
headless OpenCode API on the remote machine for discovery, status, capabilities,
session creation, and archive operations. Codex and OpenCode must already be
installed on the remote machine, and every provider must be authenticated;
remote Claude requires npm, while remote OpenCode additionally requires Node.js
and curl.

Use the `…` button on a remote row (or right-click the row) for the compact
**Test connection**, **Edit connection**, and **Disable remote** menu. In the
SSH host picker, clicking a host simply enables or disables it. Disabling a
remote only deletes it from the local Agent Threads configuration; it does not
remove files or sessions from the remote machine.

For App Server remotes, use `wss://` on an untrusted network. The plugin refuses
to send a bearer token over a non-local plain `ws://` connection. Store tokens
in a separate file and enter only its path.

Per-user remote configuration is stored at:

```text
$XDG_STATE_HOME/omarchy/codex-thread-remotes.json
```

The default is `~/.local/state/omarchy/codex-thread-remotes.json`. A
plugin-local `remote.json` is intentionally ignored and never published.
The remote configuration is limited to 256 KiB, must be a regular file, and
cannot be a symbolic link.

Other UI state is stored in `~/.local/state/omarchy/codex-threads.json`.

This state includes provider selections, model/effort/agent choices, pinned
sections, and collapsed projects/remotes. Runtime window-address files are
temporary and are stored below `$XDG_RUNTIME_DIR`.

Provider thread and project snapshots are cached at
`$XDG_RUNTIME_DIR/omarchy-agent-threads-provider-snapshot.json`. This
session-scoped cache lets the sidebar render immediately across QML reloads;
providers still reconnect and refresh the cached data in the background.

## Privacy and security

Omarchy Shell plugins run unsandboxed with the permissions of the current user.
This plugin reads local Codex session metadata and process information. If the
optional providers are selected, it also reads Claude transcript metadata or
queries a local OpenCode server. The remote picker reads host aliases from
`~/.ssh/config` but does not copy SSH keys. Project directory browsing sends the
bundled directory-listing helper over an existing SSH connection and does not
install persistent files on the remote host.

Review the source before enabling it, especially the scripts under `bin/`.

## Removal

Disable and remove the plugin with:

```bash
omarchy plugin remove adam.codex-threads
```

Removing the plugin does not delete its local state files, remote connection
configuration, or helper files previously installed on remote hosts. This
preserves session organization if the plugin is installed again. These files
contain no copied SSH keys or provider access tokens.

## Development

Before publishing a commit or tag, complete the security and verification steps
in [RELEASE.md](RELEASE.md). The checklist requires a repository-wide review of
sibling implementations whenever a security pattern is found.

Keep logic that does not require rendered controls, Quickshell services, or
Wayland state in `logic/`. The QML views and services call these modules, and
Qt Quick tests exercise them without loading the live plugin. Existing pure
QML models and controllers should be tested the same way.

The original QML ownership structure is intentional. `Panel.qml` directly owns
the bar button, layer-shell windows, focus lifecycle, overlays, and top-level
coordination. `ui/CodexThreadList.qml` owns list scrolling and row rendering,
while `ui/SidebarController.qml` owns list actions. Do not move layer-shell
windows or overlay controls behind forwarded host properties without a live
reload test; doing so can leave stale windows mapped or evaluate visibility
bindings against a detached panel.

Deterministic transformations can still live in `logic/` and be tested without
loading the Shell. Prefer those low-risk extractions over restructuring the QML
window ownership tree.

Run one focused QML unit test while iterating:

```bash
./scripts/test-unit tests/tst_projectpickerlogic.qml
```

Run every QML unit test with:

```bash
./scripts/test-unit
```

The unit-test script prefers Qt 6's `qmltestrunner`, matching Quickshell, and
uses Qt's offscreen backend so pure logic/model tests do not wait for desktop
focus. Run these commands outside restricted sandboxes; otherwise Qt can abort
and report a misleading coredump. Set `QMLTESTRUNNER` only when an alternate
Qt 6 runner is required, or `QML_TEST_PLATFORM=wayland` for a test that genuinely
needs a visible window.

Run the helper and provider integration tests with:

```bash
./scripts/test-integration
```

Individual integration tests can also be selected:

```bash
./scripts/test-integration tests/directory-picker.test
```

Before changing `Panel.qml` ownership, layer-shell windows, overlays, or list
wiring, run the component render contract directly:

```bash
./scripts/test-integration tests/panel-render.test
```

The default contract checks the real panel ownership tree statically and runs
pure QML model, controller, and key-routing tests with fake projects and
threads. It does not instantiate layer-shell windows, read live session data,
start provider processes, change focus, or touch the running plugin.

An explicit release smoke test can additionally verify real layer-shell mapping
and cleanup with `PANEL_TEST_LIVE_WAYLAND=1 tests/panel-render.test`. This is not
part of `scripts/test` and must not be run during an active desktop session.

Run static validation with:

```bash
./scripts/check-static
```

Before handing off a change, run the complete suite outside the sandbox:

```bash
./scripts/test
```

Plugin files under `~/.config/omarchy/plugins/` hot-reload on save through
[Omarchy PR #7771](https://github.com/basecamp/omarchy/pull/7771). Do not restart
the shell for ordinary QML, JavaScript, helper, or documentation changes. If
the automatic reload does not apply a change, reload the complete QML graph
in-process and verify that a new panel generation is active:

```bash
./scripts/reload-plugin
```

A full `omarchy restart shell` is a last-resort lifecycle check. The reload
script reports validation, IPC, or readiness failures without restarting. Use a restart only
when testing process startup/shutdown, recovering from a stuck socket or child
process, or confirming a problem that still exists after an in-process reload. Qt
also caches a QML directory's file listing; adding or renaming component files
inside a directory that the running Shell has already imported can therefore
require one restart. Editing existing component files does not. One final
restart may be used for release-level integration testing, but it should not be
part of the ordinary edit-test loop.

The integration currently targets the Codex App Server protocol shipped with
recent Codex CLI releases. Pinning, model discovery, rate limits, and remote
thread operations should be tested when changing the supported Codex version.

## License

MIT — see [LICENSE](LICENSE).
