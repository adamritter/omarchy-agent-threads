import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "services" as Services
import "ui" as Ui
import "logic/PanelBarLogic.js" as PanelBarLogic
import "logic/PanelHelpLogic.js" as PanelHelpLogic
import "logic/ThreadNotificationLogic.js" as ThreadNotificationLogic

Panel {
  id: root
  moduleName: "adam.codex-threads"
  ipcTarget: "adam.codex-threads"
  manageIpc: false
  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property var service: Quickshell.env("AGENT_THREADS_PANEL_TEST") === "1"
    ? null : Services.ThreadStore
  property string layerNamespace: "omarchy-codex-threads"
  property bool layerMappingEnabled: true
  readonly property alias appearance: appearanceObject
  Ui.PanelAppearance { id: appearanceObject; bar: root.bar }
  readonly property alias environment: environmentObject
  Ui.PanelEnvironment { id: environmentObject }
  property bool fullscreenSuppressionEnabled: true
  readonly property bool fullscreenSuppressed: fullscreenSuppressionEnabled
    && session.activeWorkspaceHasFullscreen
  readonly property bool sidebarPresented: opened && !fullscreenSuppressed
  readonly property bool sidebarItemFocused: (sidebarView !== null
    && sidebarView.searchField !== null && sidebarView.renameField !== null
    && (sidebarView.activeFocus || sidebarView.searchField.activeFocus
      || sidebarView.renameField.activeFocus)) || remoteSetup.inputFocused
  readonly property bool sidebarFocused: session.keyboardFocusRequested && sidebarItemFocused
  readonly property string activeProvider: service.settings.selectedProvider || "codex"
  readonly property var activeProviderHost: providerActions.providerHost(activeProvider)
  readonly property var readyThreadTargets: ThreadNotificationLogic.readyThreadTargets(
    service.threads, service.unreadThreads, service.providers.remoteHosts)
  readonly property int readyThreadCount: readyThreadTargets.length
  readonly property var providerChoices: [
    { id: "codex", label: "CODEX" },
    { id: "claude", label: "CLAUDE" },
    { id: "opencode", label: "OPENCODE" }
  ]
  readonly property alias viewRows: threadListModelObject.viewRows
  readonly property var collapsedProjects: service.settings.collapsedProjects
  readonly property var collapsedRemotes: service.settings.collapsedRemotes
  readonly property var pinnedSections: service.settings.pinnedSections
  readonly property int groupPreviewLimit: 10
  readonly property alias projectCount: threadListModelObject.projectCount
  readonly property alias visibleThreadCount: threadListModelObject.visibleThreadCount
  property alias selectedIndex: threadListModelObject.selectedIndex
  readonly property var sidebarActions: sidebarController
  readonly property bool reloadSelectionPending: session.pendingReloadRowKey !== ""
    || session.reloadSelectionGuard
  readonly property string reloadStatePath: service && service.runtimeDir
    ? service.runtimeDir + "/omarchy-agent-threads-panel-reload.json" : ""
  readonly property bool pointerWarpActive: runtime.pointerWarpGuard.running

  onSidebarItemFocusedChanged: {
    if (sidebarItemFocused || !session.keyboardFocusRequested
        || session.internalFocusTransfer) return
    if (runtime.focusReleaseGuard.running) {
      session.focusPrimed = false
      session.focusAttemptsRemaining = Math.max(session.focusAttemptsRemaining, 30)
      if (!runtime.focusAcquireTimer.running) runtime.focusAcquireTimer.restart()
      return
    }
    if (!runtime.focusAcquireTimer.running) focusActions.releaseSidebarFocus(false)
  }
  onSelectedIndexChanged: reloadActions.schedulePanelReloadStateCapture()
  readonly property var helpItems: PanelHelpLogic.items(
    service.settings.threadFrontend, service.settings.fastMode,
    service.settings.selectedEffortForProvider(activeProvider))
  readonly property alias session: sessionObject
  Ui.PanelSessionState { id: sessionObject }
  Ui.ThreadListModel {
    id: threadListModelObject
    service: root.service
    session: root.session
    activeProvider: root.activeProvider
    groupPreviewLimit: root.groupPreviewLimit
    homePath: root.environment.homePath
    workPath: root.environment.workPath
    codexScratchRoot: root.environment.codexScratchRoot
  }

  Ui.SidebarController {
    id: sidebarController
    panel: root
    listView: root.sidebarView ? root.sidebarView.threadList : null
  }

  readonly property var sidebarView: sidebarLoader.item
  readonly property alias remoteSetup: remoteSetupControl
  readonly property alias helpOverlay: helpOverlayControl
  readonly property alias listModel: threadListModelObject
  readonly property alias reloadActions: reloadActionsObject
  Ui.PanelReloadController { id: reloadActionsObject; panel: root }
  readonly property alias providerActions: providerActionsObject
  Ui.PanelProviderController { id: providerActionsObject; panel: root }
  readonly property alias overlayActions: overlayActionsObject
  Ui.PanelOverlayController { id: overlayActionsObject; panel: root }
  readonly property alias listActions: listActionsObject
  Ui.PanelListController { id: listActionsObject; panel: root }
  readonly property alias focusActions: focusActionsObject
  Ui.PanelFocusController {
    id: focusActionsObject
    panel: root
    compositor: Hyprland
  }
  readonly property alias sidebarHover: sidebarHoverObject
  readonly property alias runtime: runtimeProcesses
  readonly property alias sidebarReload: sidebarReloadObject
  Ui.SidebarReloadController { id: sidebarReloadObject; panel: root }

  function reloadEntryPoint(kind) { return sidebarReload.reloadEntryPoint(kind) }

  Ui.PanelRuntimeConnections { panel: root }

  Ui.PanelRuntimeProcesses {
    id: runtimeProcesses
    panel: root
  }

  Ui.PanelIpcHandler { panel: root }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰚩"
    active: root.sidebarFocused || root.readyThreadCount > 0
    activeColor: root.readyThreadCount > 0
      ? root.appearance.readyThreadColor : (root.bar ? root.bar.urgent : Color.urgent)
    tooltipText: PanelBarLogic.tooltip(
      root.readyThreadCount, root.fullscreenSuppressed,
      root.opened, root.sidebarFocused)
    onPressed: function(buttonCode) {
      if (buttonCode !== Qt.LeftButton) return
      if (root.readyThreadCount > 0) root.providerActions.openLatestReadyThread()
      else root.focusActions.requestToggle()
    }
  }

  PanelWindow {
    id: panel

    screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    visible: root.layerMappingEnabled && root.sidebarPresented
    color: "transparent"
    implicitWidth: root.appearance.sidebarContentWidth
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.appearance.sidebarContentWidth

    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.sidebarPresented && root.session.keyboardFocusRequested
      ? (root.session.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
    }

    // The bar's exclusive zone already places this surface beyond the bar.
    // Add only the shared panel gap instead of counting the bar height twice.
    margins {
      top: root.bar && root.bar.position === "top"
        ? root.appearance.sidebarBarGap : 0
      bottom: root.bar && root.bar.position === "bottom"
        ? root.appearance.sidebarBarGap : 0
    }

    BorderSurface {
      id: card
      anchors.fill: parent
      color: Color.popups.background
      borderSpec: root.sidebarFocused
        ? Border.surfaceSpec("popups", "border", Color.popups.border,
                             Math.max(1, Style.space(2)))
        : Border.flat("transparent", Math.max(1, Style.space(2)))
      padding: Style.spacing.popupPadding
      radius: Style.cornerRadius

      HoverHandler {
        id: sidebarHoverObject
        onHoveredChanged: {
          if (hovered && !root.runtime.pointerWarpGuard.running)
            root.session.pointerHoverSuppressed = false
          // Super+A already starts an explicit focus cycle after moving the
          // pointer. Do not start a second competing cycle on pointer entry.
          if (hovered && root.opened && !root.session.keyboardFocusRequested)
            root.focusActions.focusSidebar()
        }
      }

      Loader {
        id: sidebarLoader
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        property string requestedSource: root.sidebarReload.sidebarSource
        property bool initialized: false

        function loadSidebar() {
          setSource(requestedSource, { panel: root })
        }

        onRequestedSourceChanged: if (initialized) loadSidebar()
        onLoaded: Qt.callLater(root.sidebarReload.restoreState)
        Component.onCompleted: {
          initialized = true
          loadSidebar()
        }
      }

      Ui.RemoteSetup {
        id: remoteSetupControl
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        panel: root
      }

      Ui.HelpOverlay {
        id: helpOverlayControl
        anchors.fill: remoteSetupControl
        panel: root
      }
    }
  }

  Component.onCompleted: {
    listActions.rebuildRows()
    providerActions.syncThreadNotificationStates()
    focusActions.applySidebarOpenState()
  }
}
