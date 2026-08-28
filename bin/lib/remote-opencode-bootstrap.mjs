export function remoteOpenCodeBootstrap(serverURL, openCodeCommand, openCodePort, shellQuote) {
  const healthURL = shellQuote(serverURL + "/global/health")
  return `set -eu; umask 077; state_dir="$HOME/.local/state/omarchy/codex-threads"; `
    + `if [ -L "$state_dir" ]; then echo 'Unsafe OpenCode state directory' >&2; exit 70; fi; `
    + `mkdir -p "$state_dir"; chmod 700 "$state_dir"; `
    + `auth_file="$state_dir/opencode-server-password"; `
    + `if [ -L "$auth_file" ]; then echo 'Unsafe OpenCode auth file' >&2; exit 70; fi; `
    + `if [ ! -e "$auth_file" ]; then tmp=$(mktemp "$state_dir/.opencode-auth.XXXXXX"); `
    + `tr -d '-' </proc/sys/kernel/random/uuid >"$tmp"; `
    + `tr -d '-' </proc/sys/kernel/random/uuid >>"$tmp"; chmod 600 "$tmp"; `
    + `ln "$tmp" "$auth_file" 2>/dev/null || true; rm -f "$tmp"; fi; `
    + `[ -f "$auth_file" ] && [ ! -L "$auth_file" ] `
    + `&& [ "$(wc -c <"$auth_file")" -le 128 ] `
    + `|| { echo 'Invalid OpenCode auth file' >&2; exit 70; }; `
    + `IFS= read -r opencode_password <"$auth_file"; `
    + `case "$opencode_password" in ''|*[!A-Za-z0-9_-]*) `
    + `echo 'Invalid OpenCode auth secret' >&2; exit 70;; esac; `
    + `opencode_username=omarchy-agent-threads; `
    + `if ! curl -fsS --max-time 2 --user "$opencode_username:$opencode_password" `
    + `${healthURL} >/dev/null 2>&1; then `
    + `nohup env OPENCODE_SERVER_USERNAME="$opencode_username" `
    + `OPENCODE_SERVER_PASSWORD="$opencode_password" ${shellQuote(openCodeCommand)} `
    + `serve --hostname 127.0.0.1 --port ${openCodePort} </dev/null `
    + `>>"$state_dir/opencode-remote-server.log" 2>&1 & i=0; `
    + `while [ "$i" -lt 120 ]; do curl -fsS --max-time 2 `
    + `--user "$opencode_username:$opencode_password" ${healthURL} >/dev/null 2>&1 `
    + `&& break; i=$((i + 1)); sleep 0.25; done; fi; `
    + `curl -fsS --max-time 2 --user "$opencode_username:$opencode_password" `
    + `${healthURL} >/dev/null 2>&1 || { `
    + `echo 'OpenCode API did not become ready within 30 seconds' >&2; exit 70; }; `
}
