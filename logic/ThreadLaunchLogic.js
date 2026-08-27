.pragma library

function idleThreadLaunchState(sequence, failedThreadId, error) {
  return {
    sequence: Math.max(0, Number(sequence || 0)),
    phase: "idle",
    requestId: 0,
    targetThreadId: "",
    source: "",
    failedThreadId: String(failedThreadId || ""),
    error: String(error || "")
  }
}

function normalizedThreadLaunchState(state) {
  var source = state && typeof state === "object" ? state : ({})
  var phase = String(source.phase || "") === "launching" ? "launching" : "idle"
  return {
    sequence: Math.max(0, Number(source.sequence || 0)),
    phase: phase,
    requestId: phase === "launching" ? Math.max(0, Number(source.requestId || 0)) : 0,
    targetThreadId: phase === "launching" ? String(source.targetThreadId || "") : "",
    source: phase === "launching" ? String(source.source || "") : "",
    failedThreadId: String(source.failedThreadId || ""),
    error: String(source.error || "")
  }
}

function beginThreadLaunch(state, threadId, source) {
  var current = normalizedThreadLaunchState(state)
  var target = String(threadId || "")
  if (target === "")
    return { accepted: false, requestId: 0, state: current,
      error: "A thread is required" }
  if (current.phase === "launching")
    return { accepted: false, requestId: 0, state: current,
      error: "Wait for the current thread launch to finish" }

  var requestId = current.sequence + 1
  return {
    accepted: true,
    requestId: requestId,
    state: {
      sequence: requestId,
      phase: "launching",
      requestId: requestId,
      targetThreadId: target,
      source: String(source || "unknown"),
      failedThreadId: "",
      error: ""
    },
    error: ""
  }
}

function confirmThreadLaunch(state, requestId, threadId) {
  var current = normalizedThreadLaunchState(state)
  var wantedRequest = Number(requestId || 0)
  if (current.phase !== "launching" || current.requestId !== wantedRequest)
    return { applied: false, state: current, threadId: "" }
  var confirmed = String(threadId || current.targetThreadId)
  if (confirmed === "") return failThreadLaunch(
    current, wantedRequest, "The thread launch did not identify a thread")
  return {
    applied: true,
    state: idleThreadLaunchState(current.sequence, "", ""),
    threadId: confirmed
  }
}

function failThreadLaunch(state, requestId, message) {
  var current = normalizedThreadLaunchState(state)
  var wantedRequest = Number(requestId || 0)
  if (current.phase !== "launching" || current.requestId !== wantedRequest)
    return { applied: false, state: current, threadId: "", error: "" }
  var error = String(message || "Could not open the thread").trim()
    || "Could not open the thread"
  return {
    applied: true,
    state: idleThreadLaunchState(
      current.sequence, current.targetThreadId, error),
    threadId: current.targetThreadId,
    error: error
  }
}
