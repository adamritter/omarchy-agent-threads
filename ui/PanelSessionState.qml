// Purpose: Implements the Panel Session State user-interface component.
import QtQuick

QtObject {
  property var notificationThreadStates: ({})
  property bool notificationStateReady: false
  property var expandedGroups: ({})
  property var providerViewStates: ({})
  property double nowMs: Date.now()
  property string searchText: ""
  property bool searchOpen: false
  property bool renameOpen: false
  property var renameTargetThread: null
  property string renameTargetRemoteId: ""
  property bool helpOpen: false
  property string navigationCount: ""
  readonly property string instanceToken: Date.now() + "-" + Math.random()
  property int navigationFindDirection: 0
  property bool remoteSetupOpen: false
  property string remoteSetupType: "ssh"
  property string remoteSetupProvider: "codex"
  property string editingRemoteId: ""
  property int focusAttemptsRemaining: 0
  property bool focusPrimed: false
  property bool focusWorkflowPending: false
  property bool reloadStateLoaded: false
  property bool applyingReloadState: false
  property string pendingReloadRowKey: ""
  property bool reloadSelectionGuard: false
  property bool pendingReloadFocus: false
  property string pendingReloadFocusTarget: "list"
  property string pendingReloadWorkspaceKey: ""
  property bool pointerHoverSuppressed: false
  property int cursorReturnX: -1
  property int cursorReturnY: -1
  property int fullscreenInternalState: 0
  property int fullscreenClientState: 0
  property bool activeWorkspaceHasFullscreen: false
  property bool activeWorkspaceGeometryFullscreen: false
  property bool fullscreenProbeQueued: false
  property bool internalFocusTransfer: false
  property bool applyingWorkspaceSidebarState: false
  property int activeWorkspaceId: 0
  property string activeWorkspaceKey: ""
  property bool keyboardFocusRequested: false
}
