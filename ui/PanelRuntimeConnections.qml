import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
  required property var panel
  visible: false

  Connections {
    target: panel

    function onOpenedChanged() {
      if (!panel.bar) return
      if (!panel.session.applyingWorkspaceSidebarState && panel.session.activeWorkspaceKey !== "")
        panel.service.settings.setSidebarOpenOnWorkspace(
          panel.session.activeWorkspaceKey, panel.opened)
      if (panel.opened) {
        panel.session.nowMs = Date.now()
        panel.service.providers.refreshThreads()
        panel.service.threadActions.refreshActiveThread()
        if (!panel.session.applyingWorkspaceSidebarState)
          panel.sidebarActions.navigation.followActiveThread(true)
        panel.focusActions.queryFullscreenState()
      } else {
        panel.reloadActions.clearNavigationPrefix()
        panel.session.keyboardFocusRequested = false
        panel.session.focusPrimed = false
        panel.session.cursorReturnX = -1
        panel.session.cursorReturnY = -1
        panel.overlayActions.setSearchText("")
        panel.session.searchOpen = false
        panel.session.helpOpen = false
        panel.session.remoteSetupOpen = false
      }
    }

    function onBarChanged() {
      panel.focusActions.queryFullscreenState()
      panel.focusActions.applySidebarOpenState()
      Qt.callLater(panel.reloadActions.tryRestorePanelReloadFocus)
    }
  }

  Connections {
    target: panel.service
    ignoreUnknownSignals: true

    function onThreadsChanged() {
      panel.listActions.rebuildRows()
      panel.sidebarActions.navigation.followActiveThread(false)
      panel.providerActions.syncThreadNotificationStates()
    }
    function onProjectsChanged() { panel.listActions.rebuildRows() }
    function onRemoteHostsChanged() {
      panel.listActions.rebuildRows()
      panel.sidebarActions.navigation.followActiveThread(false)
      panel.providerActions.syncThreadNotificationStates()
    }
    function onThreadStatusesChanged() {
      panel.providerActions.syncThreadNotificationStates()
    }
    function onUnreadThreadsChanged() {
      panel.providerActions.syncThreadNotificationStates()
    }
    function onCollapsedProjectsChanged() { panel.listActions.rebuildRows() }
    function onCollapsedRemotesChanged() { panel.listActions.rebuildRows() }
    function onPinnedSectionsChanged() { panel.listActions.rebuildRows() }
    function onSelectedProviderChanged() {
      panel.providerActions.restoreProviderViewState(panel.activeProvider)
    }
    function onActiveThreadIdChanged() {
      panel.sidebarActions.navigation.followActiveThread(false)
    }
    function onLaunchingThreadIdChanged() {
      panel.sidebarActions.navigation.followActiveThread(false)
    }
    function onSidebarSettingsLoadedChanged() {
      panel.focusActions.applySidebarOpenState()
    }
    function onSidebarOpenWorkspacesChanged() {
      if (!panel.session.applyingWorkspaceSidebarState)
        panel.focusActions.applySidebarOpenState()
    }
    function onSidebarScopeChanged() { panel.focusActions.applySidebarOpenState() }
    function onGlobalSidebarOpenChanged() {
      if (!panel.session.applyingWorkspaceSidebarState)
        panel.focusActions.applySidebarOpenState()
    }
  }

  Connections {
    target: ToplevelManager

    function onActiveToplevelChanged() {
      panel.focusActions.queryFullscreenState()
      if (panel.session.keyboardFocusRequested && panel.sidebarHover.hovered) return
      panel.focusActions.releaseSidebarFocus(false)
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      var name = String(event && (event.name || event.event || event.type) || "")
      if (name === "workspace" || name === "workspacev2"
          || name === "activespecial" || name === "activespecialv2"
          || name === "focusedmon" || name === "focusedmonv2"
          || name === "fullscreen" || name === "fullscreenv2"
          || name === "activewindow" || name === "activewindowv2"
          || name === "openwindow" || name === "closewindow")
        panel.runtime.fullscreenProbeDebounce.restart()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: panel.focusActions.queryFullscreenState()
  }

  Timer {
    interval: 30000
    running: panel.opened
    repeat: true
    onTriggered: panel.session.nowMs = Date.now()
  }
}
