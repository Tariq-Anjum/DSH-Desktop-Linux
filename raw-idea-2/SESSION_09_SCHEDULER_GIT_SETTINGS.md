# Session 09 — Scheduler, Git Actions, Settings & Operational Controls

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop`.
> Read `00_MASTER_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal
Finish the operational layer while keeping every optional UX feature plugin-controlled.

### Scheduler
- Reuse existing DSH jobs/scheduler services where possible.
- UI should create/pause/resume/delete schedules without directly owning privileged execution.
- Show next run, last result, failures, and policy status.

### Git
- Expose status/diff/commit/push actions through typed host capabilities.
- Confirm destructive Git operations.

### Settings
- Plugin settings schema and profile persistence.
- GPU backend preference: `automatic` default; Vulkan preferred when verified; fallback available.
- security mode, workspace roots, browser policy, telemetry, appearance, hotkeys.

### Operational controls
- diagnostics export
- reset profile/plugin state
- plugin recovery mode
- visible disabled/failed plugin explanation

### Tests
- scheduler lifecycle
- Git policy
- settings migration
- plugin state persistence
- recovery boot

### Deliverables
- scheduler plugin
- Git actions integration
- settings/policy UI
- recovery UX

### Commit
`git add . && git commit -m "feat: add scheduler git and operational controls"`


## Agent operating rules
- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
