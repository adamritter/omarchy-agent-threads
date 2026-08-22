# Codex Threads for Omarchy

An Omarchy Shell bar widget for browsing, opening, organizing, and monitoring
local or remote coding-agent sessions from one keyboard-friendly sidebar.

## Features

- Local Codex thread and project browser with search and active-thread status.
- Optional Claude Code and OpenCode session providers.
- Remote Codex hosts over SSH or a WebSocket App Server connection.
- Thread, project, and remote pinning.
- Model, reasoning-effort, and OpenCode agent selection.
- Persistent provider, model, effort, folder, and sidebar state.

## Requirements

- A current Omarchy release with the Shell plugin system.
- Codex CLI available as `codex`.
- Node.js 22 or newer, `jq`, `inotifywait`, `hyprctl`, and standard procps tools.
- `ssh` for SSH remotes and `curl` plus `ss` for OpenCode integration.
- Claude Code and OpenCode are optional. Their providers stay inactive unless
  selected.

## Installation

After this directory is published as a Git repository:

```bash
omarchy plugin add <git-repository-url> --enable
```

For local development, place the repository at
`~/.config/omarchy/plugins/adam.codex-threads`, then run:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/adam.codex-threads
omarchy-shell shell rescanPlugins
omarchy plugin enable adam.codex-threads --section left
```

## Controls

| Key | Action |
| --- | --- |
| `j` / `k`, arrows | Move selection |
| `h` / `l`, left/right | Collapse or expand |
| `Enter` / `o` | Open a thread or toggle a group |
| `n` | Create a thread in the selected directory |
| `p` | Pin or unpin the selected item |
| `P` | Select provider |
| `y` | Archive the selected thread |
| `/` | Search |
| `R` | Add an SSH or App Server remote |
| `?` | Help |
| `Esc` | Close the current overlay or release focus |

Thread rows also provide direct pin and overflow buttons. Project and remote
headers provide pin and new-thread buttons.

## Remote hosts

Press `R` or use the two-arrow header icon. Existing aliases from
`~/.ssh/config` can be enabled directly. SSH uses `BatchMode=yes`, so a working
key-based login is required.

For App Server remotes, use `wss://` on an untrusted network. The plugin refuses
to send a bearer token over a non-local plain `ws://` connection. Store tokens
in a separate file and enter only its path.

Per-user remote configuration is stored at:

```text
$XDG_STATE_HOME/omarchy/codex-thread-remotes.json
```

The default is `~/.local/state/omarchy/codex-thread-remotes.json`. A
plugin-local `remote.json` is intentionally ignored and never published.

Other UI state is stored in `~/.local/state/omarchy/codex-threads.json`.

## Privacy and security

Omarchy Shell plugins run unsandboxed with the permissions of the current user.
This plugin reads local Codex session metadata and process information. If the
optional providers are selected, it also reads Claude transcript metadata or
queries a local OpenCode server. The remote picker reads host aliases from
`~/.ssh/config` but does not copy SSH keys.

Review the source before enabling it, especially the scripts under `bin/`.

## Development

Run the static checks with:

```bash
./scripts/check-static
```

Then restart the live shell and inspect the plugin status:

```bash
omarchy restart shell
omarchy-shell adam.codex-threads status
```

The integration currently targets the Codex App Server protocol shipped with
recent Codex CLI releases. Pinning, model discovery, rate limits, and remote
thread operations should be tested when changing the supported Codex version.

## License

MIT — see [LICENSE](LICENSE).
