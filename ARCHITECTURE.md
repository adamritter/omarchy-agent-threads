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
