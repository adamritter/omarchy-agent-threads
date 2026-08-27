# Architecture

Agent Threads keeps runtime integration at the edges and deterministic state
transformations in plain JavaScript modules.

## Dependency direction

```text
logic/ -> services/ and providers/ -> ui/ -> Panel.qml
```

- `logic/` contains deterministic transformations and must not import
  Quickshell or execute processes.
- `services/ThreadStore.qml` is the stable UI-facing façade. Persistence is
  delegated to focused stores under `services/`; snapshot normalization,
  project lookup, and state transitions stay in deterministic logic modules.
- `providers/` owns provider transports, helper processes, and normalization.
- `ui/ThreadListModel.qml` adapts service state to `ThreadListLogic`; it does
  not implement grouping or sorting itself.
- `ui/CodexThreadList.qml` owns scrolling. `ThreadListRow.qml` owns core row
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
  A provider's internal helpers remain private behind one provider API.
- `services/ThreadStore.qml` owns application state and exposes grouped,
  UI-facing domain APIs. UI code must not depend on provider implementation
  objects through aliases or forwarding chains.
- `ui/` owns presentation and interaction. Components delegate state changes
  through domain APIs and receive the narrowest practical state and action
  dependencies.
- `Panel.qml` remains the composition root and direct owner of shell-sensitive
  objects. It coordinates domains but does not become their implementation.
- `app/` owns the standalone chat frontend and uses the same provider boundary
  without depending on panel internals.

A boundary is useful when it hides implementation details, enforces ownership,
or provides a meaningful lifecycle or test seam. A file that only renames or
forwards methods is not a boundary. Compatibility façades are temporary and
must state why they exist and when they can be removed.

Passing the complete `panel`, store, or provider object is acceptable at the
composition edge, but should not become the default dependency mechanism for
lower-level components. Prefer a cohesive state object or action API over a
service-locator-style object graph.

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
5. standalone chat frontend;
6. a final cross-project deletion, naming, and dependency audit.

Refactoring is complete only when behavior remains covered, each piece of
mutable state has one clear owner, callers cross a single domain boundary, and
the previous route has been removed. Smaller files, lower line counts, or more
components are not sufficient completion criteria on their own.

## Safe extension points

Add deterministic routing, filtering, sorting, and state transitions to an
existing or new module under `logic/`, with a Qt Quick unit test. Add process
or protocol integration under `providers/`, exposed through the stable
`ThreadStore` façade. Do not move layer-shell windows or overlays behind
forwarded host properties.

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

Static source checks supplement, but do not replace, executable contracts. New
changes to these paths must cover the outcome, including failure:

- row activation parity between pointer and keyboard;
- launch success, timeout, stale completion, and unchanged active state on
  failure;
- workspace changes during hot reload restoration;
- active-writer archive rejection before optimistic removal;
- Quickshell-native component loading for top-level windows.
