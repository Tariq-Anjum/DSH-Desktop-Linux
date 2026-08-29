# Session 04 — Desktop Shell And Plugin-Composed UI

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal

Improve the desktop interface while preserving DSH's existing functionality and making layout contributions plugin-composable.

## Target shell

- compact title/toolbar
- left: projects, sessions, workspaces
- center: conversation + active artifact/workspace
- right: optional inspector/agent telemetry/context
- bottom: terminal/status when enabled
- overlays: command palette, approvals, annotations

## Tasks

1. Inspect the current renderer and client UI before changing layout. Reuse existing primitives where possible.
2. Define a small set of stable UI contribution slots, not a slot for every widget.
3. Make panels resizable and persist layout per profile.
4. Add responsive compact mode and floating/popup mode only where existing architecture supports it cleanly.
5. Add a consistent design system: spacing, typography, elevation, focus states, keyboard navigation, reduced motion.
6. Keep plugin panels lazy-loaded; disabled plugins must not add runtime listeners or large bundles to startup.
7. Add a plugin/settings screen to enable/disable optional capabilities.
8. Add an always-visible security/agent status indicator and emergency-stop control.

## Performance rules

- no expensive animation loops by default
- no giant canvas just for decoration
- lazy load large editor/browser/terminal components
- measure renderer startup and interaction latency

## Deliverables

- refreshed shell
- layout persistence
- plugin slot contract
- keyboard navigation/accessibility baseline

## Commit

`git add . && git commit -m "feat: refresh desktop shell and plugin slots"`

## Agent operating rules

- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
