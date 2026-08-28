// Purpose: Implements the Remote Setup user-interface component.
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
  readonly property bool editing: panel.session.editingRemoteId !== ""

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
  visible: panel.session.remoteSetupOpen
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
          : panel.providerActions.providerLabel(panel.session.remoteSetupProvider) + " REMOTE CONNECTION"
        color: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: panel.session.remoteSetupProvider === "codex"
            ? [
                { value: "ssh", label: "SSH" },
                { value: "app-server", label: "APP SERVER" }
              ]
            : [{ value: "ssh", label: "SSH" }]

          delegate: Rectangle {
            required property var modelData
            width: panel.session.remoteSetupProvider === "codex"
              ? (remoteSetupContent.width - Style.space(6)) / 2
              : remoteSetupContent.width
            height: Style.space(34)
            radius: Style.cornerRadius
            color: panel.session.remoteSetupType === modelData.value
              ? Style.selectedFillFor(panel.appearance.foreground, Color.accent) : panel.appearance.faint
            border.width: 1
            border.color: panel.session.remoteSetupType === modelData.value
              ? Color.accent : "transparent"

            Text {
              anchors.centerIn: parent
              text: parent.modelData.label
              color: panel.session.remoteSetupType === parent.modelData.value
                ? Color.accent : panel.appearance.foreground
              font.family: panel.appearance.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: panel.session.remoteSetupType = parent.modelData.value
            }
          }
        }
      }

      RemoteSetupSshHosts {
        width: parent.width
        panel: root.panel
        setup: root
      }

      Text {
        text: root.editing ? "CONNECTION DETAILS"
          : (panel.session.remoteSetupType === "ssh" ? "OTHER SSH HOST" : "CONNECTION DETAILS")
        color: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        text: "Name"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteNameField
        width: parent.width
        height: Style.space(34)
        placeholderText: "e.g. bee or server"
        foreground: panel.appearance.foreground
        accent: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteAddressField
        Keys.onEscapePressed: panel.overlayActions.closeRemoteSetup()
        Keys.onReturnPressed: remoteAddressField.forceActiveFocus()
        Keys.onEnterPressed: remoteAddressField.forceActiveFocus()
      }

      Text {
        text: panel.session.remoteSetupType === "ssh" ? "SSH host / alias" : "App Server URL"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteAddressField
        width: parent.width
        height: Style.space(34)
        placeholderText: panel.session.remoteSetupType === "ssh"
          ? "user@host or ~/.ssh/config alias"
          : "wss://host:4500"
        foreground: panel.appearance.foreground
        accent: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteHomeField
        Keys.onEscapePressed: panel.overlayActions.closeRemoteSetup()
        Keys.onReturnPressed: panel.overlayActions.saveRemoteSetup()
        Keys.onEnterPressed: panel.overlayActions.saveRemoteSetup()
      }

      Text {
        text: "Remote home (optional)"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteHomeField
        width: parent.width
        height: Style.space(34)
        placeholderText: "/home/user"
        foreground: panel.appearance.foreground
        accent: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: panel.session.remoteSetupType === "app-server"
          ? remoteTokenField : remoteNameField
        Keys.onEscapePressed: panel.overlayActions.closeRemoteSetup()
        Keys.onReturnPressed: panel.overlayActions.saveRemoteSetup()
        Keys.onEnterPressed: panel.overlayActions.saveRemoteSetup()
      }

      Text {
        visible: panel.session.remoteSetupType === "app-server"
        text: "Token file on this machine (optional)"
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
      }

      TextField {
        id: remoteTokenField
        visible: panel.session.remoteSetupType === "app-server"
        width: parent.width
        height: visible ? Style.space(34) : 0
        placeholderText: "~/.codex/app-server-token"
        foreground: panel.appearance.foreground
        accent: Color.accent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        KeyNavigation.tab: remoteNameField
        Keys.onEscapePressed: panel.overlayActions.closeRemoteSetup()
        Keys.onReturnPressed: panel.overlayActions.saveRemoteSetup()
        Keys.onEnterPressed: panel.overlayActions.saveRemoteSetup()
      }

      Text {
        width: parent.width
        text: panel.session.remoteSetupType === "ssh"
          ? (panel.session.remoteSetupProvider === "claude"
            ? "Install Claude Code and run claude auth login on the remote machine first. Passwordless SSH is required; the status bridge is installed automatically."
            : (panel.session.remoteSetupProvider === "opencode"
              ? "The headless OpenCode API starts automatically on the remote machine. Passwordless SSH, Node.js, curl, and an installed and authenticated OpenCode CLI are required. The first launch can take up to 30 seconds."
              : "Your SSH config manages keys, ports, and jump hosts. Passwordless key authentication and a remote Codex CLI are required."))
          : "Use wss:// over remote networks; use ws:// only for localhost or a secure tunnel."
        color: panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Text {
        visible: panel.service.providers.remoteAddError !== ""
        width: parent.width
        text: panel.service.providers.remoteAddError
        color: Color.urgent
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      Text {
        visible: root.editing
          && panel.service.providers.remoteTestHostId === panel.session.editingRemoteId
          && panel.service.providers.remoteTestMessage !== ""
        width: parent.width
        text: panel.service.providers.remoteTestMessage
        color: panel.service.providers.remoteTestRunning ? panel.appearance.dim
          : (panel.service.providers.remoteTestSucceeded ? Color.accent : Color.urgent)
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
      }

      RemoteSetupActions {
        width: parent.width
        panel: root.panel
        setup: root
      }
    }
  }

}
