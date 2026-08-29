# Session 09 — Scheduler, Git, Settings, And Recovery

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Vulkan And GPU Policy, Plugin Taxonomy And
> Contract) and the repository's `AGENTS.md` first.

## Goal

Finish the operational layer while keeping every optional UX feature plugin-controlled.

## Scheduler

- Reuse existing DSH jobs/scheduler services where possible.
- UI should create/pause/resume/delete schedules without directly owning privileged
  execution.
- Show next run, last result, failures, and policy status.

## Git

- Expose status/diff/commit/push actions through typed host capabilities.
- Confirm destructive Git operations.

## Settings

- Plugin settings schema and profile persistence.
- GPU backend preference:

  ```yaml
  graphics:
    mode: auto # auto | vulkan | accelerated | software
    requireVulkan: false
    effects: true
  ```

  `automatic` default; Vulkan preferred only when verified; fallback always available.
- Security mode, workspace roots, browser policy, telemetry, appearance, hotkeys.

## Operational Controls

- Diagnostics export
- Reset profile/plugin state
- Plugin recovery mode
- Visible disabled/failed plugin explanation

## Tests

- Scheduler lifecycle
- Git policy
- Settings migration
- Plugin state persistence
- Recovery boot

## Deliverables

- Scheduler plugin
- Git actions integration
- Settings/policy UI
- Recovery UX

## Commit

`feat: add scheduler git and operational controls`

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
