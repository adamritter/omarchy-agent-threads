import QtQuick

Item {
  id: root

  required property var flickable
  property real speedMultiplier: 2
  property real mouseWheelStep: Math.max(1,
    Number(Application.styleHints.wheelScrollLines) || 3) * 24

  x: 0
  y: 0
  width: flickable.width
  height: flickable.height
  z: 1000

  function scrollDistance(pixelDeltaY, angleDeltaY) {
    var distance = Number(pixelDeltaY) || 0
    if (distance === 0)
      distance = (Number(angleDeltaY) || 0) / 120 * mouseWheelStep
    return distance * speedMultiplier
  }

  function boundedContentY(value) {
    var minimum = Number(flickable.originY) || 0
    var maximum = Math.max(minimum,
      minimum + Math.max(0, Number(flickable.contentHeight) || 0)
        - Math.max(0, Number(flickable.height) || 0))
    return Math.max(minimum, Math.min(maximum, value))
  }

  WheelHandler {
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    blocking: true

    onWheel: function(event) {
      var distance = root.scrollDistance(event.pixelDelta.y, event.angleDelta.y)
      if (distance === 0 || !root.flickable.interactive) {
        event.accepted = false
        return
      }

      var previous = root.flickable.contentY
      root.flickable.cancelFlick()
      root.flickable.contentY = root.boundedContentY(previous - distance)
      event.accepted = Math.abs(root.flickable.contentY - previous) > 0.01
    }
  }
}
