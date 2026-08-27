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
  readonly property bool editing: panel.editingRemoteId !== ""

  function resetFields() {
    nameText = ""
    addressText = ""
    homeText = ""
    tokenText = ""
  }

  function loadHost(host) {
    nameText = String(host && host.label || "")
    addressText = String(host && (host.type === "ssh" ? host.sshHost : host.url) || "")
    homeText = String(host && host.home || "")
    tokenText = String(host && host.authTokenFile || "")
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
        text: root.editing ? "EDIT REMOTE"
          : panel.providerLabel(panel.remoteSetupProvider) + " REMOTE CONNECTION"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: panel.remoteSetupProvider === "codex"
            ? [
                { value: "ssh", label: "SSH" },
                { value: "app-server", label: "APP SERVER" }
              ]
            : [{ value: "ssh", label: "SSH" }]

          delegate: Rectangle {
            required property var modelData
            width: panel.remoteSetupProvider === "codex"
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
        visible: !root.editing && panel.remoteSetupType === "ssh"
        width: parent.width
        text: "SSH CONFIG HOSTS"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        visible: !root.editing && panel.remoteSetupType === "ssh"
          && (panel.service.sshHostsLoading === true
              || String(panel.service.sshHostsError || "") !== ""
              || (panel.service.sshHosts || []).length === 0)
        width: parent.width
        text: panel.service.sshHostsLoading === true ? "Loading SSH hosts…"
          : (String(panel.service.sshHostsError || "") !== ""
            ? String(panel.service.sshHostsError || "")
            : "No explicit Host entries found in ~/.ssh/config")
        color: String(panel.service.sshHostsError || "") !== ""
          ? Color.urgent : panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Repeater {
        model: !root.editing && panel.remoteSetupType === "ssh"
          ? (panel.service.sshHosts || []) : []

        delegate: Rectangle {
          id: sshConfigHost
          required property var modelData
          readonly property bool enabledHost: panel.service.sshHostEnabled(
            modelData, panel.remoteSetupProvider)
          width: remoteSetupContent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: sshHostMouse.containsMouse ? panel.faint : "transparent"
          border.width: 1
          border.color: enabledHost ? Util.alpha(Color.accent, 0.45) : panel.dim

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            text: String(parent.modelData || "")
            color: parent.enabledHost ? Color.accent : panel.foreground
            font.family: panel.fontFamily
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
              ? panel.dim : Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: sshHostMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.toggleSshHost(parent.modelData)
          }
        }
      }

      Text {
        text: root.editing ? "CONNECTION DETAILS"
          : (panel.remoteSetupType === "ssh" ? "OTHER SSH HOST" : "CONNECTION DETAILS")
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        text: "Name"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteNameField
        width: parent.width
        height: Style.space(34)
        placeholderText: "e.g. bee or server"
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
          ? "user@host or ~/.ssh/config alias"
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
        text: "Remote home (optional)"
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
        text: "Token file on this machine (optional)"
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
          ? (panel.remoteSetupProvider === "claude"
            ? "Install Claude Code and run claude auth login on the remote machine first. Passwordless SSH is required; the status bridge is installed automatically."
            : (panel.remoteSetupProvider === "opencode"
              ? "The headless OpenCode API starts automatically on the remote machine. Passwordless SSH, Node.js, curl, and an installed and authenticated OpenCode CLI are required. The first launch can take up to 30 seconds."
              : "Your SSH config manages keys, ports, and jump hosts. Passwordless key authentication and a remote Codex CLI are required."))
          : "Use wss:// over remote networks; use ws:// only for localhost or a secure tunnel."
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

      Text {
        visible: root.editing
          && panel.service.remoteTestHostId === panel.editingRemoteId
          && panel.service.remoteTestMessage !== ""
        width: parent.width
        text: panel.service.remoteTestMessage
        color: panel.service.remoteTestRunning ? panel.dim
          : (panel.service.remoteTestSucceeded ? Color.accent : Color.urgent)
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
            text: "Cancel"
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
            text: root.editing ? "Save" : "Add"
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
