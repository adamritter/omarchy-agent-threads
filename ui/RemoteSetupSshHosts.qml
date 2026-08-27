import QtQuick
import qs.Commons

Column {
  required property var panel
  required property var setup
  spacing: Style.space(8)

  Text {
    visible: !setup.editing && panel.session.remoteSetupType === "ssh"
    width: parent.width
    text: "SSH CONFIG HOSTS"
    color: Color.accent
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
  
  Text {
    visible: !setup.editing && panel.session.remoteSetupType === "ssh"
      && (panel.service.sshHostsLoading === true
          || String(panel.service.sshHostsError || "") !== ""
          || (panel.service.sshHosts || []).length === 0)
    width: parent.width
    text: panel.service.sshHostsLoading === true ? "Loading SSH hosts…"
      : (String(panel.service.sshHostsError || "") !== ""
        ? String(panel.service.sshHostsError || "")
        : "No explicit Host entries found in ~/.ssh/config")
    color: String(panel.service.sshHostsError || "") !== ""
      ? Color.urgent : panel.appearance.dim
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }
  
  Repeater {
    model: !setup.editing && panel.session.remoteSetupType === "ssh"
      ? (panel.service.sshHosts || []) : []
  
    delegate: Rectangle {
      id: sshConfigHost
      required property var modelData
      readonly property bool enabledHost: panel.service.providers.sshHostEnabled(
        modelData, panel.session.remoteSetupProvider)
      width: parent.width
      height: Style.space(34)
      radius: Style.cornerRadius
      color: sshHostMouse.containsMouse ? panel.appearance.faint : "transparent"
      border.width: 1
      border.color: enabledHost ? Util.alpha(Color.accent, 0.45) : panel.appearance.dim
  
      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: String(parent.modelData || "")
        color: parent.enabledHost ? Color.accent : panel.appearance.foreground
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
  
      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: parent.enabledHost
          ? (sshHostMouse.containsMouse ? "− Disable" : "Enabled")
          : "+ Enable"
        color: parent.enabledHost && !sshHostMouse.containsMouse
          ? panel.appearance.dim : Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }
  
      MouseArea {
        id: sshHostMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.overlayActions.toggleSshHost(parent.modelData)
      }
    }
  }
}
