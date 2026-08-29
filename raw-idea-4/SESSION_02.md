# Session 02 — Plugin Contract And Lifecycle

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Plugin Taxonomy And Contract) and the
> repository's `AGENTS.md` first.

## Goal

Formalize the desktop plugin manifest, dependency graph, lifecycle health, API-version
compatibility, persistent enablement, deterministic cleanup, and plugin authoring
documentation.

## Tasks

1. Inventory the existing `dsh-plugin-desktop` plugin loading/profile APIs.
2. Define a desktop-owned plugin contract compatible with current Cordis loading,
   matching this shape:

   ```ts
   interface DesktopPluginManifest {
     id: string
     version: string
     apiVersion: string
     kind: 'host' | 'client' | 'native' | 'hybrid'
     required: boolean
     enabledByDefault: boolean
     dependencies?: string[]
     optionalDependencies?: string[]
     capabilities?: string[]
     permissions?: string[]
     commands?: string[]
     slots?: string[]
     settingsNamespace?: string
     platforms?: Array<'linux' | 'win32' | 'darwin'>
   }
   ```

3. Define typed capability IDs, e.g.: `fs.read`, `fs.write`, `process.exec`,
   `terminal.pty`, `browser.navigate`, `browser.interact`, `screen.capture`, `git.read`,
   `git.write`, `scheduler.manage`, `context.read`, `context.write`, `diagnostics.read`.
4. Build a capability registry/broker. Plugins request named capabilities; they do not
   get unrestricted host objects.
5. Add dependency ordering, cycle detection, optional dependency handling, health state,
   and deterministic cleanup.
6. Preserve the existing persistent plugin enable/disable state and extend it only where
   needed.
7. Add plugin manifest validation and a compatibility check against the desktop plugin
   API version.

## Important Constraints

- Do not create a second plugin system beside Cordis.
- Do not move upstream code.
- Do not make every UI component a separate package unless it has meaningful independent
  lifecycle/configuration value.

## Required Behavior

- Duplicate IDs fail deterministically.
- Cycles fail with a readable dependency chain.
- Platform-incompatible plugins are skipped with diagnostics.
- Required plugin failure blocks startup; optional plugin failure does not.
- A disabled dependency leaves dependent plugins in a deterministic unavailable state.
- Disposal removes commands, UI contributions, listeners, and host registrations.
- Unknown persisted plugin IDs are preserved but inactive.
- Configuration writes are atomic and malformed configuration falls back safely.

## Tests

- enable
- disable
- dependency
- optional dependency
- duplicate plugin ID
- disposal
- platform gating
- plugin startup failure
- plugin settings persistence
- malformed manifest

## Deliverables

- Typed plugin contract
- Capability registry/broker
- Validation and dependency resolver
- Compatibility tests
- Plugin authoring guide

## Commit

`feat: formalize cordis plugin capabilities`

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
