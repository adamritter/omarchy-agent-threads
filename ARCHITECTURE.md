# Architecture

Agent Threads keeps runtime integration at the edges and deterministic state
transformations in plain JavaScript modules. The sidebar and standalone chat
are separate feature roots.

## Dependency direction

```text
logic/ -> services/ and providers/ -> ui/ -> Panel.qml
chat/logic -> chat/providers -> chat/ui -> agent-chat.qml
```

- `logic/` contains deterministic transformations and must not import
  Quickshell or execute processes.
- `services/ThreadStore.qml` is the stable UI-facing façade. Persistence is
  delegated to focused stores under `services/`; snapshot normalization,
  project lookup, and state transitions stay in deterministic logic modules.
- `providers/` owns provider transports, helper processes, and normalization.
- `ui/ThreadListModel.qml` adapts service state to `ThreadListLogic`; it does
  not implement grouping or sorting itself.
- `ui/ThreadList.qml` owns scrolling. `ThreadListRow.qml` owns core row
  presentation, while `ThreadListRowActions.qml` owns its buttons and menus.
  The action layer is loaded by URL so adding it does not depend on QML type
  directory discovery during a live reload.
- `Panel.qml` directly owns the bar button, layer-shell window, focus lifecycle,
  overlays, IPC, and top-level coordination.

## Target architecture

The current decomposition into smaller files is an intermediate refactoring
stage, not a goal by itself. The target is a small number of strong domain
boundaries whose implementations can be understood, tested, and changed
without loading the complete repository.

Runtime dependencies should flow inward through one public boundary per
domain:

```text
Panel composition
  -> UI components and controllers
  -> ThreadStore domain APIs
  -> provider implementations
  -> process and protocol helpers

Each layer may use deterministic logic modules.
```

The intended boundaries are:

- `logic/` owns pure transformations and state transitions. It has no runtime
  dependencies and exposes values rather than mutable global state.
- `providers/` owns provider-specific protocol, process, and transport details.
  `AgentProviderLibrary.qml` composes the provider graph and exposes focused
  internal ports for routing, models, App Server operations, local providers,
  remotes, and local Codex lifecycle. `ThreadStore` APIs declare only the ports
  they consume; UI code never receives those implementation objects.
- `services/ThreadStore.qml` owns application state and exposes grouped,
  UI-facing domain APIs. UI code must not depend on provider implementation
  objects through aliases or forwarding chains.
- `ui/` owns presentation and interaction. Components delegate state changes
  through domain APIs and receive the narrowest practical state and action
  dependencies.
- `Panel.qml` remains the composition root and direct owner of shell-sensitive
  objects. It coordinates domains but does not become their implementation.
- `chat/` is the complete standalone Agent Chat feature boundary. Its `logic/`,
  `providers/`, `ui/`, `web/`, `bin/`, `native/`, and `tests/` directories do
  not depend on panel internals. The root `agent-chat.qml` and public
  `bin/omarchy-agent-chat` command remain stable compatibility entrypoints.

A boundary is useful when it hides implementation details, enforces ownership,
or provides a meaningful lifecycle or test seam. A file that only renames or
forwards methods is not a boundary. Compatibility façades are temporary and
must state why they exist and when they can be removed.

Passing the complete `panel`, store, or provider object is acceptable at the
composition edge, but should not become the default dependency mechanism for
lower-level components. Prefer a cohesive state object or action API over a
service-locator-style object graph.

## Operational change map

Start with the row that matches the requested behavior. Read the entry files,
then follow only the listed ownership chain until the authoritative state or
runtime owner is reached. Do not load every provider, controller, or UI file
for a provider-specific change.

The owner named below is the only layer that should write the relevant mutable
state. Adapters may translate values and controllers may route actions, but
neither should create a second source of truth.

