import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Item {
  id: root

  required property var panel
  readonly property var service: panel.service
  readonly property string providerType: panel.activeProvider
  readonly property var contextHost: {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    if (providerType !== "codex" && row && row.host
        && String(row.host.providerType || "") === providerType) return row.host
    return providerType !== "codex" ? panel.activeProviderHost : null
  }
  readonly property string contextPath: {
    var row = panel.selectedIndex >= 0 && panel.selectedIndex < panel.viewRows.length
      ? panel.viewRows[panel.selectedIndex] : null
    return String(row && row.path || "")
  }

  function contextDefaults() {
    var values = contextHost && contextHost.projectDefaults
    return values && typeof values === "object" && values[contextPath]
      ? values[contextPath] : (contextHost || ({}))
  }
  implicitWidth: Style.space(148)
  implicitHeight: Style.space(22)

  function compactModelLabel(value) {
    var label = String(value || "default")
    if (label === "") return "default"
    var parts = label.replace(/^(gpt|claude)-/i, "").replace(/-/g, " ").split(" ")
    for (var i = 0; i < parts.length; i++) {
      if (/^[a-z]/.test(parts[i]))
        parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1)
    }
    return parts.join(" ")
  }

  function effectiveModelLabel() {
    if (providerType === "codex")
      return compactModelLabel(service.effectiveModel() || "gpt-5.6-sol")
    var selected = selectedModel()
    var defaults = contextDefaults()
    var effective = selected !== "" ? selected
      : String(defaults.defaultModel || defaults.model || "")
    return compactModelLabel(effective || "default")
  }

  function effectiveEffortLabel() {
    var effort = providerType === "codex"
      ? String(service.effectiveEffort() || "medium")
      : String(selectedEffort() || contextDefaultEffort())
    if (effort === "") return ""
    return effort.charAt(0).toUpperCase() + effort.slice(1)
  }

  function selectorText() {
    var parts = [effectiveModelLabel()]
    var effort = effectiveEffortLabel()
    if (effort !== "") parts.push(effort)
    var agent = effectiveAgent()
    if (agent !== "") parts.push("@" + agent)
    return parts.join(" ") + " ▾"
  }

  function modelChoices() {
    var defaults = contextDefaults()
    var defaultModel = providerType === "codex" ? service.defaultModelForProvider(providerType)
      : String(defaults.defaultModel || defaults.model || "")
    var result = [{
      id: "",
      label: "default" + (defaultModel !== ""
        ? " · " + compactModelLabel(defaultModel) : "")
    }]
    var entries = providerType !== "codex" && contextHost
        && Array.isArray(contextHost.models)
      ? contextHost.models : service.modelsForProvider(providerType)
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i] || ({})
      var id = String(entry.model || entry.id || "")
      if (id === "") continue
      result.push({
        id: id,
        label: String(entry.displayName || entry.name || id),
        isDefault: entry.isDefault === true
      })
    }
    return result
  }

  function effortChoices() {
    var defaultEffort = contextDefaultEffort()
    var result = [{
      id: "",
      label: "default" + (defaultEffort !== "" ? " · " + defaultEffort : "")
    }]
    var efforts = contextModelEfforts(service.selectedModelForProvider(providerType))
    for (var i = 0; i < efforts.length; i++)
      result.push({ id: efforts[i], label: efforts[i] })
    return result
  }

  function agentChoices() {
    var defaultAgent = contextDefaultAgent()
    var result = [{
      id: "",
      label: "default" + (defaultAgent !== "" ? " · @" + defaultAgent : "")
    }]
    var agents = contextAgentEntries()
    for (var i = 0; i < agents.length; i++) {
      var id = String(agents[i] && agents[i].id || "")
      if (id !== "") result.push({ id: id, label: String(agents[i].name || id) })
    }
    return result
  }

  function selectedModel() { return service.selectedModelForProvider(providerType) }
  function selectedEffort() { return service.selectedEffortForProvider(providerType) }
  function selectedAgent() { return service.selectedAgentForProvider(providerType) }

  function contextAgentEntries() {
    if (providerType === "claude" && contextHost) {
      var scoped = contextHost.projectAgents
      if (scoped && typeof scoped === "object" && Array.isArray(scoped[contextPath]))
        return scoped[contextPath]
    }
    return contextHost && Array.isArray(contextHost.agents)
      ? contextHost.agents : service.agentsForProvider(providerType)
  }

  function contextDefaultAgent() {
    if (providerType !== "claude") return ""
    var defaults = contextDefaults()
    return String(defaults.defaultAgent || defaults.agent || "")
  }

  function effectiveAgent() {
    return selectedAgent() || contextDefaultAgent()
  }

  function hasAgentChoices() {
    return (providerType === "claude" || providerType === "opencode")
      && (contextAgentEntries().length > 0 || contextDefaultAgent() !== "")
  }

  function contextModelEfforts(modelId) {
    if (providerType === "codex" || !contextHost)
      return service.modelEffortsForProvider(providerType, modelId)
    var wanted = String(modelId || "")
    if (wanted === "") return service.modelEffortsForProvider(providerType, "")
    var entries = Array.isArray(contextHost.models) ? contextHost.models : []
    for (var i = 0; i < entries.length; i++) {
      if (String(entries[i] && entries[i].id || "") === wanted)
        return Array.isArray(entries[i].efforts) ? entries[i].efforts : []
    }
    return []
  }

  function contextDefaultEffort() {
    if (providerType === "codex")
      return service.defaultEffortForProvider(providerType, selectedModel())
    var selected = selectedModel()
    if (selected !== "" && contextHost) {
      var entries = Array.isArray(contextHost.models) ? contextHost.models : []
      for (var i = 0; i < entries.length; i++) {
        if (String(entries[i] && entries[i].id || "") === selected)
          return String(entries[i].defaultEffort || "")
      }
    }
    var defaults = contextDefaults()
    return String(defaults.defaultEffort || defaults.effort || "")
  }

  Text {
    id: selectorLabel
    anchors.fill: parent
    text: root.selectorText()
    color: selectorMouse.containsMouse || picker.opened
      ? panel.foreground : Util.alpha(panel.foreground, 0.48)
    font.family: panel.fontFamily
    font.pixelSize: Math.max(8, Style.font.caption - 1)
    horizontalAlignment: Text.AlignRight
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideLeft
  }

  MouseArea {
    id: selectorMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: picker.opened ? picker.close() : picker.open()
  }

  Popup {
    id: picker
    x: root.width - width
    y: -height - Style.space(4)
    width: Style.space(230)
    padding: Style.space(4)
    modal: true
    dim: false
    focus: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: BorderSurface {
      color: Color.background
      borderSpec: Border.flat(panel.dim, 1)
      radius: Style.cornerRadius
    }

    contentItem: Column {
      spacing: 0

      Text {
        width: parent.width
        height: Style.space(26)
        leftPadding: Style.space(9)
        text: "MODEL"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: root.modelChoices()

        delegate: Rectangle {
          id: modelChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: modelMouse.containsMouse ? panel.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.right: modelCheck.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: modelChoice.modelData.label
              + (modelChoice.modelData.isDefault ? "  · recommended" : "")
            color: root.selectedModel() === modelChoice.modelData.id
              ? Color.accent : panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: modelCheck
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedModel() === modelChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: modelMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.service.setModelForProvider(
              root.providerType, modelChoice.modelData.id)
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: panel.faint
      }

      Text {
        width: parent.width
        height: Style.space(26)
        leftPadding: Style.space(9)
        text: "EFFORT"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: root.effortChoices()

        delegate: Rectangle {
          id: effortChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: effortMouse.containsMouse ? panel.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: effortChoice.modelData.label
            color: root.selectedEffort() === effortChoice.modelData.id
              ? Color.accent : panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedEffort() === effortChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: effortMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.service.setEffortForProvider(
                root.providerType, effortChoice.modelData.id)
              picker.close()
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: root.hasAgentChoices() ? 1 : 0
        visible: root.hasAgentChoices()
        color: panel.faint
      }

      Text {
        width: parent.width
        height: visible ? Style.space(26) : 0
        visible: root.hasAgentChoices()
        leftPadding: Style.space(9)
        text: "AGENT"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Math.max(8, Style.font.caption - 1)
        font.bold: true
        verticalAlignment: Text.AlignVCenter
      }

      Repeater {
        model: root.hasAgentChoices() ? root.agentChoices() : []

        delegate: Rectangle {
          id: agentChoice
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.cornerRadius
          color: agentMouse.containsMouse ? panel.faint : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: agentChoice.modelData.label
            color: root.selectedAgent() === agentChoice.modelData.id
              ? Color.accent : panel.foreground
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(9)
            anchors.verticalCenter: parent.verticalCenter
            text: root.selectedAgent() === agentChoice.modelData.id ? "✓" : ""
            color: Color.accent
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: agentMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.service.setAgentForProvider(
                root.providerType, agentChoice.modelData.id)
              picker.close()
            }
          }
        }
      }
    }
  }
}
