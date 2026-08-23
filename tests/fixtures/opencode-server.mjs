import fs from "node:fs"
import http from "node:http"

const [portFile, actionLog, projectDirectory] = process.argv.slice(2)
const session = {
  id: "ses_opencode_fixture",
  title: "Implement OpenCode support",
  projectID: "fixture-project",
  directory: projectDirectory,
  time: { created: 1787432000000, updated: 1787432060000 }
}
const provider = {
  connected: ["fixture"],
  default: { fixture: "model-default" },
  all: [{
    id: "fixture",
    name: "Fixture AI",
    models: {
      "model-default": {
        id: "model-default",
        name: "Default Model",
        variants: { low: {}, high: {} }
      },
      "model-project": {
        id: "model-project",
        name: "Project Model",
        variants: { medium: {}, high: {} }
      }
    }
  }]
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, "http://127.0.0.1")
  const scoped = url.searchParams.get("directory") === projectDirectory
  const send = (status, value) => {
    response.writeHead(status, { "content-type": "application/json" })
    response.end(JSON.stringify(value))
  }

  if (request.method === "GET" && url.pathname === "/global/health")
    return send(200, { healthy: true, version: "1.18.21-test" })
  if (request.method === "GET" && url.pathname === "/experimental/session")
    return send(200, [session])
  if (request.method === "GET" && url.pathname === "/session/status")
    return send(200, { [session.id]: { type: "busy" } })
  if (request.method === "GET" && url.pathname === "/provider")
    return send(200, provider)
  if (request.method === "GET" && url.pathname === "/config")
    return send(200, scoped
      ? { model: "fixture/model-project", variant: "high", default_agent: "review" }
      : { model: null, variant: "low", default_agent: "build" })
  if (request.method === "GET" && url.pathname === "/agent")
    return send(200, scoped
      ? [
          { name: "build", mode: "primary", description: "Build agent" },
          { name: "review", mode: "primary", description: "Review agent" }
        ]
      : [{ name: "build", mode: "primary", description: "Build agent" }])
  if (request.method === "PATCH" && url.pathname === `/session/${session.id}`) {
    let body = ""
    request.on("data", chunk => { body += chunk })
    request.on("end", () => {
      fs.appendFileSync(actionLog, `${request.method} ${url.pathname} ${body}\n`)
      const patch = JSON.parse(body || "{}")
      if (typeof patch.title === "string") session.title = patch.title
      if (patch.time && patch.time.archived)
        session.time = { ...session.time, archived: patch.time.archived }
      send(200, session)
    })
    return
  }
  send(404, { error: "not found" })
})

server.listen(0, "127.0.0.1", () => {
  fs.writeFileSync(portFile, String(server.address().port))
})