| Requested change | Start here | Authoritative chain and owner | Focused verification |
| --- | --- | --- | --- |
| Sidebar structure, header, or body composition | `ui/SidebarMainContent.qml`, then `ui/SidebarHeader.qml` or `ui/SidebarBody.qml` | `Panel.qml` owns composition; `ui/PanelSessionState.qml` owns ephemeral panel state; durable preferences go through `services/ThreadStoreSettingsApi.qml` | `tests/panel-render.test`; the nearest sidebar QML test |
| Sidebar keys, global shortcuts, selection, or list actions | `ui/SidebarKeyRouter.qml`, `ui/PanelIpcHandler.qml`, `ui/PanelGlobalActions.qml`, `ui/SidebarController.qml` | Fixed global shortcuts enter through plugin IPC and are routed from live QML state; list actions go through the controller to `services/ThreadStoreThreadApi.qml`; selection remains in `ui/PanelSessionState.qml` | `tests/tst_globalactionlogic.qml`, `tests/tst_keycatcher.qml`, `tests/tst_sidebarcontroller.qml`, `tests/tst_sidebarnavigation.qml` |
| Thread filtering, grouping, ordering, or row derivation | `ui/ThreadListModel.qml`, then `logic/ThreadListLogic.js` and the relevant `ThreadList*Logic.js` module | `services/ThreadStore.qml` owns source collections; deterministic logic derives rows; the model exposes them to `ui/ThreadList.qml` | `tests/tst_threadlistmodel.qml`, `tests/tst_threadrowlogic.qml`, `tests/tst_presentationlogic.qml` |
| Thread row presentation or row actions | `ui/ThreadListRow.qml`, `ui/ThreadListRowActions.qml` | Rows display model values and delegate mutations through `ui/SidebarController.qml`; they do not write store or provider state | `tests/panel-render.test`, `tests/tst_threadrowlogic.qml`, `tests/tst_sidebarcontroller.qml` |
| Thread activation, launch, terminal focus, or resume | `services/ThreadStoreThreadApi.qml`, then `providers/ThreadLaunchCoordinator.qml` | `logic/ThreadLaunchLogic.js` decides routing; `providers/AgentProviderLibrary.qml` selects the provider; the selected provider and process host own runtime execution | `tests/tst_threadlaunchcoordinator.qml`, `tests/tst_remoteagentlaunch.qml`; `tests/thread-launch-focus.test`, `tests/codex-terminal-lifecycle.test` |
| Rename, archive, pin, delete, or bulk mutation | `services/ThreadStoreThreadApi.qml`, `services/ThreadStoreMutations.qml` | `logic/ThreadMutationLogic.js` defines deterministic transitions; the provider boundary performs external mutations; the next provider snapshot reconciles stored state | `tests/tst_threadmutationlogic.qml`, `tests/tst_sidebarcontroller.qml`; the affected provider integration test |
| Local Codex snapshots, models, rate limits, or account state | `providers/CodexAppServerClient.qml`, `providers/CodexAppServerResponseHandler.qml` | App-server responses are normalized through provider logic and exposed through `services/ThreadStoreProviderApi.qml`; `services/ProviderSnapshotStore.qml` owns persisted snapshots | `tests/app-server-transport.test`, `tests/thread-statuses.test`, `tests/tst_providersnapshotlogic.qml` |
| Claude or OpenCode behavior | `providers/LocalAgentProvider.qml`, `providers/LocalAgentProcessHost.qml`, then the matching `bin/agent-*-query` helper | `providers/AgentProviderLibrary.qml` exposes the common boundary; provider-specific parsing and execution stay private to that provider | `tests/claude-provider.test`; `tests/opencode-provider.test`, `tests/opencode-auth.test`, `tests/agent-launchers.test` |
| Remote hosts, remote snapshots, or remote actions | `providers/RemoteAgentProvider.qml`, then `RemoteAgentSnapshots.qml`, `RemoteAgentManagement.qml`, or `RemoteAgentProcessHost.qml` | `providers/RemoteConfigStore.qml` owns host configuration; remote adapters normalize provider data; the remote process host owns SSH execution | `tests/remote-codex.test`, `tests/remote-claude.test`, `tests/remote-opencode.test`, `tests/remote-config.test`, `tests/ssh-hosts.test` |
| Panel window, focus, workspace state, overlays, help, or shell lifecycle | `Panel.qml`, then the matching `ui/Panel*Controller.qml` or overlay | `Panel.qml` directly owns shell-sensitive objects; `ui/PanelRuntimeProcesses.qml` adapts Quickshell's native Hyprland state through `logic/WorkspaceStateLogic.js`; controllers coordinate behavior; deterministic decisions belong in the matching `logic/Panel*Logic.js` module | Run `tests/panel-render.test` before and after the change; run the matching panel logic/controller QML test, including `tests/tst_workspacestatelogic.qml` for workspace state |
| Preferences, model/effort/agent selection, cached snapshots, or reload-state restoration | `services/ThreadStoreSettingsApi.qml`, `services/SidebarPreferences.qml`, `services/ProviderSnapshotStore.qml`, `ui/PanelReloadController.qml`, `ui/SidebarReloadController.qml` | The settings API owns the UI-facing selection contract and delegates provider catalog resolution to `providers/AgentProviderModels.qml`; focused stores own durable data; `logic/PanelReloadStateLogic.js` defines capture and restore | `tests/tst_agentproviderlogic.qml`, `tests/tst_sidebarpreferences.qml`, `tests/tst_providersnapshotlogic.qml`, `tests/tst_panelreloadstatelogic.qml`, `tests/panel-render.test` |
| Standalone Agent Chat UI or conversation protocol | `chat/ui/ChatWindow.qml`, then the affected `chat/ui/Chat*` component | `chat/providers/CodexConversationClient.qml`, `CodexConversationOperations.qml`, and `CodexConversationResponseHandler.qml` own transport; `chat/logic/Conversation*Logic.js` owns deterministic protocol transformations | The matching `chat/tests/tst_chat*.qml` or `chat/tests/tst_codexconversation*.qml` test; `chat/tests/chat-launcher.test`, `chat/tests/chat-options.test`, `chat/tests/web-transcript.test` as applicable |
| Helper scripts, command construction, quoting, or validation | The matching executable under `bin/`, then its provider adapter | Keep helpers for untrusted streams, bounded file access, SSH, credentials, hooks, and independent process launch. Fixed local action routing and deterministic compositor transformations stay in QML/`logic/` instead of adding wrappers. | The matching integration test under `tests/`; `scripts/check-static` |

