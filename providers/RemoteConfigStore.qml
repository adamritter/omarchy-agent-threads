import QtQuick
import Quickshell.Io

Item {
  id: root

  required property var provider
  required property var controller
  required property var providerRegistry
  property bool loaded: false
  property var config: ({})
  readonly property string path: controller.stateHome + "/omarchy/codex-thread-remotes.json"
  readonly property string configHelper: Qt.resolvedUrl(
    "../bin/omarchy-agent-remote-config").toString().replace(/^file:\/\//, "")
  readonly property int maxConfigCharacters: 128 * 1024
  property string pendingWrite: ""
  property string persistedText: ""

  function requestRead() {
    if (configRead.running || configWrite.running || pendingWrite !== "") return
    configRead.running = true
  }

  function applyRead(raw) {
    var text = String(raw || "")
    if (text === "" || text === persistedText) return
    persistedText = text
    load(text)
  }

  function startWrite() {
    if (configWrite.running || pendingWrite === "") return
    var text = pendingWrite
    pendingWrite = ""
    configWrite.command = [configHelper, "write", path, text]
    configWrite.running = true
  }

  function load(raw) {
    var parsed = ({ version: 1, remotes: [] })
    try {
      var text = String(raw || "").trim()
      parsed = text === "" ? parsed : JSON.parse(text)
    } catch (error) {
      console.warn("Codex Threads: invalid remote config:", error)
      provider.addError = "Invalid remote config"
    }

    var configured = Array.isArray(parsed) ? parsed
      : (Array.isArray(parsed.remotes) ? parsed.remotes : [])
    var nextHosts = []
    for (var i = 0; i < configured.length; i++) {
      var entry = configured[i] || ({})
      var id = String(entry.id || "remote-" + (i + 1))
      var existing = provider.hostById(id)
      var providerType = providerRegistry.typeForEntry(entry)
      nextHosts.push(Object.assign({}, entry, {
        id: id,
        label: String(entry.label || id),
        providerType: providerType,
        type: providerType !== "" || entry.type === "ssh" ? "ssh" : "app-server",
        threads: existing ? existing.threads : [],
        projects: existing ? existing.projects : [],
        models: existing ? existing.models : [],
        agents: existing ? existing.agents : [],
        projectDefaults: existing ? existing.projectDefaults : ({}),
        projectAgents: existing ? existing.projectAgents : ({}),
        defaultModel: existing ? String(existing.defaultModel || "") : "",
        defaultEffort: existing ? String(existing.defaultEffort || "") : "",
        defaultAgent: existing ? String(existing.defaultAgent || "") : "",
        available: existing ? existing.available !== false : true,
        authenticated: existing ? existing.authenticated !== false : true,
        version: existing ? String(existing.version || "") : "",
        subscriptionType: existing ? String(existing.subscriptionType || "") : "",
        rateLimits: existing && existing.rateLimits ? existing.rateLimits : ({}),
        loaded: existing ? existing.loaded === true : false,
        loading: false,
        error: ""
      }))
    }

    config = { version: 2, remotes: configured }
    provider.remoteHosts = nextHosts
    loaded = true
    controller.startAppServer()
    provider.refresh()
  }

  function configuredById(hostId) {
    var wanted = String(hostId || "")
    var configured = config.remotes || []
    for (var i = 0; i < configured.length; i++) {
      if (String(configured[i] && configured[i].id || "") === wanted)
        return configured[i]
    }
    return null
  }

  function write(remotes) {
    var nextConfig = { version: 2, remotes: remotes }
    var serialized = JSON.stringify(nextConfig, null, 2) + "\n"
    if (serialized.length > maxConfigCharacters) {
      provider.addError = "Remote config is too large"
      return
    }
    pendingWrite = serialized
    load(serialized)
    startWrite()
  }

  function validate(name, connectionType, endpoint) {
    if (name === "") return "Enter a name for the remote machine"
    if (connectionType === "ssh" && !/^[A-Za-z0-9_.@:-]+$/.test(endpoint))
      return "Invalid SSH host or alias"
    if (connectionType === "app-server"
        && endpoint.indexOf("ws://") !== 0 && endpoint.indexOf("wss://") !== 0)
      return "The App Server address must start with ws:// or wss://"
    return ""
  }

  function buildEntry(id, existing, label, type, address, home, tokenFile, providerType) {
    var adapter = providerRegistry.adapter(providerType)
    var connectionType = adapter.connectionType(type)
    var name = String(label || "").trim()
    var endpoint = String(address || "").trim()
    var error = validate(name, connectionType, endpoint)
    if (error !== "") {
      provider.addError = error
      return null
    }

    var entry = Object.assign({}, existing || ({}), {
      id: id,
      label: name,
      type: connectionType,
      home: String(home || "").trim()
    })
    adapter.applyProviderFields(entry, existing, connectionType)
    if (connectionType === "ssh") {
      entry.sshHost = endpoint
      delete entry.url
      delete entry.authTokenEnv
      delete entry.authTokenFile
    } else {
      entry.url = endpoint
      entry.authTokenEnv = String(existing && existing.authTokenEnv || "")
      entry.authTokenFile = String(tokenFile || "").trim()
      delete entry.sshHost
    }
    return entry
  }

  function add(label, type, address, home, tokenFile, providerType) {
    provider.addError = ""
    var name = String(label || "").trim()
    var baseId = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    if (baseId === "") baseId = "remote"
    var id = baseId
    var suffix = 2
    while (provider.hostById(id)) id = baseId + "-" + suffix++
    var entry = buildEntry(id, null, label, type, address, home, tokenFile, providerType)
    if (!entry) return ""
    write((config.remotes || []).concat([entry]))
    return id
  }

  function update(hostId, label, type, address, home, tokenFile, providerType) {
    provider.addError = ""
    var id = String(hostId || "")
    var existing = configuredById(id)
    if (!existing) {
      provider.addError = "The remote no longer exists"
      return ""
    }
    var requestedProvider = String(providerType
      || providerRegistry.typeForEntry(existing) || "codex")
    var entry = buildEntry(
      id, existing, label, type, address, home, tokenFile, requestedProvider)
    if (!entry) return ""
    var configured = config.remotes || []
    var next = []
    for (var i = 0; i < configured.length; i++) {
      var candidate = configured[i] || ({})
      next.push(String(candidate.id || "") === id ? entry : candidate)
    }
    write(next)
    return id
  }

  Process {
    id: configRead
    command: [root.configHelper, "read", root.path]
    running: false
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var message = String(configReadStderr.text || "").trim()
        provider.addError = message || "Could not read remote config"
      }
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRead(text)
    }
    stderr: StdioCollector { id: configReadStderr; waitForEnd: true }
  }

  Process {
    id: configWrite
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) persistedText = String(command[3] || "")
      else {
        var message = String(configWriteStderr.text || "").trim()
        provider.addError = message || "Could not write remote config"
      }
      root.startWrite()
    }
    stderr: StdioCollector { id: configWriteStderr; waitForEnd: true }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.requestRead()
  }
}
