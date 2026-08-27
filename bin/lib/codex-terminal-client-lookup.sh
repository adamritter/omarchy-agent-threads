client_exists() {
  local address="$1"
  hyprctl -j clients 2>/dev/null \
    | jq -e --arg address "$address" '.[] | select(.address == $address)' >/dev/null
}

focus_client() {
  local address="$1"
  hyprctl dispatch "hl.dsp.focus({ window = \"address:${address}\" })" >/dev/null
}

move_client_to_launch_workspace() {
  local address="$1"

  [[ "$launch_workspace" =~ ^[0-9]+$ ]] || return 0
  hyprctl dispatch movetoworkspacesilent \
    "${launch_workspace},address:${address}" >/dev/null
}

codex_process_matches_thread() {
  local pid="$1"
  local cmdline fd fd_target

  if [[ -r "${proc_root}/${pid}/cmdline" ]]; then
    cmdline="$(tr '\0' ' ' < "${proc_root}/${pid}/cmdline")"
    if [[ "$cmdline" == *"$thread_id"* \
      && ( -n "$remote_url" && "$cmdline" == *"--remote $remote_url"* \
        || -z "$remote_url" && "$cmdline" != *"--remote "* ) ]]; then
      return 0
    fi
  fi

  # A running local Codex process keeps its rollout JSONL open. This also
  # identifies sessions initially started without an explicit `resume` argv.
  if [[ -z "$remote_url" && -d "${proc_root}/${pid}/fd" ]]; then
    for fd in "${proc_root}/${pid}/fd/"*; do
      [[ -e "$fd" || -L "$fd" ]] || continue
      fd_target="$(readlink "$fd" 2>/dev/null || true)"
      if [[ "$fd_target" == *"/rollout-"*"-${thread_id}.jsonl" ]]; then
        return 0
      fi
    done
  fi

  return 1
}

client_for_process_ancestry() {
  local current_pid="$1"
  local parent_pid

  while [[ "$current_pid" =~ ^[0-9]+$ && "$current_pid" -gt 1 ]]; do
    if [[ -n "${client_by_pid[$current_pid]:-}" ]]; then
      printf '%s\n' "${client_by_pid[$current_pid]}"
      return 0
    fi
    parent_pid="$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ' || true)"
    [[ "$parent_pid" =~ ^[0-9]+$ ]] || break
    current_pid="$parent_pid"
  done
  return 1
}

tmux_target_for_process() {
  local codex_pid="$1"
  local process_tty pane_pid pane_tty pane_session pane_window pane_id

  command -v tmux >/dev/null 2>&1 || return 1
  process_tty="$(readlink "${proc_root}/${codex_pid}/fd/0" 2>/dev/null || true)"
  [[ "$process_tty" == /dev/pts/* ]] || return 1

  while IFS='|' read -r pane_pid pane_tty pane_session pane_window pane_id; do
    if [[ "$pane_tty" == "$process_tty" && -n "$pane_session" \
        && -n "$pane_window" && -n "$pane_id" ]]; then
      printf '%s|%s|%s\n' "$pane_session" "$pane_window" "$pane_id"
      return 0
    fi
  done < <(tmux list-panes -a \
    -F '#{pane_pid}|#{pane_tty}|#{session_name}|#{window_id}|#{pane_id}' \
    2>/dev/null || true)
  return 1
}

tmux_client_for_process() {
  local codex_pid="$1"
  local target pane_session client_pid client_session address

  target="$(tmux_target_for_process "$codex_pid")" || return 1
  pane_session="${target%%|*}"

  while IFS='|' read -r client_pid client_session; do
    [[ "$client_session" == "$pane_session" && "$client_pid" =~ ^[0-9]+$ ]] \
      || continue
    if address="$(client_for_process_ancestry "$client_pid")"; then
      printf '%s\n' "$address"
      return 0
    fi
  done < <(tmux list-clients -F '#{client_pid}|#{client_session}' 2>/dev/null || true)
  return 1
}

find_detached_tmux_target() {
  local codex_pid target

  [[ -n "$thread_id" ]] || return 1
  while read -r codex_pid; do
    [[ "$codex_pid" =~ ^[0-9]+$ ]] || continue
    codex_process_matches_thread "$codex_pid" || continue
    target="$(tmux_target_for_process "$codex_pid")" || continue
    printf '%s\n' "$target"
    return 0
  done < <(pgrep -x codex 2>/dev/null || true)
  return 1
}

find_existing_client() {
  local address pid codex_pid
  declare -A client_by_pid=()

  [[ -n "$thread_id" ]] || return 1
  while IFS=$'\t' read -r address pid; do
    [[ -n "$address" && "$pid" =~ ^[0-9]+$ ]] || continue
    client_by_pid["$pid"]="$address"
  done < <(hyprctl -j clients 2>/dev/null | jq -r '.[] | [.address, .pid] | @tsv')

  while read -r codex_pid; do
    [[ "$codex_pid" =~ ^[0-9]+$ ]] || continue
    codex_process_matches_thread "$codex_pid" || continue
    if address="$(client_for_process_ancestry "$codex_pid")"; then
      printf '%s\n' "$address"
      return 0
    fi
    if address="$(tmux_client_for_process "$codex_pid")"; then
      printf '%s\n' "$address"
      return 0
    fi
  done < <(pgrep -x codex 2>/dev/null || true)

  return 1
}