When a public boundary or ownership path changes, update this map in the same
commit. A stale map is worse than no map because it sends future changes
through obsolete paths.

### Reload and test scope

Saving the two manifest hot-reload boundary files has intentionally narrow
scope:

- `ui/SidebarKeyRouter.qml` reloads the `sidebar` component while preserving
  the panel, store, provider clients, and other long-lived state.
- `ui/SidebarMainContent.qml` reloads the `sidebarContent` component with the
  same preservation rules.

Editing a QML file imported below those boundaries usually causes an in-process
QML graph reload, because the imported component is not itself a manifest
boundary. If the saved change does not appear, run `./scripts/reload-plugin` and
let it validate the graph, wait for a new panel generation, and verify plugin
status. Do not restart the shell for an ordinary edit to an existing file.

Adding or renaming a QML component in an already imported directory can require
one complete shell restart because Qt caches directory listings. Panel startup,
shutdown, stuck socket or child-process recovery, and an explicit final release
smoke test are the other full-restart cases.

During iteration, run the narrowest test named in the map. Use
`./scripts/test-unit` for QML logic and models, `./scripts/test-integration` for
helpers and providers, and `./scripts/check-static` for validation. Run
`./scripts/test` outside the sandbox before handoff. Panel ownership, window
bindings, overlays, and list wiring additionally require
`tests/panel-render.test` before and after the edit.

### Trace discipline

- Start a UI change at the visible component or action, then trace inward to
  one public domain API and one state owner.
- Start a provider change at `AgentProviderLibrary.qml` only when the common
  contract changes. Otherwise open just the selected provider chain.
- Put a deterministic decision in `logic/` before adding branches to QML
  adapters, controllers, or process hosts.
- Do not bypass `ThreadStore` from UI code or expose provider implementation
  objects through new aliases.
- Do not duplicate derived values as mutable state merely to shorten a binding
  chain. Add a focused model or domain API when the chain itself is the problem.
- Treat completion as behavior plus deletion: redirect callers, remove the old
  route, run the focused checks, then run the full suite.

## Refactoring method

Boundary work and simplification happen together, one domain at a time. For
each domain:

