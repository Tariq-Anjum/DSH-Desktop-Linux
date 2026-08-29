# Session 02 — Cordis Plugin Contract, Capability Registry & Lifecycle

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop`.
> Read `00_MASTER_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal
Strengthen the existing Cordis plugin composition model into a well-defined desktop capability system without replacing Cordis.

### Tasks
1. Inventory the existing `dsh-plugin-desktop` plugin loading/profile APIs.
2. Define a desktop-owned plugin contract compatible with current Cordis loading. Required metadata: id, version, API version, capabilities, permissions, dependencies, commands, UI contributions, settings schema, lifecycle health.
3. Define typed capability IDs such as `fs.read`, `fs.write`, `process.exec`, `terminal.pty`, `browser.navigate`, `browser.interact`, `screen.capture`, `git`, `scheduler`, `context.read`, `context.write`.
4. Build a capability registry/broker. Plugins request named capabilities; they do not get unrestricted host objects.
5. Add dependency ordering, cycle detection, optional dependency handling, health state, and deterministic cleanup.
6. Preserve the existing persistent plugin enable/disable state and extend it only where needed.
7. Add plugin manifest validation and a compatibility check against the desktop plugin API version.
8. Add tests for registration, dependency ordering, hot disable/enable, malformed manifests, capability denial, cleanup, and failure recovery.

### Important constraints
- Do not create a second plugin system beside Cordis.
- Do not move upstream code.
- Do not make every UI component a separate package unless it has meaningful independent lifecycle/configuration value.

### Deliverables
- typed plugin contract
- capability registry/broker
- validation and dependency resolver
- compatibility tests
- plugin authoring guide

### Commit
`git add . && git commit -m "feat: formalize cordis plugin capabilities"`


## Agent operating rules
- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
