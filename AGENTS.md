# Project language

- Use English for all user-facing text, documentation, comments, errors, logs, tests, commit messages, and contributor-facing instructions.
- Do not add Hungarian or mixed-language copy. Preserve technical names, commands, paths, and upstream product terminology as written by their owners.

# QML test execution

- Always run `qmltestrunner` outside the sandbox with host-level execution.
  The sandbox does not provide the required Wayland/display and local socket
  access, so `qmltestrunner` can abort and create a misleading coredump
  notification.
- Apply this rule to commands that invoke `qmltestrunner` indirectly as well,
  including plugin validation and aggregate test scripts.
- Use `./scripts/test-unit` instead of resolving `qmltestrunner` directly. The
  unqualified system binary may be Qt 5, while Quickshell and this plugin use
  Qt 6; the script selects the matching Qt 6 runner and defaults pure tests to
  Qt's offscreen backend. Set `QML_TEST_PLATFORM=wayland` only for tests that
  intentionally render a visible window.

# Development loop

- Plugin code under this directory hot-reloads on save. Do not use
  `omarchy restart shell` as part of the normal edit-test loop.
- If a saved change does not appear, use `./scripts/reload-plugin`, which calls
  `omarchy-shell shell rescanPlugins` and then inspects plugin status.
- Only restart the complete shell when testing startup/shutdown behavior,
  recovering a stuck socket or child process, or reproducing a failure that
  remains after a plugin rescan. Qt caches imported QML directory listings, so
  adding or renaming component files in an already imported directory is also
  a valid one-restart exception. Editing existing files is not. A final
  release-level smoke test may include one full restart.
- Run the narrowest relevant test while iterating. Use `./scripts/test-unit`
  for QML logic/models, `./scripts/test-integration` for helper/provider tests,
  and `./scripts/check-static` for validation and linting.
- Run `./scripts/test` outside the sandbox before handoff. It includes static,
  integration, and QML unit checks.

# Testable architecture

- Put deterministic transformations and routing decisions in modules under
  `logic/`. Keep rendered controls, Quickshell services, process execution, and
  Wayland integration in their QML adapters.
- Add or update Qt Quick unit tests for extracted logic and QML models. Manual
  shell inspection supplements these tests; it does not replace them.
- Prefer adding focused coverage when changing `Panel.qml`,
  `services/ThreadStore.qml`, `ui/ThreadListModel.qml`, or provider state
  handling. These are high-coupling integration surfaces.
- Preserve the original QML ownership boundary: `Panel.qml` directly owns the
  bar button, layer-shell windows, focus lifecycle, overlays, and top-level
  coordination. `ui/CodexThreadList.qml` owns scrolling and rows, and
  `ui/SidebarController.qml` owns list actions.
- Run `tests/panel-render.test` outside the sandbox before and after any change
  to `Panel.qml` ownership, window bindings, overlay composition, or list
  wiring. It instantiates the real panel with fake data in Quickshell and
  verifies rendered rows, overlays, layer windows, recreation, and cleanup.
- Do not move layer-shell windows or overlay controls behind forwarded host
  properties without a live reload test. Detached plugin instances can retain
  stale windows or incorrectly visible overlays.
- Prefer extracting deterministic transformations into `logic/` over changing
  the QML window ownership tree.