1. Identify the state owner, runtime owner, and required public operations.
2. Define one small public API and executable behavioral contracts.
3. Move implementation behind that API without changing behavior.
4. Redirect all callers to the new boundary.
5. Delete replaced paths, aliases, duplicated state, and forwarding-only
   components immediately.
6. Run the narrowest relevant tests, then the full suite before handoff.

The preferred migration order is:

1. provider boundaries;
2. `ThreadStore` and its grouped domain APIs;
3. panel state and controllers;
4. sidebar and thread-list presentation;
5. standalone `chat/` feature;
6. a final cross-project deletion, naming, and dependency audit.

Refactoring is complete only when behavior remains covered, each piece of
mutable state has one clear owner, callers cross a single domain boundary, and
the previous route has been removed. Smaller files, lower line counts, or more
components are not sufficient completion criteria on their own.

## Safe extension points

Add sidebar routing, filtering, sorting, and state transitions to an existing
or new module under `logic/`, with a Qt Quick unit test. Add sidebar process or
protocol integration under `providers/`, exposed through the stable
`ThreadStore` façade. Keep standalone chat logic and protocol integration under
`chat/logic` and `chat/providers`. Do not move layer-shell windows or overlays
behind forwarded host properties.

New QML component files require a fresh shell import scan. Use
`scripts/reload-plugin` first; a complete shell restart is reserved for the
documented Qt directory-cache exception.

## Behavioral invariants

Folder boundaries do not replace runtime state contracts. Changes must preserve
the following invariants.

### Thread activation

- Pointer, keyboard, cycling, and IPC activation route through
  `ui/SidebarController.qml`.
- Row components and context menus select and delegate; they never mutate the
  store or call provider methods directly.
- `ThreadRowLogic.presentation` derives row state once at the controller
  boundary instead of letting rendered controls inspect store internals.
- Selection, pending launch, and confirmed active thread are separate states.
- A failed launch preserves the user's selected thread and reports an error.

### Launch lifecycle

`services/ThreadStore.qml` is the single writer for the thread launch state:

```text
idle -> launching(requestId, target, source) -> confirmed(target)
                                           \-> failed(target, error)
```

- Providers request a launch token before starting a process.
- Success or failure must present the same token; stale completions are ignored.
- `activeThreadId` changes only after a provider observes its launch
  postcondition. Helper exit code zero therefore means the target window was
  observed, not merely that a process was spawned.

### Thread mutations

- Archive, rename, and pin operations acquire the shared mutation boundary
  before changing UI state or starting provider work.
- Archive validates active-writer ownership before applying a tombstone.
- Every optimistic mutation has a provider-owned rollback and a normalized
  user-facing failure.

### Persistence and reload state

- Durable user preferences and ephemeral panel reload state remain separate.
- Reload selection and focus are scoped to the workspace that created the
  snapshot and are discarded after a real workspace change.
- Persistent frontend changes record their source and timestamp. The interactive
  shortcut requires `Super+Ctrl+A`; unmodified text input cannot change it.

## Required behavioral contracts

Executable contracts define these boundaries. New changes to these paths must
cover the outcome, including failure:

- row activation parity between pointer and keyboard;
- launch success, timeout, stale completion, and unchanged active state on
  failure;
- workspace changes during hot reload restoration;
- active-writer archive rejection before optimistic removal;
- Quickshell-native component loading for top-level windows.

## Test boundaries

Tests follow the same dependency boundaries as production code:

- `tests/tst_*.qml` exercises sidebar logic, models, and controllers;
  `chat/tests/tst_*.qml` exercises the standalone chat feature. Rendered
  interaction assertions belong in these behavioral tests rather than in
  source-text searches.
- `scripts/check-static` runs the plugin validator, language parsers and
  linters, plus the explicit maintained-file size limit. It does not infer
  runtime architecture from source-text patterns.
- Bash integration tests cover executable, Node, SSH, IPC, and real process
  boundaries. Bash launches these systems but does not emulate QML behavior.
- `tests/panel-render.test` first loads the real `Panel` type with Quickshell
  without instantiating a layer-shell window, then runs focused QML behavior
  tests. This catches cold import and `qmldir` failures safely.
- `PANEL_TEST_LIVE_WAYLAND=1 tests/panel-render.test` remains an isolated
  release smoke test for real layer mapping and destruction. It must not run
  during an active user session.
