import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  required property var controller
  property bool configLoaded: false
  property var remoteConfig: ({})
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

  readonly property string queryHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-remote-query").toString().replace(/^file:\/\//, "")
  readonly property string openHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-remote-open").toString().replace(/^file:\/\//, "")
  readonly property string sshHostsHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-ssh-hosts").toString().replace(/^file:\/\//, "")
  readonly property string mapThreadWindowHelperPath: Qt.resolvedUrl(
    "../bin/omarchy-codex-map-thread-window").toString().replace(/^file:\/\//, "")
  readonly property string configPath: controller.stateHome
    + "/omarchy/codex-thread-remotes.json"

  function providerTypeForEntry(entry) {
    return String(entry && entry.providerType || "").toLowerCase() === "claude"
      ? "claude" : ""
  }

  function providerLabel(host) {
    return providerTypeForEntry(host) === "claude" ? "Claude" : "Codex"
  }

  function initializeConfig(raw) {
    if (configLoaded) return
    var text = String(raw || "").trim()
    if (text === "") {
      text = JSON.stringify({ version: 1, remotes: [] }, null, 2)
      configFile.setText(text + "\n")
      Qt.callLater(root.secureConfigFile)
    }
    text += "\n"
    loadConfig(text)
  }

  function loadPrimaryConfig(raw) {
    if (configLoaded) loadConfig(raw)
    else initializeConfig(raw)
    secureConfigFile()
  }

  function secureConfigFile() {
    if (configPermissionsProcess.running) return
    configPermissionsProcess.command = ["chmod", "600", configPath]
    configPermissionsProcess.running = true
  }

  function loadConfig(raw) {
    var parsed = ({ version: 1, remotes: [] })
    try {
      var text = String(raw || "").trim()
      parsed = text === "" ? parsed : JSON.parse(text)
    } catch (error) {
      console.warn("Codex Threads: invalid remote config:", error)
      addError = "Invalid remote.json"
    }

    var configured = Array.isArray(parsed) ? parsed
      : (Array.isArray(parsed.remotes) ? parsed.remotes : [])
    var nextHosts = []
    for (var i = 0; i < configured.length; i++) {
      var entry = configured[i] || ({})
      var id = String(entry.id || "remote-" + (i + 1))
      var existing = hostById(id)
      var providerType = providerTypeForEntry(entry)
      nextHosts.push(Object.assign({}, entry, {
        id: id,
        label: String(entry.label || id),
        providerType: providerType,
        type: providerType === "claude" || entry.type === "ssh" ? "ssh" : "app-server",
        threads: existing ? existing.threads : [],
        projects: existing ? existing.projects : [],
        models: existing ? existing.models : [],
        agents: existing ? existing.agents : [],
        loaded: existing ? existing.loaded === true : false,
        loading: false,
        error: ""
      }))
    }

    remoteConfig = { version: 2, remotes: configured }
    remoteHosts = nextHosts
    configLoaded = true
    controller.startAppServer()
    refresh()
  }

  function hostById(hostId) {
    var wanted = String(hostId || "")
    for (var i = 0; i < remoteHosts.length; i++) {
      if (String(remoteHosts[i].id || "") === wanted) return remoteHosts[i]
    }
    return null
  }

  function updateHost(hostId, patch) {
    var wanted = String(hostId || "")
    var next = []
    for (var i = 0; i < remoteHosts.length; i++) {
      var host = remoteHosts[i]
      next.push(String(host.id || "") === wanted ? Object.assign({}, host, patch) : host)
    }
    remoteHosts = next
  }

  function projectForId(host, projectId) {
    var wanted = String(projectId || "")
    var items = host && Array.isArray(host.projects) ? host.projects : []
    for (var i = 0; i < items.length; i++) {
      if (String(items[i].id || "") === wanted) return items[i]
    }
    return null
  }

  function projectRoot(project) {
    if (!project || !project.roots || project.roots.length === 0) return ""
    return String(project.roots[0].path || "")
  }

  function pathForThread(host, thread) {
    var project = projectForId(host, thread ? thread.projectId : "")
    var rootPath = projectRoot(project)
    return rootPath !== "" ? rootPath : String(thread && thread.cwd || host && host.home || "")
  }

  function threadStatus(thread) {
    var status = thread ? thread.status : null
    var type = typeof status === "string" ? status : String(status && status.type || "")
    return type === "active" ? "busy" : "done"
  }

  function threadById(items, threadId) {
    var wanted = String(threadId || "")
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") === wanted) return items[i]
    }
    return null
  }

  function mergeUnread(host, nextThreads) {
    var previous = host && host.threads || []
    var merged = []
    for (var i = 0; i < nextThreads.length; i++) {
      var next = nextThreads[i]
      var id = String(next && next.id || "")
      var old = threadById(previous, id)
      var wasBusy = old && threadStatus(old) === "busy"
      var nowBusy = threadStatus(next) === "busy"
      var unread = next.attention === true || (old && old.unread === true)
      if (wasBusy && !nowBusy && id !== controller.activeThreadId) unread = true
      if (id === controller.activeThreadId) unread = false
      merged.push(Object.assign({}, next, { unread: unread }))
    }
    return merged
  }

  function markThreadSeen(threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return
    for (var hostIndex = 0; hostIndex < remoteHosts.length; hostIndex++) {
      var host = remoteHosts[hostIndex]
      var threads = host.threads || []
      var changed = false
      var next = []
      for (var threadIndex = 0; threadIndex < threads.length; threadIndex++) {
        var thread = threads[threadIndex]
        if (String(thread && thread.id || "") === wanted && thread.unread === true) {
          next.push(Object.assign({}, thread, { unread: false }))
          changed = true
        } else next.push(thread)
      }
      if (changed) updateHost(host.id, { threads: next })
    }
  }

  function refresh(hostId) {
    if (!configLoaded) return
    var wanted = String(hostId || "")
    var queue = queryQueue.slice()
    function append(id) {
      if (id === queryHostId || queue.indexOf(id) >= 0) return
      queue.push(id)
      var host = hostById(id)
      updateHost(id, { loading: !(host && host.loaded === true), error: "" })
    }
    if (wanted !== "") append(wanted)
    else for (var i = 0; i < remoteHosts.length; i++) append(String(remoteHosts[i].id || ""))
    queryQueue = queue
    startNextQuery()
  }

  function refreshVisibleProvider() {
    if (!controller.sidebarOpen) {
      refresh()
      return
    }
    var selected = String(controller.selectedProvider || "codex").toLowerCase()
    for (var i = 0; i < remoteHosts.length; i++) {
      var hostProvider = providerTypeForEntry(remoteHosts[i]) || "codex"
      if (hostProvider === selected) refresh(remoteHosts[i].id)
    }
  }

  function startNextQuery() {
    if (controller.shuttingDown || queryProcess.running || queryQueue.length === 0) return
    var queue = queryQueue.slice()
    queryHostId = String(queue.shift() || "")
    queryQueue = queue
    if (queryHostId === "" || !hostById(queryHostId)) {
      queryHostId = ""
      Qt.callLater(root.startNextQuery)
      return
    }
    queryProcess.command = [queryHelperPath, configPath, queryHostId, "snapshot"]
    queryProcess.running = true
  }

  function applySnapshot(snapshot) {
    var hostId = String(snapshot && snapshot.hostId || "")
    if (hostId === "") return
    var existing = hostById(hostId)
    if (!existing) return
    var snapshotThreads = Array.isArray(snapshot.threads) ? snapshot.threads : []
    var hiddenArchiveId = hostId === actionHostId ? archivedThreadId
      : (hostId === archiveConfirmationHostId ? archiveConfirmationThreadId : "")
    var visibleThreads = threadsWithoutId(snapshotThreads, hiddenArchiveId)
    updateHost(hostId, {
      home: String(snapshot.home || existing.home || ""),
      providerType: providerTypeForEntry(snapshot),
      threads: mergeUnread(existing, visibleThreads),
      projects: Array.isArray(snapshot.projects) ? snapshot.projects : [],
      projectDefaults: snapshot.projectDefaults && typeof snapshot.projectDefaults === "object"
        ? snapshot.projectDefaults : ({}),
      projectAgents: snapshot.projectAgents && typeof snapshot.projectAgents === "object"
        ? snapshot.projectAgents : ({}),
      models: Array.isArray(snapshot.models) ? snapshot.models : [],
      agents: Array.isArray(snapshot.agents) ? snapshot.agents : [],
      defaultModel: String(snapshot.defaultModel || ""),
      defaultEffort: String(snapshot.defaultEffort || ""),
      defaultAgent: String(snapshot.defaultAgent || ""),
      available: snapshot.available !== false,
      authenticated: snapshot.authenticated !== false,
      version: String(snapshot.version || ""),
      subscriptionType: String(snapshot.subscriptionType || ""),
      loaded: true,
      loading: false,
      error: String(snapshot.error || "")
    })
    if (hostId === archiveConfirmationHostId) {
      archiveConfirmationHostId = ""
      archiveConfirmationThreadId = ""
    }
    resolvePendingNew(hostId)
  }

  function threadIndex(items, threadId) {
    var wanted = String(threadId || "")
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") === wanted) return i
    }
    return -1
  }

  function threadsWithoutId(items, threadId) {
    var wanted = String(threadId || "")
    if (wanted === "") return items.slice()
    var visible = []
    for (var i = 0; i < items.length; i++) {
      if (String(items[i] && items[i].id || "") !== wanted) visible.push(items[i])
    }
    return visible
  }

  function add(label, type, address, home, tokenFile, providerType) {
    addError = ""
    var name = String(label || "").trim()
    var agentProvider = String(providerType || "codex").toLowerCase() === "claude"
      ? "claude" : "codex"
    var connectionType = agentProvider === "claude"
      ? "ssh" : (type === "app-server" ? "app-server" : "ssh")
    var endpoint = String(address || "").trim()
    var remoteHome = String(home || "").trim()
    var localTokenFile = String(tokenFile || "").trim()
    if (name === "") {
      addError = "Adj nevet a remote gépnek"
      return ""
    }
    if (connectionType === "ssh") {
      if (!/^[A-Za-z0-9_.@:-]+$/.test(endpoint)) {
        addError = "Érvénytelen SSH host vagy alias"
        return ""
      }
    } else if (endpoint.indexOf("ws://") !== 0 && endpoint.indexOf("wss://") !== 0) {
      addError = "Az App Server címe ws:// vagy wss:// legyen"
      return ""
    }

    var baseId = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    if (baseId === "") baseId = "remote"
    var id = baseId
    var suffix = 2
    while (hostById(id)) id = baseId + "-" + suffix++

    var entry = { id: id, label: name, type: connectionType, home: remoteHome }
    if (agentProvider === "claude") entry.providerType = "claude"
    if (connectionType === "ssh") {
      entry.sshHost = endpoint
      if (agentProvider === "claude") entry.claudeCommand = "claude"
      else entry.codexCommand = "codex"
    } else {
      entry.url = endpoint
      entry.authTokenEnv = ""
      entry.authTokenFile = localTokenFile
    }

    var nextConfig = {
      version: 2,
      remotes: (remoteConfig.remotes || []).concat([entry])
    }
    var serialized = JSON.stringify(nextConfig, null, 2) + "\n"
    configFile.setText(serialized)
    Qt.callLater(root.secureConfigFile)
    loadConfig(serialized)
    return id
  }

  function sshHostEnabled(alias, providerType) {
    var wanted = String(alias || "")
    var wantedProvider = String(providerType || "codex").toLowerCase() === "claude"
      ? "claude" : ""
    var configured = remoteConfig.remotes || []
    for (var i = 0; i < configured.length; i++) {
      var remote = configured[i] || ({})
      if (remote.type === "ssh" && String(remote.sshHost || "") === wanted
          && providerTypeForEntry(remote) === wantedProvider) return true
    }
    return false
  }

  function refreshSshHosts() {
    if (controller.shuttingDown || sshHostsProcess.running) return
    sshHostsLoading = true
    sshHostsError = ""
    sshHostsProcess.command = [sshHostsHelperPath]
    sshHostsProcess.running = true
  }

  function archiveThread(hostId, thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running) return
    controller.archivingThreadId = id
    controller.launchError = ""
    actionHostId = String(hostId || "")
    actionKind = "archive"
    actionThreadId = id
    var host = hostById(actionHostId)
    archivedThreadId = id
    archivedThreadSnapshot = thread
    archivedThreadIndex = host ? threadIndex(host.threads, id) : -1
    if (host) updateHost(actionHostId, { threads: threadsWithoutId(host.threads, id) })
    actionProcess.command = [queryHelperPath, configPath, actionHostId, "archive", id]
    actionProcess.running = true
  }

  function toggleThreadPin(hostId, thread) {
    var id = String(thread && thread.id || "")
    if (id === "" || actionProcess.running || controller.pinningThreadId !== "") return
    actionHostId = String(hostId || "")
    actionKind = "pin"
    actionThreadId = id
    actionPinValue = thread.isPinned !== true
    controller.pinningThreadId = id
    controller.launchError = ""
    actionProcess.command = [
      queryHelperPath,
      configPath,
      actionHostId,
      "pin",
      id,
      actionPinValue ? "true" : "false"
    ]
    actionProcess.running = true
  }

  function applyThreadPin(hostId, threadId, pinned, returnedThread) {
    var host = hostById(hostId)
    if (!host) return
    var next = []
    for (var i = 0; i < host.threads.length; i++) {
      var thread = host.threads[i]
      next.push(String(thread && thread.id || "") === String(threadId || "")
        ? Object.assign({}, thread, returnedThread || ({}), { isPinned: !!pinned })
        : thread)
    }
    updateHost(hostId, { threads: next })
  }

  function restoreArchivedThread(hostId) {
    var host = hostById(hostId)
    if (host && archivedThreadSnapshot && threadIndex(host.threads, archivedThreadId) < 0) {
      var restored = host.threads.slice()
      var index = Math.max(0, Math.min(archivedThreadIndex, restored.length))
      restored.splice(index, 0, archivedThreadSnapshot)
      updateHost(hostId, { threads: restored })
    }
    archivedThreadId = ""
    archivedThreadSnapshot = null
    archivedThreadIndex = -1
  }

  function openThread(hostId, thread, path) {
    if (!thread || !thread.id || openProcess.running) return
    var host = hostById(hostId)
    if (!host) return
    if (providerTypeForEntry(host) === "claude" && host.available === false) {
      controller.launchError = host.error || "Claude is unavailable on this remote"
      return
    }
    var providerType = providerTypeForEntry(host) || "codex"
    openIsNew = false
    openHostId = String(hostId || "")
    controller.launchingThreadId = String(thread.id)
    controller.launchError = ""
    openProcess.command = [
      openHelperPath,
      configPath,
      String(hostId || ""),
      String(path || thread.cwd || ""),
      controller.launchingThreadId,
      controller.selectedModelForProvider(providerType),
      controller.selectedEffortForProvider(providerType),
      controller.selectedAgentForProvider(providerType)
    ]
    openProcess.running = true
    controller.threadLaunchRequested(controller.launchingThreadId)
  }

  function newThread(hostId, path) {
    if (openProcess.running) return
    var host = hostById(hostId)
    if (!host) return
    if (providerTypeForEntry(host) === "claude" && host.available === false) {
      controller.launchError = host.error || "Claude is unavailable on this remote"
      return
    }
    var providerType = providerTypeForEntry(host) || "codex"
    var remotePath = String(path || host.home || "")
    if (remotePath === "") {
      controller.launchError = "A remote home még nem ismert; add meg az R-es beállításnál"
      return
    }
    openIsNew = true
    openHostId = String(hostId || "")
    controller.launchingProjectPath = remotePath
    pendingHostId = String(hostId || "")
    pendingPath = remotePath
    pendingWindowAddress = ""
    pendingAttempts = 24
    pendingKnownIds = ({})
    for (var i = 0; i < host.threads.length; i++) {
      if (host.threads[i] && host.threads[i].id)
        pendingKnownIds[String(host.threads[i].id)] = true
    }
    controller.launchError = ""
    openProcess.command = [
      openHelperPath,
      configPath,
      pendingHostId,
      pendingPath,
      "",
      controller.selectedModelForProvider(providerType),
      controller.selectedEffortForProvider(providerType),
      controller.selectedAgentForProvider(providerType)
    ]
    openProcess.running = true
  }

  function clearPendingNew() {
    openIsNew = false
    openHostId = ""
    pendingHostId = ""
    pendingPath = ""
    pendingKnownIds = ({})
    pendingWindowAddress = ""
    pendingAttempts = 0
    controller.launchingProjectPath = ""
    newResolveTimer.stop()
  }

  function resolvePendingNew(hostId) {
    if (pendingHostId === "" || pendingHostId !== String(hostId || "")
        || pendingWindowAddress === "") return
    var host = hostById(pendingHostId)
    if (!host) return
    for (var i = 0; i < host.threads.length; i++) {
      var thread = host.threads[i]
      var id = String(thread && thread.id || "")
      if (id === "" || pendingKnownIds[id] === true) continue
      if (pathForThread(host, thread) !== pendingPath
          && String(thread.cwd || "") !== pendingPath) continue
      if (!mapThreadWindowProcess.running) {
        mapThreadWindowProcess.command = [
          mapThreadWindowHelperPath,
          id,
          pendingWindowAddress,
          pendingHostId
        ]
        mapThreadWindowProcess.running = true
      }
      controller.activeThreadId = id
      clearPendingNew()
      return
    }
  }

  Process {
    id: queryProcess
    running: false

    onExited: function(exitCode) {
      var hostId = root.queryHostId
      if (exitCode !== 0) {
        var failedHost = root.hostById(hostId)
        root.updateHost(hostId, {
          loading: false,
          error: queryStderr.text.trim()
            || "Could not load remote " + root.providerLabel(failedHost) + " threads"
        })
      } else {
        try {
          root.applySnapshot(JSON.parse(String(queryStdout.text || "{}").trim()))
        } catch (error) {
          root.updateHost(hostId, { loading: false, error: "Invalid remote response" })
        }
      }
      root.queryHostId = ""
      Qt.callLater(root.startNextQuery)
    }

    stdout: StdioCollector { id: queryStdout; waitForEnd: true }
    stderr: StdioCollector { id: queryStderr; waitForEnd: true }
  }

  Process {
    id: actionProcess
    running: false

    onExited: function(exitCode) {
      var hostId = root.actionHostId
      var kind = root.actionKind
      if (exitCode !== 0) {
        var failedHost = root.hostById(hostId)
        root.controller.launchError = actionStderr.text.trim()
          || "Remote " + root.providerLabel(failedHost) + " action failed"
        if (kind === "archive") root.restoreArchivedThread(hostId)
      } else if (kind === "archive") {
        root.archiveConfirmationHostId = hostId
        root.archiveConfirmationThreadId = root.archivedThreadId
        root.archivedThreadId = ""
        root.archivedThreadSnapshot = null
        root.archivedThreadIndex = -1
      } else if (kind === "pin") {
        var response = null
        try {
          response = JSON.parse(String(actionStdout.text || "{}").trim())
        } catch (error) {
          response = null
        }
        root.applyThreadPin(hostId, root.actionThreadId, root.actionPinValue,
          response ? response.thread : null)
      }
      if (kind === "archive") root.controller.archivingThreadId = ""
      if (kind === "pin") root.controller.pinningThreadId = ""
      root.actionHostId = ""
      root.actionKind = ""
      root.actionThreadId = ""
      root.actionPinValue = false
      if (exitCode === 0) root.refresh(hostId)
    }

    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
  }

  Process {
    id: openProcess
    running: false

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var failedHost = root.hostById(root.openHostId)
        root.controller.launchError = openStderr.text.trim()
          || "Could not open remote " + root.providerLabel(failedHost)
        root.controller.launchingThreadId = ""
        if (root.openIsNew) root.clearPendingNew()
        else root.openHostId = ""
        return
      }
      var output = String(openStdout.text || "").trim()
      var address = output
      var runtimeSessionId = ""
      try {
        var result = JSON.parse(output)
        address = String(result.address || "")
        runtimeSessionId = String(result.sessionId || "")
      } catch (error) {
        // Compatibility with the older remote helper which returned only an address.
      }
      if (root.openIsNew) {
        if (runtimeSessionId !== "" && address !== "") {
          mapThreadWindowProcess.command = [
            root.mapThreadWindowHelperPath,
            runtimeSessionId,
            address,
            root.pendingHostId
          ]
          mapThreadWindowProcess.running = true
          root.controller.activeThreadId = runtimeSessionId
          root.clearPendingNew()
        } else {
          root.pendingWindowAddress = address
          root.refresh(root.pendingHostId)
          newResolveTimer.restart()
        }
      } else {
        root.controller.activeThreadId = root.controller.launchingThreadId
        root.controller.launchingThreadId = ""
        root.openHostId = ""
      }
      root.controller.refreshActiveThread()
    }

    stdout: StdioCollector { id: openStdout; waitForEnd: true }
    stderr: StdioCollector { id: openStderr; waitForEnd: true }
  }

  Process { id: mapThreadWindowProcess; running: false }

  Connections {
    target: root.controller
    function onActiveThreadIdChanged() {
      root.markThreadSeen(root.controller.activeThreadId)
    }
  }

  Process {
    id: sshHostsProcess
    running: false

    onExited: function(exitCode) {
      root.sshHostsLoading = false
      if (exitCode !== 0) {
        root.sshHosts = []
        root.sshHostsError = sshHostsStderr.text.trim() || "Az SSH hostok nem olvashatók"
        return
      }
      try {
        var parsed = JSON.parse(String(sshHostsStdout.text || "[]").trim())
        root.sshHosts = Array.isArray(parsed) ? parsed : []
        root.sshHostsError = ""
      } catch (error) {
        root.sshHosts = []
        root.sshHostsError = "Érvénytelen SSH config válasz"
      }
    }

    stdout: StdioCollector { id: sshHostsStdout; waitForEnd: true }
    stderr: StdioCollector { id: sshHostsStderr; waitForEnd: true }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadPrimaryConfig(text())
    onLoadFailed: root.initializeConfig("")
  }

  Process {
    id: configPermissionsProcess
    running: false
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

  Component.onDestruction: {
    queryProcess.running = false
    actionProcess.running = false
    openProcess.running = false
    sshHostsProcess.running = false
  }
}
