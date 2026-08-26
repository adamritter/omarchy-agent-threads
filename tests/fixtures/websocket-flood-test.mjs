import crypto from "node:crypto"
import net from "node:net"
import { once } from "node:events"
import { spawn } from "node:child_process"

const helper = process.argv[2]
if (!helper) throw new Error("WebSocket helper path is required")

function websocketFrame(value) {
  const payload = Buffer.from(value)
  let header
  if (payload.length < 126) {
    header = Buffer.from([0x81, payload.length])
  } else if (payload.length <= 0xffff) {
    header = Buffer.alloc(4)
    header[0] = 0x81
    header[1] = 126
    header.writeUInt16BE(payload.length, 2)
  } else {
    header = Buffer.alloc(10)
    header[0] = 0x81
    header[1] = 127
    header.writeBigUInt64BE(BigInt(payload.length), 2)
  }
  return Buffer.concat([header, payload])
}

const payload = JSON.stringify({
  method: "item/agentMessage/delta",
  params: { delta: "x".repeat(65500) }
})
const frame = websocketFrame(payload)

const sockets = new Set()
const server = net.createServer(socket => {
  sockets.add(socket)
  socket.on("close", () => sockets.delete(socket))
  let request = ""
  let upgraded = false
  socket.on("data", chunk => {
    if (upgraded) return
    request += chunk.toString("utf8")
    if (!request.includes("\r\n\r\n")) return
    upgraded = true
    const key = request.match(/^Sec-WebSocket-Key:\s*(.+)\r$/mi)?.[1]?.trim()
    if (!key) {
      socket.destroy(new Error("Missing WebSocket key"))
      return
    }
    const accept = crypto.createHash("sha1")
      .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
      .digest("base64")
    socket.write([
      "HTTP/1.1 101 Switching Protocols",
      "Upgrade: websocket",
      "Connection: Upgrade",
      `Sec-WebSocket-Accept: ${accept}`,
      "\r\n"
    ].join("\r\n"))
    void (async () => {
      for (let index = 0; index < 400 && !socket.destroyed; index++) {
        if (!socket.write(frame)) await once(socket, "drain")
      }
    })().catch(() => {})
  })
})

server.listen(0, "127.0.0.1")
await once(server, "listening")
const address = server.address()
const child = spawn(helper, [`ws://127.0.0.1:${address.port}`], {
  stdio: ["pipe", "pipe", "pipe"]
})
child.stdout.pause()
let stderr = ""
child.stderr.on("data", chunk => {
  stderr = (stderr + chunk.toString("utf8")).slice(-65536)
})

let timer
const result = await Promise.race([
  once(child, "exit").then(([code, signal]) => ({ code, signal })),
  new Promise(resolve => {
    timer = setTimeout(() => resolve({ timeout: true }), 8000)
  })
])
clearTimeout(timer)
child.stdin.destroy()
if (result.timeout) child.kill("SIGKILL")
for (const socket of sockets) socket.destroy()
server.close()

if (result.timeout) throw new Error("WebSocket flood test timed out")
if (result.code !== 2)
  throw new Error(`WebSocket helper exited with ${result.code ?? result.signal}`)
if (!stderr.includes("inbound response queue exceeded the 16 MiB limit"))
  throw new Error(`Missing inbound queue error: ${stderr.trim()}`)

process.stdout.write("WebSocket flood test passed\n")
