// Purpose: Provides reusable bounded io helpers for command-line adapters.
import fs from "node:fs"
import path from "node:path"

function byteLimitError(label, limit) {
  return new Error(`${label} exceeded the ${limit} byte limit`)
}

export function readFileLimited(filePath, limit, label = "file") {
  if (!Number.isSafeInteger(limit) || limit < 0) throw new Error("invalid byte limit")
  const flags = fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK
  const descriptor = fs.openSync(filePath, flags)
  try {
    const stat = fs.fstatSync(descriptor)
    if (!stat.isFile()) throw new Error(`${label} is not a regular file`)
    if (stat.size > limit) throw byteLimitError(label, limit)
    const buffer = Buffer.alloc(stat.size)
    let offset = 0
    while (offset < buffer.length) {
      const count = fs.readSync(descriptor, buffer, offset, buffer.length - offset, offset)
      if (count === 0) throw new Error(`${label} changed while being read`)
      offset += count
    }
    const extra = Buffer.alloc(1)
    if (fs.readSync(descriptor, extra, 0, 1, offset) !== 0)
      throw new Error(`${label} changed while being read`)
    return buffer.toString("utf8")
  } finally {
    fs.closeSync(descriptor)
  }
}

export function readJsonLimited(filePath, limit, label = "JSON file", fallback) {
  try {
    return JSON.parse(readFileLimited(filePath, limit, label))
  } catch (error) {
    if (arguments.length >= 4) return fallback
    throw error
  }
}

export async function readResponseJsonLimited(response, limit, label = "HTTP response") {
  const declared = Number(response.headers.get("content-length"))
  if (Number.isFinite(declared) && declared > limit) throw byteLimitError(label, limit)
  if (!response.body) return null
  const reader = response.body.getReader()
  const chunks = []
  let bytes = 0
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      const chunk = Buffer.from(value)
      bytes += chunk.length
      if (bytes > limit) {
        await reader.cancel("response exceeded byte limit")
        throw byteLimitError(label, limit)
      }
      if (chunks.length >= 8192) {
        await reader.cancel("response exceeded chunk limit")
        throw new Error(`${label} exceeded the response chunk limit`)
      }
      chunks.push(chunk)
    }
  } finally {
    reader.releaseLock()
  }
  return JSON.parse(Buffer.concat(chunks, bytes).toString("utf8"))
}

export async function mapWithConcurrency(values, concurrency, mapper) {
  const input = Array.from(values)
  const results = new Array(input.length)
  let next = 0
  async function worker() {
    while (next < input.length) {
      const index = next++
      results[index] = await mapper(input[index], index)
    }
  }
  await Promise.all(Array.from(
    { length: Math.min(concurrency, input.length) }, () => worker()))
  return results
}

export function readDirectoryLimited(directory, limit, label = "directory") {
  const handle = fs.opendirSync(directory)
  const entries = []
  try {
    while (entries.length <= limit) {
      const entry = handle.readSync()
      if (!entry) break
      entries.push(entry)
    }
  } finally {
    handle.closeSync()
  }
  if (entries.length > limit) throw new Error(`${label} exceeded the ${limit} entry limit`)
  return entries
}

export function writePrivateJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true, mode: 0o700 })
  const temporary = `${filePath}.${process.pid}.${Date.now()}.tmp`
  try {
    fs.writeFileSync(temporary, JSON.stringify(value) + "\n", { mode: 0o600, flag: "wx" })
    fs.renameSync(temporary, filePath)
  } finally {
    try { fs.unlinkSync(temporary) } catch { /* The rename already consumed it. */ }
  }
}
