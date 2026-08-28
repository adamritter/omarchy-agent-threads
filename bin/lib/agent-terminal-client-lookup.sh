#!/usr/bin/env bash

# Process-based recovery for Claude, OpenCode, and SSH-backed terminal sessions.
# Callers set agent_lookup_kind, agent_lookup_session_id, and optionally
# agent_lookup_ssh_host and agent_lookup_proc_root before calling
# find_existing_agent_client.

agent_lookup_arguments_have_pair() {
  local framed="$1"
  local option="$2"
  local value="$3"
  [[ "$framed" == *$'\n'"${option}"$'\n'"${value}"$'\n'* ]]
}

agent_lookup_remote_command_has_pair() {
  local command_line="$1"
  local option="$2"
  local value="$3"
  [[ " ${command_line} " == *" ${option} ${value} "* ]]
}

agent_lookup_process_matches() {
  local pid="$1"
  local cmdline framed first argument port=""
  local -a arguments=()
  local index

  [[ -r "${agent_lookup_proc_root}/${pid}/cmdline" ]] || return 1
  [[ "$(stat -c %u -- "${agent_lookup_proc_root}/${pid}" 2>/dev/null || true)" == "$UID" ]] \
    || return 1
  cmdline="$(head -c 65537 -- "${agent_lookup_proc_root}/${pid}/cmdline" \
    | tr '\0' '\n')"
  (( ${#cmdline} <= 65536 )) || return 1
  [[ -n "$cmdline" ]] || return 1
  framed=$'\n'"${cmdline}"$'\n'
  mapfile -t arguments <<< "$cmdline"
  first="${arguments[0]##*/}"
  AGENT_LOOKUP_SERVER_URL=""

  case "$agent_lookup_kind" in
    local-claude)
      [[ "$first" == "claude" || "$first" == "node" ]] || return 1
      agent_lookup_arguments_have_pair "$framed" --resume "$agent_lookup_session_id" \
        || agent_lookup_arguments_have_pair \
          "$framed" --session-id "$agent_lookup_session_id" || return 1
      ;;
    local-opencode)
      agent_lookup_arguments_have_pair "$framed" --session "$agent_lookup_session_id" \
        || return 1
      agent_lookup_arguments_have_pair "$framed" --hostname 127.0.0.1 \
        || return 1
      for (( index = 0; index + 1 < ${#arguments[@]}; index++ )); do
        if [[ "${arguments[$index]}" == "--port" \
            && "${arguments[$((index + 1))]}" =~ ^[0-9]{1,5}$ ]]; then
          port="${arguments[$((index + 1))]}"
          (( 10#$port >= 1 && 10#$port <= 65535 )) || return 1
          AGENT_LOOKUP_SERVER_URL="http://127.0.0.1:${port}"
          break
        fi
      done
      [[ -n "$AGENT_LOOKUP_SERVER_URL" ]] || return 1
      ;;
    ssh-claude|ssh-opencode|ssh-codex)
      [[ "$first" == "ssh" ]] || return 1
      [[ "$framed" == *$'\n'"${agent_lookup_ssh_host}"$'\n'* ]] || return 1
      case "$agent_lookup_kind" in
        ssh-claude)
          agent_lookup_remote_command_has_pair \
            "$cmdline" --resume "$agent_lookup_session_id" \
            || agent_lookup_remote_command_has_pair \
              "$cmdline" --session-id "$agent_lookup_session_id" \
            || return 1
          ;;
        ssh-opencode)
          agent_lookup_remote_command_has_pair \
            "$cmdline" --session "$agent_lookup_session_id" \
            || return 1
          ;;
        ssh-codex)
          agent_lookup_remote_command_has_pair \
            "$cmdline" resume "$agent_lookup_session_id" \
            || return 1
          ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

agent_lookup_parent_pid() {
  local pid="$1"
  local stat_line stat_tail parent_pid

  [[ -r "${agent_lookup_proc_root}/${pid}/stat" ]] || return 1
  stat_line="$(<"${agent_lookup_proc_root}/${pid}/stat")"
  stat_tail="${stat_line##*) }"
  read -r _ parent_pid _ <<< "$stat_tail" || return 1
  [[ "$parent_pid" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$parent_pid"
}

agent_lookup_client_for_ancestry() {
  local current_pid="$1"
  local parent_pid

  while [[ "$current_pid" =~ ^[0-9]+$ ]] && (( current_pid > 1 )); do
    if [[ -n "${agent_lookup_client_by_pid[$current_pid]:-}" ]]; then
      printf '%s\n' "${agent_lookup_client_by_pid[$current_pid]}"
      return 0
    fi
    parent_pid="$(agent_lookup_parent_pid "$current_pid" || true)"
    [[ "$parent_pid" =~ ^[0-9]+$ ]] || break
    current_pid="$parent_pid"
  done
  return 1
}

agent_lookup_tmux_client() {
  local process_pid="$1"
  local process_tty pane_pid pane_tty pane_session client_pid client_session

  command -v tmux >/dev/null 2>&1 || return 1
  process_tty="$(readlink \
    "${agent_lookup_proc_root}/${process_pid}/fd/0" 2>/dev/null || true)"
  [[ "$process_tty" == /dev/pts/* ]] || return 1
  pane_session=""
  while IFS='|' read -r pane_pid pane_tty client_session; do
    if [[ "$pane_tty" == "$process_tty" && -n "$client_session" ]]; then
      pane_session="$client_session"
      break
    fi
  done < <(tmux list-panes -a -F '#{pane_pid}|#{pane_tty}|#{session_name}' \
    2>/dev/null || true)
  [[ -n "$pane_session" ]] || return 1
  while IFS='|' read -r client_pid client_session; do
    [[ "$client_session" == "$pane_session" && "$client_pid" =~ ^[0-9]+$ ]] \
      || continue
    agent_lookup_client_for_ancestry "$client_pid" && return 0
  done < <(tmux list-clients -F '#{client_pid}|#{session_name}' 2>/dev/null || true)
  return 1
}

find_existing_agent_client() {
  local client_address client_pid process_dir process_pid address
  declare -gA agent_lookup_client_by_pid=()

  agent_lookup_proc_root="${agent_lookup_proc_root:-/proc}"
  [[ "$agent_lookup_session_id" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  while IFS=$'\t' read -r client_address client_pid; do
    [[ "$client_address" =~ ^0x[0-9a-fA-F]+$ && "$client_pid" =~ ^[0-9]+$ ]] \
      || continue
    agent_lookup_client_by_pid["$client_pid"]="$client_address"
  done < <(hyprctl -j clients 2>/dev/null \
    | jq -r '.[] | [.address, .pid] | @tsv' 2>/dev/null || true)

  for process_dir in "${agent_lookup_proc_root}"/[0-9]*/cmdline; do
    [[ -r "$process_dir" ]] || continue
    process_pid="${process_dir%/cmdline}"
    process_pid="${process_pid##*/}"
    agent_lookup_process_matches "$process_pid" || continue
    if address="$(agent_lookup_client_for_ancestry "$process_pid")" \
        || address="$(agent_lookup_tmux_client "$process_pid")"; then
      printf '%s\t%s\n' "$address" "$AGENT_LOOKUP_SERVER_URL"
      return 0
    fi
  done
  return 1
}
