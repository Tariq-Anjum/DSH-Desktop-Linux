# Session 04 — Desktop Shell And Plugin-Composed UI

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (UI Model) and the repository's
> `AGENTS.md` first.

## Goal

Create stable UI slots and a polished, accessible, keyboard-first shell. Make core
panels independently composable where meaningful, with persistent layout and lazy
loading.

## Target Shell

```
┌──────────────────────────────────────────────────────────────┐
│ Command bar | Profile | GPU status | Commands | Security stop │
├─────────────┬──────────────────────────────┬─────────────────┤
│ Projects /  │ Conversation / Agent /       │ Inspector /     │
│ sessions /  │ active artifact/workspace    │ telemetry/context│
│ plugins     │                              │                 │
├─────────────┴──────────────────────────────┴─────────────────┤
│ Optional terminal / status / task progress / diagnostics      │
└──────────────────────────────────────────────────────────────┘
```

## Tasks

1. Inspect the current renderer and client UI before changing layout. Reuse existing
   primitives where possible.
2. Define a small, stable set of UI contribution slots, not a slot per widget. Target
   plugins: `ui-frame`, `ui-command-bar`, `ui-sidebar`, `ui-session-list`,
   `ui-conversation`, `ui-details`, `ui-command-palette`, `ui-status-bar`,
   `ui-settings`, `ui-plugin-manager`, `ui-agent-matrix`, `ui-artifact-canvas`.
3. Make panels resizable and persist layout per profile.
4. Add responsive compact mode and floating/popup mode only where existing architecture
   supports it cleanly.
5. Add a consistent design system: spacing, typography, elevation, focus states,
   keyboard navigation, reduced motion.
6. Keep plugin panels lazy-loaded; disabled plugins must not add runtime listeners or
   large bundles to startup.
7. Add a plugin/settings screen to enable/disable optional capabilities.
8. Add an always-visible security/agent status indicator and emergency-stop control.

## Performance Rules

- No expensive animation loops by default.
- No giant canvas just for decoration.
- Lazy load large editor/browser/terminal components.
- Measure renderer startup and interaction latency.

## UX Requirements

- Keyboard-first navigation and plugin-registered commands
- Resizable sidebar, inspector, and terminal with per-profile persistence
- Clear empty, loading, failure, disabled, and dependency-blocked states
- System/light/dark themes, reduced motion, high contrast, visible focus states
- Responsive compact behavior and sensible minimum window dimensions
- No hidden blocking modal for normal actions

## Tests

- Disable sidebar
- Disable inspector
- Disable command palette
- Disable visual effects
- Disable status bar
- Start with all optional UI plugins disabled
- Restore all plugins
- Verify settings persist
- Verify no stale UI or listener leakage

## Deliverables

- Refreshed shell
- Layout persistence
- Plugin slot contract
- Keyboard navigation/accessibility baseline

## Commit

`feat: refresh desktop shell and plugin slots`

## Agent Operating Rules

- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly
  recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
