new_session_id=""
if [[ "$provider_type" == "claude" ]]; then
  claude_command="$(jq -r '.claudeCommand // "claude"' <<<"$remote_json")"
  [[ "$claude_command" =~ ^[A-Za-z0-9_./-]+$ ]] || {
    echo "Invalid remote Claude command" >&2
    exit 2
  }
  remote_args=("$claude_command")
  if [[ -n "$thread_id" ]]; then
    remote_args+=(--resume "$thread_id")
  else
    IFS= read -r new_session_id < /proc/sys/kernel/random/uuid
    remote_args+=(--session-id "$new_session_id")
  fi
  [[ -z "$selected_model" ]] || remote_args+=(--model "$selected_model")
  [[ -z "$selected_effort" ]] || remote_args+=(--effort "$selected_effort")
  [[ -z "$selected_agent" ]] || remote_args+=(--agent "$selected_agent")
  helper_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  remote_hook_path='.local/lib/omarchy-codex-threads/claude-thread-hook'
  hook_payload="$(base64 -w 0 -- "${helper_dir}/omarchy-claude-thread-hook")"
  bootstrap_command="set -eu; umask 077; hook_dir=\"\$HOME/.local/lib/omarchy-codex-threads\"; if [ -L \"\$hook_dir\" ]; then echo 'Unsafe Claude hook directory' >&2; exit 70; fi; mkdir -p \"\$hook_dir\"; chmod 700 \"\$hook_dir\"; hook_tmp=\$(mktemp \"\$hook_dir/.claude-thread-hook.XXXXXX\"); trap 'rm -f \"\$hook_tmp\"' EXIT HUP INT TERM; printf %s ${hook_payload@Q} | base64 -d >\"\$hook_tmp\"; chmod 700 \"\$hook_tmp\"; mv -fT \"\$hook_tmp\" \"\$hook_dir/claude-thread-hook\"; trap - EXIT HUP INT TERM"
  if ! ssh -T -o BatchMode=yes -o ConnectTimeout=8 \
      "$ssh_host" "$bootstrap_command" </dev/null; then
    echo "Could not install the Claude status bridge on ${ssh_host}" >&2
    exit 1
  fi
  hook_command='${HOME}/.local/lib/omarchy-codex-threads/claude-thread-hook'
  hook_settings="$(jq -cn --arg command "$hook_command" '{statusLine:{
    type:"command",command:$command,refreshInterval:60
  },hooks:{
    SessionStart:[{matcher:"",hooks:[{type:"command",command:$command}]}],
    UserPromptSubmit:[{matcher:"",hooks:[{type:"command",command:$command}]}],
    Notification:[{matcher:"",hooks:[{type:"command",command:$command}]}],
    Stop:[{matcher:"",hooks:[{type:"command",command:$command}]}],
    StopFailure:[{matcher:"",hooks:[{type:"command",command:$command}]}],
    SessionEnd:[{matcher:"",hooks:[{type:"command",command:$command}]}]
  }}')"
  remote_args+=(--settings "$hook_settings")
  printf -v quoted_cwd '%q' "$remote_cwd"
  printf -v quoted_args '%q ' "${remote_args[@]}"
  remote_command="export PATH=\"\$HOME/.local/bin:\$HOME/.claude/local:\$PATH\"; cd -- ${quoted_cwd} && exec ${quoted_args}"
