#!/usr/bin/env bash

# Shared, private diagnostics for terminal launch helpers. Callers may set
# AGENT_THREADS_LAUNCH_LOG to redirect the log, primarily for tests.

agent_threads_launch_log_init() {
  local state_home log_dir log_size rotate_path

  state_home="${XDG_STATE_HOME:-${HOME}/.local/state}"
  AGENT_THREADS_LAUNCH_LOG_PATH="${AGENT_THREADS_LAUNCH_LOG:-${state_home}/omarchy/agent-threads-launch.log}"
  log_dir="$(dirname -- "$AGENT_THREADS_LAUNCH_LOG_PATH")"

  umask 077
  if [[ -L "$AGENT_THREADS_LAUNCH_LOG_PATH" ]]; then
    AGENT_THREADS_LAUNCH_LOG_PATH=""
    return 0
  fi
  mkdir -p -m 700 -- "$log_dir" 2>/dev/null || {
    AGENT_THREADS_LAUNCH_LOG_PATH=""
    return 0
  }
  if [[ -e "$AGENT_THREADS_LAUNCH_LOG_PATH" \
      && ! -f "$AGENT_THREADS_LAUNCH_LOG_PATH" ]]; then
    AGENT_THREADS_LAUNCH_LOG_PATH=""
    return 0
  fi
  touch -- "$AGENT_THREADS_LAUNCH_LOG_PATH" 2>/dev/null || {
    AGENT_THREADS_LAUNCH_LOG_PATH=""
    return 0
  }
  chmod 600 -- "$AGENT_THREADS_LAUNCH_LOG_PATH" 2>/dev/null || true

  log_size="$(stat -c '%s' -- "$AGENT_THREADS_LAUNCH_LOG_PATH" 2>/dev/null || printf 0)"
  if [[ "$log_size" =~ ^[0-9]+$ ]] && (( log_size > 1048576 )); then
    rotate_path="${AGENT_THREADS_LAUNCH_LOG_PATH}.rotate.$$"
    if tail -c 524288 -- "$AGENT_THREADS_LAUNCH_LOG_PATH" >"$rotate_path" 2>/dev/null; then
      chmod 600 -- "$rotate_path" 2>/dev/null || true
      mv -f -- "$rotate_path" "$AGENT_THREADS_LAUNCH_LOG_PATH"
    else
      rm -f -- "$rotate_path"
    fi
  fi
  export AGENT_THREADS_LAUNCH_LOG_PATH
}

agent_threads_launch_log() {
  local component="${1:-unknown}"
  local phase="${2:-event}"
  local field
  shift 2 || true

  [[ -n "${AGENT_THREADS_LAUNCH_LOG_PATH:-}" ]] || return 0
  {
    printf '%(%Y-%m-%dT%H:%M:%S%z)T component=%q phase=%q' \
      -1 "$component" "$phase"
    for field in "$@"; do
      printf ' %q' "$field"
    done
    printf '\n'
  } >>"$AGENT_THREADS_LAUNCH_LOG_PATH" 2>/dev/null || true
}

agent_threads_launch_log_path() {
  printf '%s' "${AGENT_THREADS_LAUNCH_LOG_PATH:-unavailable}"
}
