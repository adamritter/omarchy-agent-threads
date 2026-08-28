#!/usr/bin/env bash

# Shared validation for short-lived launch-status storage.

agent_threads_runtime_error() {
  printf 'Agent Threads runtime state: %s\n' "$1" >&2
  return 2
}

agent_threads_private_directory() {
  local directory="$1"
  local label="$2"
  local owner mode

  [[ "$directory" == /* ]] \
    || { agent_threads_runtime_error "$label path must be absolute"; return 2; }
  [[ ! -L "$directory" ]] \
    || { agent_threads_runtime_error "$label must not be a symbolic link"; return 2; }
  [[ -d "$directory" ]] \
    || { agent_threads_runtime_error "$label is not a directory"; return 2; }
  read -r owner mode < <(stat -c '%u %a' -- "$directory" 2>/dev/null) \
    || { agent_threads_runtime_error "could not inspect $label"; return 2; }
  [[ "$owner" == "$EUID" ]] \
    || { agent_threads_runtime_error "$label is not owned by the current user"; return 2; }
  [[ "$mode" == "700" ]] \
    || { agent_threads_runtime_error "$label must have mode 0700"; return 2; }
}

agent_threads_runtime_root_init() {
  local runtime_root="${XDG_RUNTIME_DIR:-}"

  [[ -n "$runtime_root" ]] \
    || { agent_threads_runtime_error 'XDG_RUNTIME_DIR is not set'; return 2; }
  agent_threads_private_directory "$runtime_root" 'XDG_RUNTIME_DIR' || return
  AGENT_THREADS_RUNTIME_ROOT="$runtime_root"
  export AGENT_THREADS_RUNTIME_ROOT
}

agent_threads_runtime_state_init() {
  local state_dir

  agent_threads_runtime_root_init || return
  state_dir="${AGENT_THREADS_RUNTIME_ROOT}/omarchy-codex-threads-${UID}"
  if [[ ! -e "$state_dir" && ! -L "$state_dir" ]]; then
    if ! (umask 077; mkdir -m 700 -- "$state_dir") 2>/dev/null; then
      [[ -e "$state_dir" || -L "$state_dir" ]] \
        || { agent_threads_runtime_error 'could not create the state directory'; return 2; }
    fi
  fi
  agent_threads_private_directory "$state_dir" 'state directory' || return
  AGENT_THREADS_STATE_DIR="$state_dir"
  export AGENT_THREADS_STATE_DIR
}
