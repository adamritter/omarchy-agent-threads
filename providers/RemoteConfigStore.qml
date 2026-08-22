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

  function initialize(raw) {
    if (loaded) return
    var text = String(raw || "").trim()
    if (text === "") {
      text = JSON.stringify({ version: 1, remotes: [] }, null, 2)
      configFile.setText(text + "\n")
      Qt.callLater(root.secure)
    }
    load(text + "\n")
  }

  function loadPrimary(raw) {
    if (loaded) load(raw)
    else initialize(raw)
    secure()
  }

  function secure() {
    if (permissionsProcess.running) return
    permissionsProcess.command = ["chmod", "600", path]
    permissionsProcess.running = true
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
    configFile.setText(serialized)
    Qt.callLater(root.secure)
    load(serialized)
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

  FileView {
    id: configFile
    path: root.path
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadPrimary(text())
    onLoadFailed: root.initialize("")
  }

  Process { id: permissionsProcess; running: false }
}
