.pragma library

function cursorPoint(value) {
  var parsed
  try { parsed = JSON.parse(String(value || "")) }
  catch (error) { return { valid: false, x: -1, y: -1 } }
  var x = Number(parsed && parsed.x)
  var y = Number(parsed && parsed.y)
  if (!isFinite(x) || !isFinite(y)) return { valid: false, x: -1, y: -1 }
  return { valid: true, x: Math.round(x), y: Math.round(y) }
}
