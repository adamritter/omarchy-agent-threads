.pragma library

function appendCount(current, digit) {
  var value = String(current || "")
  var next = String(digit || "")
  if (!/^[0-9]$/.test(next)) return value
  if (value === "" && next === "0") return ""
  return (value + next).slice(0, 4)
}

function countValue(value) {
  var parsed = parseInt(String(value || ""), 10)
  return isFinite(parsed) && parsed > 0 ? parsed : 1
}

function movedIndex(currentIndex, direction, count, rowCount) {
  if (rowCount <= 0) return -1
  var current = Math.max(0, Math.min(rowCount - 1, Number(currentIndex) || 0))
  var target = current + direction * Math.max(1, Number(count) || 1)
  return Math.max(0, Math.min(rowCount - 1, target))
}

function pageStep(firstVisibleIndex, lastVisibleIndex, fraction) {
  var visibleRows = Math.max(1,
    Number(lastVisibleIndex) - Number(firstVisibleIndex) + 1)
  return Math.max(1, Math.floor(visibleRows * Number(fraction || 1)))
}
