// Purpose: Implements the Thread List Row user-interface component.
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../logic/PresentationLogic.js" as PresentationLogic

Rectangle {
  id: row

  required property var panel
  required property var modelData
  required property int index
  readonly property color busyThreadColor: "#e5c07b"
  readonly property color readyThreadColor: "#98c379"
  readonly property bool pointerHovered: mouse.containsMouse
    && !panel.session.pointerHoverSuppressed
  readonly property var presentation: panel.sidebarActions.actions.rowPresentation(
    modelData, index, pointerHovered)
  readonly property bool remoteRow: presentation.remoteRow
  readonly property bool projectRow: presentation.projectRow
  readonly property bool moreRow: presentation.moreRow
  readonly property bool sectionRow: presentation.sectionRow
  readonly property bool threadRow: presentation.threadRow
  readonly property var threadData: presentation.threadData
  readonly property bool loginableRemoteClaude: presentation.loginableRemoteClaude
  readonly property bool loggingInRemoteClaude: presentation.loggingInRemoteClaude
  readonly property bool needsRemoteClaudeAction: presentation.needsRemoteClaudeAction
  readonly property bool groupedThread: presentation.groupedThread
  readonly property bool activeThread: presentation.activeThread
  readonly property bool activeProject: presentation.activeProject
  readonly property bool busy: presentation.busy
  readonly property bool blocked: presentation.blocked
  readonly property bool unread: presentation.unread
  readonly property bool pinned: presentation.pinned
  readonly property bool pinnedSection: presentation.pinnedSection
  readonly property bool archiving: presentation.archiving
  readonly property bool pinning: presentation.pinning
  readonly property bool renaming: presentation.renaming
  readonly property bool moving: presentation.moving
  readonly property string backgroundRole: PresentationLogic.rowBackgroundRole(
    activeThread, pointerHovered, index === panel.selectedIndex, panel.sidebarFocused)

    function renderSnapshot() {
      return {
        index: index,
        instantiated: true,
        kind: String(modelData.kind || "thread"),
        key: panel.listActions.rowKey(modelData),
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
      if (rowActions.item) rowActions.item.openMenu()
    }

    width: ListView.view ? ListView.view.width : 0
    height: sectionRow ? Style.space(52)
      : (moreRow ? Style.space(38) : threadContent.implicitHeight + Style.space(8))
    radius: Style.cornerRadius
    color: backgroundRole === "active" || backgroundRole === "focused-selection"
      ? panel.appearance.focusedSelectionFill
      : (backgroundRole === "hover"
          ? panel.appearance.faint
          : (backgroundRole === "unfocused-selection"
              ? panel.appearance.unfocusedSelectionFill : "transparent"))

    Text {
      visible: row.threadRow && !row.busy && !row.blocked && !row.unread
      anchors.left: parent.left
      anchors.leftMargin: Style.space(row.groupedThread ? 22 : 0)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(22)
      text: panel.listActions.age(row.threadData ? row.threadData.updatedAt : 0)
      color: panel.appearance.dim
      font.family: panel.appearance.fontFamily
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
          panel.session.pointerHoverSuppressed = false
      }
      onClicked: panel.sidebarActions.actions.activateRow(row.index, "pointer")
    }

    TapHandler {
      acceptedButtons: Qt.RightButton
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: row.openThreadMenu()
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
      color: row.pointerHovered ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
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
        text: row.presentation.threadTitle
        textFormat: Text.PlainText
        color: row.activeThread ? Color.accent : panel.appearance.foreground
        opacity: row.archiving || row.moving || row.pinning || row.renaming ? 0.58 : 1
        font.family: panel.appearance.fontFamily
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
      text: row.presentation.sectionIndicator
      color: row.activeProject || (row.remoteRow && !row.presentation.collapsed)
        ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      visible: row.sectionRow
      anchors.left: parent.left
      anchors.leftMargin: Style.space(22 + Number(row.modelData.depth || 0) * 18)
      anchors.right: parent.right
      anchors.rightMargin: (rowActions.item
        ? rowActions.item.reservedWidth : Style.space(106)) + Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        id: sectionTitleText
        width: parent.width
        text: row.modelData.name + "  ·  " + row.modelData.count
        textFormat: Text.PlainText
        color: row.activeProject ? Color.accent : panel.appearance.foreground
        font.family: panel.appearance.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        visible: !row.remoteRow || !row.modelData.host.loading
        width: parent.width
        text: row.presentation.sectionSubtitle
        textFormat: Text.PlainText
        color: row.remoteRow && row.modelData.host.error !== ""
          && !row.needsRemoteClaudeAction ? Color.urgent : panel.appearance.dim
        font.family: panel.appearance.fontFamily
        font.pixelSize: Math.max(9, Style.font.caption - 1)
        elide: Text.ElideMiddle
      }
    }

    Loader {
      id: rowActions
      anchors.fill: parent
      z: 2
      Component.onCompleted: setSource(
        Qt.resolvedUrl("ThreadListRowActions.qml"), {
          panel: row.panel,
          rowItem: row
        })
    }
}
