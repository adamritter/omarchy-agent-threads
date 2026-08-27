import QtQuick

Item {
  id: root

  required property var controller
  readonly property alias configLoaded: configStore.loaded
  readonly property alias remoteConfig: configStore.config
  property var remoteHosts: []
  property var queryQueue: []
  property string queryHostId: ""
  property string actionHostId: ""
  property string actionKind: ""
  property string actionThreadId: ""
  property bool actionPinValue: false
  property string archivedThreadId: ""
  property var archivedThreadSnapshot: null
  property int archivedThreadIndex: -1
  property string archiveConfirmationHostId: ""
  property string archiveConfirmationThreadId: ""
  property string addError: ""
  property string managementTestHostId: ""
  property bool managementTestRunning: false
  property bool managementTestSucceeded: false
  property string managementTestMessage: ""
  readonly property alias loginHostId: claudeManager.loginHostId
  readonly property alias loginRunning: claudeManager.loginRunning
  property var sshHosts: []
  property bool sshHostsLoading: false
  property string sshHostsError: ""
  property bool openIsNew: false
  property string openHostId: ""
  property string pendingHostId: ""
  property string pendingPath: ""
  property var pendingKnownIds: ({})
  property string pendingWindowAddress: ""
  property int pendingAttempts: 0
  property int openRequestId: 0

  readonly property string queryHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-remote-query").toString().replace(/^file:\/\//, "")
  readonly property string openHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-remote-open").toString().replace(/^file:\/\//, "")
  readonly property string sshHostsHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-ssh-hosts").toString().replace(/^file:\/\//, "")

  RemoteProviderRegistry { id: providerRegistry }
  RemoteConfigStore {
    id: configStore
    provider: root
    controller: root.controller
    providerRegistry: providerRegistry
  }
  RemoteClaudeManager {
    id: claudeManager
    provider: root
    controller: root.controller
  }
  ThreadLaunchCoordinator { id: launchCoordinator }
  readonly property alias configPath: configStore.path

  RemoteAgentSnapshots {
    id: snapshots
    provider: root
    processes: processHost
    configStore: configStore
    registry: providerRegistry
  }

  function providerTypeForEntry(entry) { return snapshots.providerTypeForEntry(entry) }
  function providerLabel(host) { return snapshots.providerLabel(host) }
  function hostById(hostId) { return snapshots.hostById(hostId) }
  function updateHost(hostId, patch) { return snapshots.updateHost(hostId, patch) }
  function restoreSnapshots(values) { return snapshots.restoreSnapshots(values) }
  function projectForId(host, projectId) { return snapshots.projectForId(host, projectId) }
  function projectRoot(project) { return snapshots.projectRoot(project) }
  function pathForThread(host, thread) { return snapshots.pathForThread(host, thread) }
  function threadStatus(thread) { return snapshots.threadStatus(thread) }
  function mergeUnread(host, nextThreads) { return snapshots.mergeUnread(host, nextThreads) }
  function markThreadSeen(threadId) { return snapshots.markThreadSeen(threadId) }
  function refresh(hostId) { return snapshots.refresh(hostId) }
  function refreshVisibleProvider() { return snapshots.refreshVisibleProvider() }
  function startNextQuery() { return snapshots.startNextQuery() }
  function applySnapshot(snapshot) { return snapshots.applySnapshot(snapshot) }

  RemoteAgentManagement {
    id: management
    provider: root
    processes: processHost
    configStore: configStore
    registry: providerRegistry
    manager: claudeManager
  }

  function threadIndex(items, threadId) { return management.threadIndex(items, threadId) }
  function threadsWithoutId(items, threadId) { return management.threadsWithoutId(items, threadId) }
  function configuredRemoteById(hostId) { return management.configuredRemoteById(hostId) }
  function writeRemoteConfig(remotes) { return management.writeRemoteConfig(remotes) }
  function add(label, type, address, home, tokenFile, providerType) { return management.add(label, type, address, home, tokenFile, providerType) }
  function updateRemote(hostId, label, type, address, home, tokenFile, providerType) { return management.updateRemote(hostId, label, type, address, home, tokenFile, providerType) }
  function removeRemote(hostId) { return management.removeRemote(hostId) }
  function testRemote(hostId) { return management.testRemote(hostId) }
  function loginClaude(hostId) { return management.loginClaude(hostId) }
  function sshHostEnabled(alias, providerType) { return management.sshHostEnabled(alias, providerType) }
  function remoteIdForSshHost(alias, providerType) { return management.remoteIdForSshHost(alias, providerType) }
  function refreshSshHosts() { return management.refreshSshHosts() }
  function archiveThread(hostId, thread) { return management.archiveThread(hostId, thread) }
  function renameThread(hostId, thread, name) { return management.renameThread(hostId, thread, name) }
  function toggleThreadPin(hostId, thread) { return management.toggleThreadPin(hostId, thread) }
  function applyThreadPin(hostId, threadId, pinned, returnedThread) { return management.applyThreadPin(hostId, threadId, pinned, returnedThread) }
  function restoreArchivedThread(hostId) { return management.restoreArchivedThread(hostId) }

  RemoteAgentLaunch {
    id: remoteLaunch
    provider: root
    processes: processHost
    launches: launchCoordinator
  }

  function openThread(hostId, thread, path, source) {
    return remoteLaunch.openThread(hostId, thread, path, source)
  }
  function newThread(hostId, path) { return remoteLaunch.newThread(hostId, path) }
  function clearPendingNew() { return remoteLaunch.clearPendingNew() }
  function resolvePendingNew(hostId) { return remoteLaunch.resolvePendingNew(hostId) }
  function stopNewResolveTimer() { newResolveTimer.stop() }


  RemoteAgentProcessHost {
    id: processHost
    provider: root
    launches: launchCoordinator
  }

  function restartNewResolveTimer() { newResolveTimer.restart() }


  Connections {
    target: root.controller
    function onActiveThreadIdChanged() {
      root.markThreadSeen(root.controller.activeThreadId)
    }
  }


  Timer {
    id: newResolveTimer
    interval: 800
    repeat: true
    onTriggered: {
      root.pendingAttempts--
      root.refresh(root.pendingHostId)
      root.resolvePendingNew(root.pendingHostId)
      if (root.pendingHostId === "") stop()
      else if (root.pendingAttempts <= 0) {
        var pendingHost = root.hostById(root.pendingHostId)
        root.controller.launchError = "The new remote "
          + root.providerLabel(pendingHost) + " thread did not appear in time"
        root.clearPendingNew()
      }
    }
  }

  Timer {
    interval: root.controller.sidebarOpen ? 2000 : 30000
    running: Array.isArray(root.remoteHosts) && root.remoteHosts.length > 0
    repeat: true
    onTriggered: root.refreshVisibleProvider()
  }

  Component.onDestruction: processHost.stopAll()
}
