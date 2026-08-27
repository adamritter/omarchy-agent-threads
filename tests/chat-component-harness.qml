import QtQuick
import Quickshell

ShellRoot {
  Component.onCompleted: {
    var path = Quickshell.env("AGENT_CHAT_COMPONENT_PATH")
    var component = Qt.createComponent(
      "file://" + path, Component.PreferSynchronous)
    if (component.status === Component.Ready)
      console.info("CHAT_COMPONENT_PASS")
    else console.warn("CHAT_COMPONENT_FAIL: " + component.errorString())
    component.destroy()
    Qt.callLater(Qt.quit)
  }
}
