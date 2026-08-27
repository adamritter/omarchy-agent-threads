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
  delegated to focused stores under `services/`.
- `providers/` owns provider transports, helper processes, and normalization.
- `ui/ThreadListModel.qml` adapts service state to `ThreadListLogic`; it does
  not implement grouping or sorting itself.
- `ui/CodexThreadList.qml` owns scrolling. `ThreadListRow.qml` and the context
  menu components own row presentation and row-local interaction.
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
