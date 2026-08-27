#!/usr/bin/env bash

# Compatibility for detached QML instances retained across an in-process
# plugin reload. Current QML never calls this positional boundary.

codex_legacy_prepare_remote_auth() {
  [[ -n "$remote_auth_file" ]] || return 0
  if [[ "$remote_auth_file" == "~/"* ]]; then
    remote_auth_file="${HOME}/${remote_auth_file#~/}"
  fi
  [[ -r "$remote_auth_file" ]] || {
    echo "Codex remote token file is not readable" >&2
    exit 2
  }
  [[ -n "$remote_auth_env" ]] || remote_auth_env="CODEX_REMOTE_TOKEN"
  [[ "$remote_auth_env" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
    echo "Invalid Codex remote token environment variable" >&2
    exit 2
  }
  remote_token_bytes="$(wc -c <"$remote_auth_file")"
  [[ "$remote_token_bytes" =~ ^[0-9]+$ && "$remote_token_bytes" -le 65536 ]] || {
    echo "Codex remote token file exceeded the 64 KiB limit" >&2
    exit 2
  }
  remote_token="$(<"$remote_auth_file")"
  export "${remote_auth_env}=${remote_token}"
}

codex_legacy_launch() {
  local launch_kind="$1"
  shift

  local project_cwd remote_url remote_auth_env remote_auth_file
  local thread_id="" mapping_namespace="" selected_model selected_effort
  local selected_service_tier terminal_cwd adapter_path
  local -a adapter_command codex_command

  adapter_path="${script_dir}/omarchy-codex-terminal-open"
  if [[ "$launch_kind" == "thread" ]]; then
    # The stale local QML call has eight arguments because it omitted the
    # mapping namespace. The former complete helper interface had nine.
    if (( $# == 8 )); then
      thread_id="${1:-}"
      project_cwd="${2:-${PWD}}"
      remote_url="${3:-}"
      remote_auth_env="${4:-}"
      remote_auth_file="${5:-}"
      selected_model="${6:-}"
      selected_effort="${7:-}"
      selected_service_tier="${8:-}"
    elif (( $# == 9 )); then
      thread_id="${1:-}"
      project_cwd="${2:-${PWD}}"
      remote_url="${3:-}"
      remote_auth_env="${4:-}"
      remote_auth_file="${5:-}"
      mapping_namespace="${6:-}"
      selected_model="${7:-}"
      selected_effort="${8:-}"
      selected_service_tier="${9:-}"
    else
      echo "Invalid legacy Codex thread launch arguments" >&2
      exit 2
    fi
  elif [[ "$launch_kind" == "project" && $# == 7 ]]; then
    project_cwd="${1:-}"
    remote_url="${2:-}"
    remote_auth_env="${3:-}"
    remote_auth_file="${4:-}"
    selected_model="${5:-}"
    selected_effort="${6:-}"
    selected_service_tier="${7:-}"
  else
    echo "Invalid legacy Codex project launch arguments" >&2
    exit 2
  fi

  terminal_cwd="$project_cwd"
  if [[ -n "$remote_url" ]]; then terminal_cwd="${HOME}"; fi
  adapter_command=("$adapter_path" --terminal-cwd "$terminal_cwd")
  if [[ "$launch_kind" == "thread" ]]; then
    adapter_command+=(--thread-id "$thread_id")
    [[ -z "$mapping_namespace" ]] \
      || adapter_command+=(--mapping-namespace "$mapping_namespace")
  else
    adapter_command+=(--move-to-active-workspace)
    [[ -n "$remote_url" ]] || adapter_command+=(--require-terminal-cwd)
  fi

  codex_legacy_prepare_remote_auth
  codex_command=(codex)
  if [[ -n "$remote_url" ]]; then
    codex_command+=(--remote "$remote_url")
    [[ -z "$remote_auth_env" ]] \
      || codex_command+=(--remote-auth-token-env "$remote_auth_env")
  fi
  [[ -z "$selected_model" ]] || codex_command+=(--model "$selected_model")
  [[ -z "$selected_effort" ]] \
    || codex_command+=(-c "model_reasoning_effort=\"${selected_effort}\"")
  [[ -z "$selected_service_tier" ]] \
    || codex_command+=(-c "service_tier=\"${selected_service_tier}\"")
  codex_command+=(-C "$project_cwd")
  [[ "$launch_kind" != "thread" ]] || codex_command+=(resume "$thread_id")

  exec "${adapter_command[@]}" -- "${codex_command[@]}"
}
