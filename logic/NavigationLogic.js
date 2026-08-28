.pragma library
// Purpose: Provides deterministic Navigation decisions shared by QML adapters.

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

function countedRowIndex(value, rowCount) {
  if (rowCount <= 0) return -1
  return Math.min(rowCount - 1, countValue(value) - 1)
}

function matchingThreadIndex(rows, currentIndex, direction, character, count, titleForRow) {
  var values = rows || []
  var step = direction < 0 ? -1 : 1
  var wanted = String(character || "").charAt(0)
  if (wanted === "" || values.length === 0) return -1
  var remaining = countValue(count)
  for (var index = Number(currentIndex) + step;
       index >= 0 && index < values.length; index += step) {
    var row = values[index]
    if (!row || row.kind !== "thread") continue
    var title = titleForRow ? titleForRow(row)
      : String(row.title || row.name || "")
    if (String(title || "").trim().charAt(0) !== wanted) continue
    remaining--
    if (remaining === 0) return index
  }
  return -1
}

function pageStep(firstVisibleIndex, lastVisibleIndex, fraction) {
  var visibleRows = Math.max(1,
    Number(lastVisibleIndex) - Number(firstVisibleIndex) + 1)
  return Math.max(1, Math.floor(visibleRows * Number(fraction || 1)))
}