elif [[ "$provider_type" == "opencode" ]]; then
  opencode_command="$(jq -r '.opencodeCommand // "opencode"' <<<"$remote_json")"
  [[ "$opencode_command" =~ ^[A-Za-z0-9_./-]+$ ]] || {
    echo "Invalid remote OpenCode command" >&2
    exit 2
  }
  opencode_port="$(jq -r '.opencodePort // 43962' <<<"$remote_json")"
  [[ "$opencode_port" =~ ^[0-9]+$ ]] && (( opencode_port >= 1024 && opencode_port <= 65535 )) || {
    echo "Invalid remote OpenCode port" >&2
    exit 2
  }
  server_url="http://127.0.0.1:${opencode_port}"
  printf -v quoted_server_url '%q' "$server_url"
  printf -v quoted_opencode_command '%q' "$opencode_command"
  remote_state_dir='${HOME}/.local/state/omarchy/codex-threads'
  ensure_server="set -eu; umask 077; state_dir=\"${remote_state_dir}\"; if [ -L \"\$state_dir\" ]; then echo 'Unsafe OpenCode state directory' >&2; exit 70; fi; mkdir -p \"\$state_dir\"; chmod 700 \"\$state_dir\"; auth_file=\"\$state_dir/opencode-server-password\"; if [ -L \"\$auth_file\" ]; then echo 'Unsafe OpenCode auth file' >&2; exit 70; fi; if [ ! -e \"\$auth_file\" ]; then tmp=\$(mktemp \"\$state_dir/.opencode-auth.XXXXXX\"); tr -d '-' </proc/sys/kernel/random/uuid >\"\$tmp\"; tr -d '-' </proc/sys/kernel/random/uuid >>\"\$tmp\"; chmod 600 \"\$tmp\"; ln \"\$tmp\" \"\$auth_file\" 2>/dev/null || true; rm -f \"\$tmp\"; fi; [ -f \"\$auth_file\" ] && [ ! -L \"\$auth_file\" ] && [ \"\$(wc -c <\"\$auth_file\")\" -le 128 ] || { echo 'Invalid OpenCode auth file' >&2; exit 70; }; IFS= read -r opencode_password <\"\$auth_file\"; case \"\$opencode_password\" in ''|*[!A-Za-z0-9_-]*) echo 'Invalid OpenCode auth secret' >&2; exit 70;; esac; opencode_username=omarchy-agent-threads; if ! curl -fsS --max-time 2 --user \"\$opencode_username:\$opencode_password\" ${quoted_server_url}/global/health >/dev/null 2>&1; then nohup env OPENCODE_SERVER_USERNAME=\"\$opencode_username\" OPENCODE_SERVER_PASSWORD=\"\$opencode_password\" ${quoted_opencode_command} serve --hostname 127.0.0.1 --port ${opencode_port} </dev/null >>\"\$state_dir/opencode-remote-server.log\" 2>&1 & i=0; while [ \"\$i\" -lt 120 ]; do curl -fsS --max-time 2 --user \"\$opencode_username:\$opencode_password\" ${quoted_server_url}/global/health >/dev/null 2>&1 && break; i=\$((i + 1)); sleep 0.25; done; fi; curl -fsS --max-time 2 --user \"\$opencode_username:\$opencode_password\" ${quoted_server_url}/global/health >/dev/null 2>&1 || { echo 'OpenCode API did not become ready within 30 seconds' >&2; exit 70; }"
  if [[ -z "$thread_id" ]]; then
    encoded_cwd="$(jq -rn --arg value "$remote_cwd" '$value|@uri')"
    create_command="${ensure_server}; curl -fsS --max-time 8 --max-filesize 1048576 --user \"\$opencode_username:\$opencode_password\" -X POST ${quoted_server_url}/session?directory=${encoded_cwd} -H 'content-type: application/json' --data '{}'"
    if ! new_session="$(ssh -T -o BatchMode=yes -o ConnectTimeout=8 \
        "$ssh_host" "$create_command" </dev/null)"; then
      echo "Could not create the remote OpenCode session" >&2
      exit 1
    fi
    new_session_id="$(jq -r '.id // empty' <<<"$new_session")"
    [[ "$new_session_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
      echo "Remote OpenCode did not create a valid session" >&2
      exit 1
    }
    thread_id="$new_session_id"
  fi
  remote_args=("$opencode_command" "$remote_cwd")
  [[ -z "$selected_model" ]] || remote_args+=(--model "$selected_model")
  [[ -z "$selected_effort" ]] || remote_args+=(--variant "$selected_effort")
  [[ -z "$selected_agent" ]] || remote_args+=(--agent "$selected_agent")
  remote_args+=(--session "$thread_id")
  printf -v quoted_cwd '%q' "$remote_cwd"
  printf -v quoted_args '%q ' "${remote_args[@]}"
  port_probe='const net=require("node:net"),server=net.createServer();server.listen(0,"127.0.0.1",()=>{process.stdout.write(String(server.address().port));server.close()})'
  printf -v quoted_port_probe '%q' "$port_probe"
  remote_command="${ensure_server}; cd -- ${quoted_cwd} && opencode_tui_port=\$(node -e ${quoted_port_probe}) && exec env OPENCODE_SERVER_USERNAME=\"\$opencode_username\" OPENCODE_SERVER_PASSWORD=\"\$opencode_password\" ${quoted_args}--hostname 127.0.0.1 --port \"\$opencode_tui_port\""
else
  codex_command="$(jq -r '.codexCommand // "codex"' <<<"$remote_json")"
  [[ "$codex_command" =~ ^[A-Za-z0-9_./-]+$ ]] || {
    echo "Invalid remote Codex command" >&2
    exit 2
  }
  remote_args=("$codex_command")
  [[ -z "$selected_model" ]] || remote_args+=(--model "$selected_model")
  [[ -z "$selected_effort" ]] \
    || remote_args+=(-c "model_reasoning_effort=\"${selected_effort}\"")
  [[ -z "$selected_service_tier" ]] \
    || remote_args+=(-c "service_tier=\"${selected_service_tier}\"")
  remote_args+=(-C "$remote_cwd")
  [[ -z "$thread_id" ]] || remote_args+=(resume "$thread_id")
  printf -v remote_command '%q ' "${remote_args[@]}"
fi
