import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "." as Components
import "../logic/PresentationLogic.js" as PresentationLogic

Rectangle {
  id: row

  required property var panel
  required property var modelData
  required property int index
  readonly property color busyThreadColor: "#e5c07b"
  readonly property color readyThreadColor: "#98c379"
  readonly property bool remoteRow: modelData.kind === "remote"
    readonly property bool projectRow: modelData.kind === "project"
    readonly property bool moreRow: modelData.kind === "more"
    readonly property bool sectionRow: remoteRow || projectRow
    readonly property bool threadRow: !sectionRow && !moreRow
    readonly property var threadData: threadRow ? modelData.thread : null
    readonly property bool loginableRemoteClaude: remoteRow
      && String(modelData.host && modelData.host.providerType || "") === "claude"
      && modelData.host.available !== false
      && modelData.host.authenticated === false
    readonly property bool loggingInRemoteClaude: loginableRemoteClaude
      && panel.service.remoteClaudeLoginHostId === String(modelData.remoteId || "")
      && panel.service.remoteClaudeLoginRunning
    readonly property bool needsRemoteClaudeAction: loginableRemoteClaude
    readonly property bool groupedThread: threadRow && modelData.grouped === true
    readonly property bool activeThread: threadRow
      && panel.service.activeThreadId !== ""
      && String(threadData.id || "") === panel.service.activeThreadId
      && String(modelData.remoteId || "")
        === String(panel.sidebarActions.threadScopeForId(panel.service.activeThreadId) || "")
    readonly property var activeThreadData: panel.sidebarActions.threadForId(
      panel.service.activeThreadId)
    readonly property bool activeProject: projectRow
      && !modelData.remoteId
      && activeThreadData !== null
      && panel.projectPath(activeThreadData) === modelData.path
    readonly property bool busy: threadRow
      && (modelData.remoteId
        ? panel.service.remoteThreadStatus(threadData) === "busy"
        : panel.service.threadStatus(threadData.id) === "busy")
    readonly property bool blocked: threadRow
      && (modelData.remoteId
        ? panel.service.remoteThreadStatus(threadData) === "blocked"
        : panel.service.threadStatus(threadData.id) === "blocked")
    readonly property bool unread: threadRow
      && (modelData.remoteId
        ? threadData.unread === true
        : panel.service.threadUnread(threadData.id))
    readonly property bool pinned: threadRow && threadData.isPinned === true
    readonly property bool pinnedSection: sectionRow && panel.sectionPinned(
      remoteRow ? "remote" : "project", modelData.path, modelData.remoteId)
    readonly property bool archiving: threadRow
      && String(threadData.id || "") === panel.service.archivingThreadId
      && String(modelData.remoteId || "")
        === String(panel.service.remoteActionHostId || "")
    readonly property bool pinning: threadRow
      && String(threadData.id || "") === panel.service.pinningThreadId
      && String(modelData.remoteId || "")
        === String(panel.service.remoteActionHostId || "")
    readonly property bool renaming: threadRow
      && String(threadData.id || "") === panel.service.renamingThreadId
      && String(modelData.remoteId || "")
        === String(panel.service.remoteActionHostId || "")
    readonly property bool moving: threadRow && !modelData.remoteId
      && String(threadData.id || "") === panel.service.movingThreadId
    readonly property bool pointerHovered: mouse.containsMouse
      && !panel.pointerHoverSuppressed
    readonly property string backgroundRole: PresentationLogic.rowBackgroundRole(
      activeThread, pointerHovered, index === panel.selectedIndex,
      panel.sidebarFocused)

    function renderSnapshot() {
      return {
        index: index,
        instantiated: true,
        kind: String(modelData.kind || "thread"),
        key: panel.rowKey(modelData),
        primaryText: threadRow ? threadTitleText.text
          : (sectionRow ? sectionTitleText.text : moreTitleText.text),
        active: activeThread || activeProject,
        busy: busy,
        blocked: blocked,
        unread: unread,
        pinned: pinned || pinnedSection,
        backgroundRole: backgroundRole,
        depth: Number(modelData.depth || 0)
      }
    }

    function openThreadMenu() {
      if (remoteRow) {
        panel.selectedIndex = row.index
        remoteMenu.open()
        return
      }
      if (projectRow) {
        panel.selectedIndex = row.index
        projectMenu.open()
        return
      }
      if (!threadRow) return
      panel.selectedIndex = row.index
      threadMenu.open()
    }

    width: ListView.view ? ListView.view.width : 0
    height: sectionRow ? Style.space(52)
      : (moreRow ? Style.space(38) : threadContent.implicitHeight + Style.space(8))
    radius: Style.cornerRadius
    color: backgroundRole === "active" || backgroundRole === "focused-selection"
      ? panel.focusedSelectionFill
      : (backgroundRole === "hover"
          ? panel.faint
          : (backgroundRole === "unfocused-selection"
              ? panel.unfocusedSelectionFill : "transparent"))

    Text {
      visible: row.threadRow && !row.busy && !row.blocked && !row.unread
      anchors.left: parent.left
      anchors.leftMargin: Style.space(row.groupedThread ? 22 : 0)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(22)
      text: panel.age(row.threadData ? row.threadData.updatedAt : 0)
      color: panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - 1)
      horizontalAlignment: row.groupedThread ? Text.AlignLeft : Text.AlignHCenter
    }

    Item {
      id: statusCircle
      visible: row.busy || row.blocked || row.unread
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2 + (row.groupedThread
        ? Number(row.modelData.depth || 1) * 18 : 0))
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(14)
      height: width

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(10)
        height: width
        radius: width / 2
        color: row.blocked ? Color.urgent
          : (row.busy ? row.busyThreadColor : row.readyThreadColor)
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onPositionChanged: {
        if (!panel.pointerWarpActive)
          panel.pointerHoverSuppressed = false
      }
      onClicked: function(event) {
        panel.selectedIndex = row.index
        if (row.moreRow) {
          if (event.button === Qt.LeftButton)
            panel.showAllGroup(row.modelData.groupKind, row.modelData.path,
              row.modelData.remoteId)
          return
        }
        if (row.remoteRow) panel.toggleRemote(row.modelData.remoteId)
        else if (row.projectRow)
          panel.toggleProject(row.modelData.path, row.modelData.remoteId)
        else if (row.modelData.remoteId)
          panel.service.openRemoteThread(row.modelData.remoteId,
                                        row.threadData, row.modelData.path)
        else panel.service.openThread(row.threadData, row.modelData.path)
      }
    }

    TapHandler {
      acceptedButtons: Qt.RightButton
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: row.openThreadMenu()
    }

    Components.ProjectContextMenu {
      id: projectMenu
      panel: row.panel
      rowItem: row
    }

    Rectangle {
      id: threadMenuButton
      visible: row.threadRow
        && (row.pointerHovered || threadMenuMouse.containsMouse || threadMenu.opened)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28)
      height: width
      radius: Style.cornerRadius
      color: threadMenuMouse.containsMouse || threadMenu.opened
        ? Util.alpha(panel.foreground, 0.14) : "transparent"
      z: 2

      Text {
        anchors.centerIn: parent
        text: "⋯"
        color: panel.foreground
        font.family: panel.fontFamily
        font.pixelSize: Style.font.title
        verticalAlignment: Text.AlignVCenter
      }

      MouseArea {
        id: threadMenuMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: row.openThreadMenu()
      }

      Components.ThreadContextMenu {
        id: threadMenu
        panel: row.panel
        rowItem: row
      }
    }

    Rectangle {
      id: threadPinButton
      visible: row.threadRow
        && (row.pointerHovered || threadPinMouse.containsMouse || row.pinned || row.pinning)
      anchors.right: threadMenuButton.left
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28)
      height: width
      radius: Style.cornerRadius
      color: threadPinMouse.containsMouse
        ? Util.alpha(panel.foreground, 0.14) : "transparent"
      z: 2

      Text {
        anchors.centerIn: parent
        text: "󰐃"
        color: row.pinned ? Color.accent : panel.dim
        opacity: row.pinning ? 0.45 : 1
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        id: threadPinMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: !row.pinning
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.selectedIndex = row.index
          panel.sidebarActions.togglePin(row.modelData.remoteId, row.threadData)
        }
      }
    }

    Text {
      id: moreTitleText
      visible: row.moreRow
      anchors.left: parent.left
      anchors.leftMargin: Style.space(22 + Number(row.modelData.depth || 0) * 18)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: "…  Show all  ·  " + Number(row.modelData.remaining || 0) + " more"
      color: row.pointerHovered ? Color.accent : panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Column {
      id: threadContent
      visible: row.threadRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(row.groupedThread
        ? (Number(row.modelData.depth || 1) * 18 + 26)
        : 22)
      anchors.rightMargin: Style.space(68)
      spacing: Style.space(2)

      Text {
        id: threadTitleText
        width: parent.width
        text: row.renaming ? "Renaming…  " + panel.threadTitle(row.threadData)
          : (row.pinning ? "Updating pin…  " + panel.threadTitle(row.threadData)
          : (row.moving ? "Moving…  " + panel.threadTitle(row.threadData)
          : (row.archiving ? "Archiving…  " + panel.threadTitle(row.threadData)
            : (row.pinned ? "󰐃  " : "") + panel.threadTitle(row.threadData))))
        textFormat: Text.PlainText
        color: row.activeThread ? Color.accent : panel.foreground
        opacity: row.archiving || row.moving || row.pinning || row.renaming ? 0.58 : 1
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }
    }

    Text {
      visible: row.sectionRow
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2 + Number(row.modelData.depth || 0) * 18)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(14)
      text: row.remoteRow
        ? (panel.remoteCollapsed(row.modelData.remoteId) ? "▸" : "▾")
        : (panel.projectCollapsed(row.modelData.path, row.modelData.remoteId)
            ? "\uf07b" : "\uf07c")
      color: row.activeProject
        || (row.remoteRow && !panel.remoteCollapsed(row.modelData.remoteId))
        ? Color.accent : panel.dim
      font.family: panel.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      visible: row.sectionRow
      anchors.left: parent.left
      anchors.leftMargin: Style.space(22 + Number(row.modelData.depth || 0) * 18)
      anchors.right: row.needsRemoteClaudeAction
        ? remoteClaudeActionButton.left : remoteManageButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        id: sectionTitleText
        width: parent.width
        text: row.modelData.name + "  ·  " + row.modelData.count
        textFormat: Text.PlainText
        color: row.activeProject ? Color.accent : panel.foreground
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        visible: !row.remoteRow || !row.modelData.host.loading
        width: parent.width
        text: row.remoteRow
          ? (row.needsRemoteClaudeAction ? "CLAUDE"
            : (row.modelData.host.error !== "" ? row.modelData.host.error
            : (row.modelData.host.providerType
              ? String(row.modelData.host.providerType).toUpperCase()
              : (row.modelData.host.type === "ssh" ? "SSH" : "APP SERVER"))))
          : row.modelData.path
        textFormat: Text.PlainText
        color: row.remoteRow && row.modelData.host.error !== ""
          && !row.needsRemoteClaudeAction ? Color.urgent : panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Math.max(9, Style.font.caption - 1)
        elide: Text.ElideMiddle
      }
    }

    Rectangle {
      id: remoteClaudeActionButton
      visible: row.needsRemoteClaudeAction
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      width: visible ? Style.space(92) : 0
      height: Style.space(30)
      radius: Style.cornerRadius
      color: remoteClaudeActionMouse.containsMouse
        ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.accent, 0.16)
      border.width: 1
      border.color: Color.accent
      z: 4

      Text {
        anchors.centerIn: parent
        text: row.loggingInRemoteClaude ? "OPENING…" : "LOGIN"
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
      }

      MouseArea {
        id: remoteClaudeActionMouse
        anchors.fill: parent
        enabled: !panel.service.remoteClaudeLoginRunning
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
          panel.selectedIndex = row.index
          panel.service.loginRemoteClaude(row.modelData.remoteId)
        }
      }
    }

    Item {
      id: remoteManageButton
      visible: row.remoteRow
        && !row.needsRemoteClaudeAction
        && (row.pointerHovered || remoteManageMouse.containsMouse || remoteMenu.opened)
      anchors.right: sectionPinButton.left
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      width: visible ? Style.space(28) : 0
      height: width
      z: 3

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: remoteManageMouse.containsMouse
          ? Util.alpha(panel.foreground, 0.14) : "transparent"
      }

      Text {
        anchors.centerIn: parent
        text: "⋯"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.title
      }

      MouseArea {
        id: remoteManageMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.selectedIndex = row.index
          remoteMenu.open()
        }
      }
    }

    Components.RemoteContextMenu {
      id: remoteMenu
      panel: row.panel
      rowItem: row
    }

    Item {
      id: sectionPinButton
      visible: row.sectionRow
        && !row.needsRemoteClaudeAction
        && (row.pointerHovered || sectionPinMouse.containsMouse || row.pinnedSection)
      anchors.right: newProjectButton.left
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28)
      height: width
      z: 2

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: sectionPinMouse.containsMouse
          ? Util.alpha(panel.foreground, 0.14) : "transparent"
      }

      Text {
        anchors.centerIn: parent
        text: "󰐃"
        color: row.pinnedSection ? Color.accent : panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.body
      }

      MouseArea {
        id: sectionPinMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.selectedIndex = row.index
          panel.toggleSectionPin(row.remoteRow ? "remote" : "project",
            row.modelData.path, row.modelData.remoteId)
        }
      }
    }

    Item {
      id: newProjectButton
      visible: row.sectionRow && !row.needsRemoteClaudeAction
        && (row.pointerHovered || newProjectMouse.containsMouse)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(28)
      height: width

      Text {
        anchors.centerIn: parent
        text: panel.service.launchingProjectPath === row.modelData.path ? "…" : "+"
        color: newProjectMouse.containsMouse ? Color.accent : panel.foreground
        font.family: panel.fontFamily
        font.pixelSize: Style.font.title
      }

      MouseArea {
        id: newProjectMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.selectedIndex = row.index
          if (row.modelData.remoteId)
            panel.service.newRemoteThread(row.modelData.remoteId,
              row.modelData.path || row.modelData.host.home)
          else panel.service.newProjectThread(row.modelData.path)
        }
      }
    }
}
