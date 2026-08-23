import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "." as Components

ListView {
  id: root

  function renderSnapshot() {
    var rendered = []
    for (var index = 0; index < count; index++) {
      var item = itemAtIndex(index)
      rendered.push(item ? item.renderSnapshot() : {
        index: index,
        instantiated: false
      })
    }
    return rendered
  }

  required property var panel
  anchors.fill: parent
  visible: !panel.helpOpen
  model: panel.viewRows
  clip: true
  spacing: 0
  currentIndex: panel.selectedIndex
  boundsBehavior: Flickable.StopAtBounds
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Components.FastScrollHandler {
    flickable: root
    speedMultiplier: 2
  }

  delegate: Rectangle {
    id: row
    required property var modelData
    required property int index
    readonly property bool remoteRow: modelData.kind === "remote"
    readonly property bool projectRow: modelData.kind === "project"
    readonly property bool moreRow: modelData.kind === "more"
    readonly property bool sectionRow: remoteRow || projectRow
    readonly property bool threadRow: !sectionRow && !moreRow
    readonly property var threadData: threadRow ? modelData.thread : null
    readonly property bool installableRemoteClaude: remoteRow
      && String(modelData.host && modelData.host.providerType || "") === "claude"
      && modelData.host.available === false
    readonly property bool installingRemoteClaude: installableRemoteClaude
      && panel.service.remoteClaudeInstallHostId === String(modelData.remoteId || "")
    readonly property bool loginableRemoteClaude: remoteRow
      && String(modelData.host && modelData.host.providerType || "") === "claude"
      && modelData.host.available !== false
      && modelData.host.authenticated === false
    readonly property bool loggingInRemoteClaude: loginableRemoteClaude
      && panel.service.remoteClaudeLoginHostId === String(modelData.remoteId || "")
      && panel.service.remoteClaudeLoginRunning
    readonly property bool needsRemoteClaudeAction: installableRemoteClaude
      || loginableRemoteClaude
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
        depth: Number(modelData.depth || 0)
      }
    }

    function openThreadMenu() {
      if (remoteRow) {
        panel.selectedIndex = row.index
        remoteMenu.open()
        return
      }
      if (!threadRow) return
      panel.selectedIndex = row.index
      threadMenu.open()
    }

    width: root.width
    height: sectionRow ? Style.space(52)
      : (moreRow ? Style.space(38) : threadContent.implicitHeight + Style.space(8))
    radius: Style.cornerRadius
    color: activeThread
      ? Style.selectedFillFor(panel.foreground, Color.accent)
      : (mouse.containsMouse
          || (panel.sidebarFocused && index === panel.selectedIndex)
          ? panel.faint : "transparent")

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
        color: row.blocked ? Color.urgent : (row.unread ? Color.accent : "transparent")
        border.width: row.blocked ? 0 : Math.max(1, Style.space(2))
        border.color: row.blocked ? Color.urgent : Color.accent
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Style.space(4)
        height: width
        radius: width / 2
        visible: row.busy && !row.blocked
        color: Color.accent
      }

      RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
        running: row.busy && !row.blocked
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
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

    Rectangle {
      id: threadMenuButton
      visible: row.threadRow
        && (mouse.containsMouse || threadMenuMouse.containsMouse || threadMenu.opened)
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

      Popup {
        id: threadMenu
        x: parent ? parent.width - width : 0
        y: parent ? parent.height + Style.space(4) : 0
        width: Style.space(240)
        padding: Style.space(4)
        property bool choosingProject: false
        // A modal, non-dimming overlay reliably observes clicks
        // outside the menu and uses them only to dismiss it.
        modal: true
        dim: false
        focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: choosingProject = false

        background: BorderSurface {
          color: Color.background
          borderSpec: Border.flat(panel.dim, 1)
          radius: Style.cornerRadius
        }

        contentItem: Column {
          spacing: 0

          Repeater {
            visible: !threadMenu.choosingProject
            model: row.modelData.remoteId ? [
              { label: row.pinned ? "Unpin thread" : "Pin thread", hint: "p", action: "pin" },
              { label: "Open thread", hint: "Enter / o", action: "open" },
              { label: "Rename…", hint: "r", action: "rename" },
              { label: "New thread here", hint: "n", action: "new" },
              { label: "Archive", hint: "y", action: "archive" }
            ] : [
              { label: row.pinned ? "Unpin thread" : "Pin thread", hint: "p", action: "pin" },
              { label: "Open thread", hint: "Enter / o", action: "open" },
              { label: "Rename…", hint: "r", action: "rename" },
              { label: "New thread here", hint: "n", action: "new" },
              { label: "Move to…", hint: "›", action: "move" },
              { label: "Archive", hint: "y", action: "archive" }
            ]

            delegate: Rectangle {
              id: menuChoice
              required property var modelData
              visible: !threadMenu.choosingProject
              width: parent.width
              height: visible ? Style.space(38) : 0
              radius: Style.cornerRadius
              color: menuChoiceMouse.containsMouse ? panel.faint : "transparent"

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: menuChoice.modelData.label
                color: menuChoice.modelData.action === "archive"
                  ? Color.urgent : panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: menuChoice.modelData.hint
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: menuChoiceMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var action = String(menuChoice.modelData.action || "")
                  if (action === "move") {
                    threadMenu.choosingProject = true
                    return
                  }
                  threadMenu.close()
                  if (action === "pin") {
                    panel.sidebarActions.togglePin(row.modelData.remoteId, row.threadData)
                  } else if (action === "open") {
                    if (row.modelData.remoteId)
                      panel.service.openRemoteThread(row.modelData.remoteId,
                        row.threadData, row.modelData.path)
                    else panel.service.openThread(row.threadData, row.modelData.path)
                  } else if (action === "rename") {
                    panel.startRename(row.modelData.remoteId, row.threadData)
                  } else if (action === "new") {
                    if (row.modelData.remoteId)
                      panel.service.newRemoteThread(row.modelData.remoteId, row.modelData.path)
                    else panel.service.newProjectThread(row.modelData.path)
                  } else if (action === "archive") {
                    if (row.modelData.remoteId)
                      panel.service.archiveRemoteThread(row.modelData.remoteId, row.threadData)
                    else panel.service.archiveThread(row.threadData)
                  }
                }
              }
            }
          }

          Column {
            visible: threadMenu.choosingProject && !row.modelData.remoteId
            width: parent.width
            spacing: 0

            Rectangle {
              width: parent.width
              height: Style.space(38)
              radius: Style.cornerRadius
              color: moveBackMouse.containsMouse ? panel.faint : "transparent"

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: "‹  Move to project"
                color: panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              MouseArea {
                id: moveBackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: threadMenu.choosingProject = false
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: panel.faint
            }

            Repeater {
              model: row.modelData.remoteId ? [] : panel.projectMoveTargets(row.threadData)

              delegate: Rectangle {
                id: projectChoice
                required property var modelData
                width: parent.width
                height: Style.space(48)
                radius: Style.cornerRadius
                color: projectChoiceMouse.containsMouse ? panel.faint : "transparent"

                Column {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    text: projectChoice.modelData.name
                    textFormat: Text.PlainText
                    color: panel.foreground
                    font.family: panel.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: projectChoice.modelData.path
                    textFormat: Text.PlainText
                    color: panel.dim
                    font.family: panel.fontFamily
                    font.pixelSize: Math.max(9, Style.font.caption - 1)
                    elide: Text.ElideMiddle
                  }
                }

                MouseArea {
                  id: projectChoiceMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    threadMenu.close()
                    panel.service.moveThreadToProject(
                      row.threadData,
                      projectChoice.modelData.path,
                      projectChoice.modelData.name)
                  }
                }
              }
            }

            Text {
              visible: panel.projectMoveTargets(row.threadData).length === 0
              width: parent.width
              height: Style.space(42)
              text: "No other projects"
              color: panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }

    Rectangle {
      id: threadPinButton
      visible: row.threadRow
        && (mouse.containsMouse || threadPinMouse.containsMouse || row.pinned || row.pinning)
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
      color: mouse.containsMouse ? Color.accent : panel.dim
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
        text: row.installingRemoteClaude ? "INSTALLING…"
          : (row.loggingInRemoteClaude ? "OPENING…"
            : (row.installableRemoteClaude ? "INSTALL" : "LOGIN"))
        color: Color.accent
        font.family: panel.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
      }

      MouseArea {
        id: remoteClaudeActionMouse
        anchors.fill: parent
        enabled: row.installableRemoteClaude
          ? !panel.service.remoteClaudeInstallRunning
          : !panel.service.remoteClaudeLoginRunning
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
          panel.selectedIndex = row.index
          if (row.installableRemoteClaude)
            panel.service.installRemoteClaude(row.modelData.remoteId)
          else panel.service.loginRemoteClaude(row.modelData.remoteId)
        }
      }
    }

    Item {
      id: remoteManageButton
      visible: row.remoteRow
        && !row.needsRemoteClaudeAction
        && (mouse.containsMouse || remoteManageMouse.containsMouse || remoteMenu.opened)
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

    Popup {
      id: remoteMenu
      x: Math.max(0, row.width - width - Style.space(6))
      y: row.height - Style.space(4)
      width: Style.space(210)
      padding: Style.space(4)
      modal: true
      dim: false
      focus: false
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

      readonly property bool testingThis: panel.service.remoteTestRunning
        && panel.service.remoteTestHostId === String(row.modelData.remoteId || "")
      readonly property bool hasTestResult: panel.service.remoteTestHostId
          === String(row.modelData.remoteId || "")
        && String(panel.service.remoteTestMessage || "") !== ""

      background: BorderSurface {
        color: Color.background
        borderSpec: Border.flat(panel.dim, 1)
        radius: Style.cornerRadius
      }

      contentItem: Column {
        spacing: 0

        Repeater {
          model: [
            { label: remoteMenu.testingThis ? "Testing…" : "Test connection", action: "test" },
            { label: "Edit connection…", action: "edit" },
            { label: "Disable remote", action: "disable" }
          ]

          delegate: Rectangle {
            id: remoteMenuChoice
            required property var modelData
            width: parent.width
            height: Style.space(38)
            radius: Style.cornerRadius
            color: remoteMenuChoiceMouse.containsMouse ? panel.faint : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: remoteMenuChoice.modelData.label
              color: remoteMenuChoice.modelData.action === "disable"
                ? Color.urgent : panel.foreground
              font.family: panel.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: remoteMenuChoiceMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: remoteMenuChoice.modelData.action !== "test"
                || !remoteMenu.testingThis
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: {
                var action = String(remoteMenuChoice.modelData.action || "")
                if (action === "test") {
                  panel.service.testRemote(row.modelData.remoteId)
                  return
                }
                remoteMenu.close()
                if (action === "edit")
                  panel.openRemoteSetup(row.modelData.remoteId)
                else if (action === "disable")
                  panel.disableRemote(row.modelData.remoteId)
              }
            }
          }
        }

        Text {
          visible: remoteMenu.hasTestResult
          width: parent.width
          topPadding: Style.space(5)
          leftPadding: Style.space(10)
          rightPadding: Style.space(10)
          bottomPadding: Style.space(7)
          text: panel.service.remoteTestMessage
          textFormat: Text.PlainText
          color: remoteMenu.testingThis ? panel.dim
            : (panel.service.remoteTestSucceeded ? Color.accent : Color.urgent)
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }
      }
    }

    Item {
      id: sectionPinButton
      visible: row.sectionRow
        && !row.needsRemoteClaudeAction
        && (mouse.containsMouse || sectionPinMouse.containsMouse || row.pinnedSection)
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
        && (mouse.containsMouse || newProjectMouse.containsMouse)
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
}
