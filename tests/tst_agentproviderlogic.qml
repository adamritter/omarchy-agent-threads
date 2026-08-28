// Purpose: Verifies agentproviderlogic behavior with Qt Quick Test.
import QtQuick
import QtTest
import "../logic/AgentProviderLogic.js" as AgentProviderLogic

TestCase {
  name: "AgentProviderLogic"

  function test_normalizesProviderAndConnection() {
    var local = AgentProviderLogic.normalizeHost({
      id: "provider-claude",
      providerType: "CLAUDE",
      type: "provider"
    })
    compare(local.providerType, "claude")
    compare(local.connectionType, "local")

    var remote = AgentProviderLogic.normalizeHost({
      id: "build",
      providerType: "opencode",
      type: "ssh"
    })
    compare(remote.providerType, "opencode")
    compare(remote.connectionType, "ssh")
  }

  function test_exposesCapabilityDifferences() {
    var direct = AgentProviderLogic.normalizeHost({
      id: "codex-api",
      providerType: "codex",
      type: "app-server"
    })
    verify(direct.capabilities.directAppServer)
    verify(!direct.capabilities.filesystem)
    verify(!direct.capabilities.agents)

    var openCode = AgentProviderLogic.normalizeHost({
      id: "opencode-local",
      providerType: "opencode"
    })
    verify(openCode.capabilities.filesystem)
    verify(openCode.capabilities.agents)
  }

  function test_keepsExplicitCapabilities() {
    var host = AgentProviderLogic.normalizeHost({
      id: "limited",
      capabilities: { renameThread: false, customAction: true }
    })
    verify(!host.capabilities.renameThread)
    verify(host.capabilities.customAction)
    verify(host.capabilities.openThread)
  }

  function test_filtersDuplicateAndInvalidHosts() {
    var hosts = AgentProviderLogic.normalizeHosts([
      { id: "local", providerType: "claude" },
      { id: "local", providerType: "opencode" },
      { providerType: "codex" },
      null
    ])
    compare(hosts.length, 1)
    compare(hosts[0].providerType, "claude")
    compare(AgentProviderLogic.hostById(hosts, "local").id, "local")
    verify(AgentProviderLogic.hostById(hosts, "missing") === null)
  }

  function test_resolvesCodexModelDefaultsAndOverrides() {
    var models = [
      {
        model: "gpt-default",
        isDefault: true,
        defaultReasoningEffort: "medium",
        supportedReasoningEfforts: [
          { reasoningEffort: "low" },
          { reasoningEffort: "medium" },
          { reasoningEffort: "high" }
        ]
      },
      {
        model: "gpt-fast",
        defaultReasoningEffort: "low",
        supportedReasoningEfforts: ["low", "high"]
      }
    ]
    var defaults = AgentProviderLogic.modelState(models, ({}), "", "")
    compare(defaults.defaultModel, "gpt-default")
    compare(defaults.effectiveModel, "gpt-default")
    compare(defaults.defaultEffort, "medium")
    compare(defaults.effectiveEffort, "medium")
    compare(defaults.efforts, ["low", "medium", "high"])

    var configured = AgentProviderLogic.modelState(models, {
      model: "gpt-fast",
      model_reasoning_effort: "high"
    }, "", "")
    compare(configured.defaultModel, "gpt-fast")
    compare(configured.defaultEffort, "high")

    var selected = AgentProviderLogic.modelState(
      models, { model_reasoning_effort: "medium" }, "gpt-fast", "high")
    compare(selected.effectiveModel, "gpt-fast")
    compare(selected.defaultEffort, "low")
    compare(selected.effectiveEffort, "high")
  }

  function test_supportsGenericProviderModelShape() {
    var state = AgentProviderLogic.modelState([
      { id: "provider/model", isDefault: true, defaultEffort: "high", efforts: ["high"] }
    ], ({}), "", "")
    compare(state.defaultModel, "provider/model")
    compare(state.defaultEffort, "high")
    compare(state.efforts, ["high"])
  }
}
