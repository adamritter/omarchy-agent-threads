.pragma library

function text(value) {
  return String(value === undefined || value === null ? "" : value)
}

function parseJson(value) {
  var parsed = ({})
  try {
    parsed = JSON.parse(text(value) || "{}")
  } catch (error) {
    parsed = ({})
  }
  return normalize(parsed)
}

function normalize(value) {
  var source = value && typeof value === "object" ? value : ({})
  return {
    explicit: source.explicit === true,
    threadId: text(source.threadId),
    remote: text(source.remote),
    remoteAuthTokenEnv: text(source.remoteAuthTokenEnv),
    model: text(source.model),
    effort: text(source.effort),
    serviceTier: text(source.serviceTier),
    approvalPolicy: text(source.approvalPolicy),
    approvalsReviewer: text(source.approvalsReviewer) || "user",
    sandbox: text(source.sandbox),
    cwd: text(source.cwd),
    prompt: text(source.prompt),
    configOverrides: Array.isArray(source.configOverrides)
      ? source.configOverrides.map(function(entry) { return text(entry) }) : []
  }
}

function sandboxPolicy(mode) {
  if (mode === "read-only") return { type: "readOnly" }
  if (mode === "workspace-write") return { type: "workspaceWrite" }
  if (mode === "danger-full-access") return { type: "dangerFullAccess" }
  return null
}

function approvalLabel(policy, reviewer) {
  if (reviewer === "auto_review") return "Auto review"
  if (policy === "never") return "Never ask"
  if (policy === "untrusted") return "Untrusted only"
  return "Ask as needed"
}

function connectionLabel(remote) {
  var value = text(remote)
  return value === "" ? "Local" : value
}

function transportCommand(remote, tokenEnv, transportGuard, websocketHelper,
    configOverrides) {
  var address = text(remote)
  var command
  if (address.indexOf("ws://") === 0 || address.indexOf("wss://") === 0)
    command = [text(websocketHelper), address, text(tokenEnv), ""]
  else if (address.indexOf("unix://") === 0) {
    var socketPath = decodeURIComponent(address.slice("unix://".length))
    var proxy = ["codex", "app-server", "proxy"]
    command = socketPath === "" ? proxy : proxy.concat(["--sock", socketPath])
  } else {
    command = ["codex", "app-server"]
    var overrides = Array.isArray(configOverrides) ? configOverrides : []
    for (var i = 0; i < overrides.length; i++)
      command = command.concat(["-c", text(overrides[i])])
  }
  return [text(transportGuard), "--"].concat(command)
}

function threadParams(base, options) {
  var params = base && typeof base === "object" ? base : ({})
  var value = normalize(options)
  if (value.cwd !== "") params.cwd = value.cwd
  if (value.model !== "") params.model = value.model
  if (value.approvalPolicy !== "") params.approvalPolicy = value.approvalPolicy
  params.approvalsReviewer = value.approvalsReviewer || "user"
  if (value.sandbox !== "") params.sandbox = value.sandbox
  if (value.serviceTier !== "") params.serviceTier = value.serviceTier
  return params
}

function turnParams(base, options) {
  var params = base && typeof base === "object" ? base : ({})
  var value = normalize(options)
  if (value.cwd !== "") params.cwd = value.cwd
  if (value.model !== "") params.model = value.model
  if (value.effort !== "") params.effort = value.effort
  if (value.approvalPolicy !== "") params.approvalPolicy = value.approvalPolicy
  params.approvalsReviewer = value.approvalsReviewer || "user"
  var policy = sandboxPolicy(value.sandbox)
  if (policy) params.sandboxPolicy = policy
  if (value.serviceTier !== "") params.serviceTier = value.serviceTier
  return params
}
