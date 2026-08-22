import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  required property var panel
  readonly property bool inputFocused: remoteNameField.activeFocus
    || remoteAddressField.activeFocus || remoteHomeField.activeFocus
    || remoteTokenField.activeFocus
  property alias nameText: remoteNameField.text
  property alias addressText: remoteAddressField.text
  property alias homeText: remoteHomeField.text
  property alias tokenText: remoteTokenField.text

  function resetFields() {
    nameText = ""
    addressText = ""
    homeText = ""
    tokenText = ""
  }

  function focusName() {
    remoteNameField.forceActiveFocus()
  }

  function blurFields() {
    remoteNameField.focus = false
    remoteAddressField.focus = false
    remoteHomeField.focus = false
    remoteTokenField.focus = false
  }
  anchors.fill: parent
  visible: panel.remoteSetupOpen
  color: Color.popups.background
  radius: Style.cornerRadius
  z: 3

  Flickable {
    anchors.fill: parent
    contentHeight: remoteSetupContent.implicitHeight + Style.space(20)
    clip: true

    Column {
      id: remoteSetupContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.space(10)
      spacing: Style.space(8)

      Text {
        width: parent.width
        text: panel.providerLabel() + " REMOTE KAPCSOLAT"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: panel.activeProvider === "codex"
            ? [
                { value: "ssh", label: "SSH" },
                { value: "app-server", label: "APP SERVER" }
              ]
            : [{ value: "ssh", label: "SSH" }]

          delegate: Rectangle {
            required property var modelData
            width: panel.activeProvider === "codex"
              ? (remoteSetupContent.width - Style.space(6)) / 2
              : remoteSetupContent.width
            height: Style.space(34)
            radius: Style.cornerRadius
            color: panel.remoteSetupType === modelData.value
              ? Style.selectedFillFor(panel.foreground, Color.accent) : panel.faint
            border.width: 1
            border.color: panel.remoteSetupType === modelData.value
              ? Color.accent : "transparent"

            Text {
              anchors.centerIn: parent
              text: parent.modelData.label
              color: panel.remoteSetupType === parent.modelData.value
                ? Color.accent : panel.foreground
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.remoteSetupType = parent.modelData.value
            }
          }
        }
      }

      Text {
        visible: panel.remoteSetupType === "ssh"
        width: parent.width
        text: "SSH CONFIG HOSTOK"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        visible: panel.remoteSetupType === "ssh"
          && (panel.service.sshHostsLoading === true
              || String(panel.service.sshHostsError || "") !== ""
              || (panel.service.sshHosts || []).length === 0)
        width: parent.width
        text: panel.service.sshHostsLoading === true ? "SSH hostok betöltése…"
          : (String(panel.service.sshHostsError || "") !== ""
            ? String(panel.service.sshHostsError || "")
            : "Nincs konkrét Host bejegyzés a ~/.ssh/config fájlban")
        color: String(panel.service.sshHostsError || "") !== ""
          ? Color.urgent : panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Repeater {
        model: panel.remoteSetupType === "ssh" ? (panel.service.sshHosts || []) : []

        delegate: Rectangle {
          id: sshConfigHost
          required property var modelData
          readonly property bool enabledHost: panel.service.sshHostEnabled(
            modelData, panel.activeProvider)
          width: remoteSetupContent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: sshHostMouse.containsMouse && !enabledHost ? panel.faint : "transparent"
          border.width: 1
          border.color: enabledHost ? Util.alpha(Color.accent, 0.45) : panel.dim

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: String(parent.modelData || "")
            color: parent.enabledHost ? panel.dim : panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: parent.enabledHost ? "Bekapcsolva" : "+ Bekapcsolás"
            color: parent.enabledHost ? panel.dim : Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: sshHostMouse
            anchors.fill: parent
            enabled: !parent.enabledHost
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: panel.enableSshHost(parent.modelData)
          }
        }
      }

      Text {
        text: panel.remoteSetupType === "ssh" ? "MÁS SSH HOST" : "KAPCSOLAT ADATAI"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        text: "Név"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteNameField
        width: parent.width
        height: Style.space(34)
        placeholderText: "pl. bee vagy szerver"
        foreground: panel.foreground
        accent: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteAddressField
        Keys.onEscapePressed: panel.closeRemoteSetup()
        Keys.onReturnPressed: remoteAddressField.forceActiveFocus()
        Keys.onEnterPressed: remoteAddressField.forceActiveFocus()
      }

      Text {
        text: panel.remoteSetupType === "ssh" ? "SSH host / alias" : "App Server URL"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteAddressField
        width: parent.width
        height: Style.space(34)
        placeholderText: panel.remoteSetupType === "ssh"
          ? "user@host vagy ~/.ssh/config alias"
          : "wss://host:4500"
        foreground: panel.foreground
        accent: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteHomeField
        Keys.onEscapePressed: panel.closeRemoteSetup()
        Keys.onReturnPressed: panel.saveRemoteSetup()
        Keys.onEnterPressed: panel.saveRemoteSetup()
      }

      Text {
        text: "Remote home (opcionális)"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteHomeField
        width: parent.width
        height: Style.space(34)
        placeholderText: "/home/user"
        foreground: panel.foreground
        accent: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: panel.remoteSetupType === "app-server"
          ? remoteTokenField : remoteNameField
        Keys.onEscapePressed: panel.closeRemoteSetup()
        Keys.onReturnPressed: panel.saveRemoteSetup()
        Keys.onEnterPressed: panel.saveRemoteSetup()
      }

      Text {
        visible: panel.remoteSetupType === "app-server"
        text: "Token fájl ezen a gépen (opcionális)"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteTokenField
        visible: panel.remoteSetupType === "app-server"
        width: parent.width
        height: visible ? Style.space(34) : 0
        placeholderText: "~/.codex/app-server-token"
        foreground: panel.foreground
        accent: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteNameField
        Keys.onEscapePressed: panel.closeRemoteSetup()
        Keys.onReturnPressed: panel.saveRemoteSetup()
        Keys.onEnterPressed: panel.saveRemoteSetup()
      }

      Text {
        width: parent.width
        text: panel.remoteSetupType === "ssh"
          ? "Az SSH config kezeli a kulcsot, portot és jumphostot. Jelszó nélküli kulcsos belépés és a távoli "
            + panel.providerLabel() + " CLI szükséges."
          : "Távoli hálózaton használj wss:// címet; ws:// csak localhosthoz vagy biztonságos tunnelhez való."
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Text {
        visible: panel.service.remoteAddError !== ""
        width: parent.width
        text: panel.service.remoteAddError
        color: Color.urgent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: (parent.width - Style.space(8)) / 2
          height: Style.space(36)
          radius: Style.cornerRadius
          color: cancelRemoteMouse.containsMouse ? panel.faint : "transparent"
          border.width: 1
          border.color: panel.dim

          Text {
            anchors.centerIn: parent
            text: "Mégse"
            color: panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            id: cancelRemoteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.closeRemoteSetup()
          }
        }

        Rectangle {
          width: (parent.width - Style.space(8)) / 2
          height: Style.space(36)
          radius: Style.cornerRadius
          color: addRemoteMouse.containsMouse
            ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.accent, 0.18)
          border.width: 1
          border.color: Color.accent

          Text {
            anchors.centerIn: parent
            text: "Hozzáadás"
            color: Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          MouseArea {
            id: addRemoteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.saveRemoteSetup()
          }
        }
      }
    }
  }
}
