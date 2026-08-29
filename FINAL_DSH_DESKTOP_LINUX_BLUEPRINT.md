# DSH Desktop Linux — Final Execution Blueprint

## Execution Target

- **Repository:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux`
- **Local checkout:** `/mnt/MD/Project/DSH/DSH-Desktop-Linux`
- **Reference-only fork:** `https://github.com/Tariq-Anjum/dsh-desktop`
- **Upstream boundary:** `deepseek-harness/` remains a pinned submodule and is not edited by desktop feature work.

## Product Goal

Build a CachyOS/Linux-first, secure, high-performance DSH desktop workspace. Extend the existing DSH/Cordis architecture rather than replacing it with a generic Electron shell.

The product must provide a polished desktop experience with plugin-composable UI, capability-gated native features, persistent and recoverable plugin configuration, practical AI-agent workflows, and GPU diagnostics with a safe Vulkan preference policy.

## Baseline Assumptions To Verify

Before writing implementation code, inspect the actual local checkout and record all differences from this blueprint.

Expected inherited foundation:

- `dsh-plugin-desktop` owns the Electron/Cordis desktop host, profile composition, packaging, diagnostics, browser access, settings, and plugin state.
- Root tooling uses Yarn via Corepack and Node compatible with the repository's declared engine.
- `deepseek-harness/` is a pinned submodule.
- Existing scripts include some combination of `check`, `typecheck`, `test`, `build`, `start`, and packaging commands.
- Existing docs and CachyOS claims are hypotheses until corroborated by source and a local test run.

## Non-Negotiable Architecture

1. Reuse Cordis composition; do not introduce a second competing plugin runtime.
2. Keep Electron a thin bootstrap and native-service host.
3. Keep the upstream DSH submodule isolated and pinned.
4. Keep the plugin loader, core lifecycle, capability broker, IPC boundary, security policy, emergency stop, and application recovery path as required core infrastructure.
5. Desktop-owned capabilities and meaningful UI surfaces must be Cordis/profile-composable plugins.
6. Do not split every widget into a plugin; create plugins only where lifecycle, configuration, permissions, platform support, or independent enablement makes sense.
7. No renderer/plugin gets arbitrary Node.js or Electron APIs. Privileged operations go through typed, capability-scoped host services.
8. Compatibility mode must boot the upstream/default UI with minimal desktop overrides.
9. Disabled plugins must add no UI contributions, listeners, polling loops, or material startup cost.
10. Build, typecheck, test, and static checks must stay headless-safe.

## Plugin Contract

Adapt this model to existing Cordis contracts; do not duplicate or replace Cordis loading.

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

Every desktop plugin must document and test:

- Manifest, owner, version, and API compatibility
- Dependencies and optional dependencies
- Requested host capabilities and resource scope
- UI slots and commands contributed
- Settings schema, defaults, persistence, and migrations
- Start, stop, disposal, and restart behavior
- Required versus optional failure policy
- Diagnostics and user-visible unavailable state

Required behavior:

- Duplicate IDs fail deterministically.
- Cycles fail with a readable dependency chain.
- Platform-incompatible plugins are skipped with diagnostics.
- Required plugin failure blocks startup; optional plugin failure does not.
- A disabled dependency leaves dependent plugins in a deterministic unavailable state.
- Disposal removes commands, UI contributions, listeners, and host registrations.
- Unknown persisted plugin IDs are preserved but inactive.
- Configuration writes are atomic and malformed configuration falls back safely.

## Capability And Security Model

Use typed capability identifiers and resource-scoped decisions. Suggested capability families:

```text
fs.read, fs.write, process.exec, terminal.pty,
browser.navigate, browser.interact, screen.capture,
git.read, git.write, scheduler.manage,
context.read, context.write, diagnostics.read
```

All privileged requests carry plugin ID, capability, operation, resource/target, request ID, and policy context.

Security baseline:

- `nodeIntegration: false`
- `contextIsolation: true`
- renderer sandboxing where the current architecture permits it
- sender validation for every IPC entry point
- strict navigation, permission, external-window, and CSP policy
- external links handled by the OS after validation
- no arbitrary shell API exposed to renderers
- remote browser content treated as untrusted
- audit events redact secrets
- destructive operations require review unless policy explicitly grants them
- emergency stop cancels active agent/task/process work where supported

User-facing policy presets may be `Sandbox`, `Review`, and `Full Access`, but enforcement remains per capability and resource.

## UI Model

Use a small, stable set of contribution slots rather than a slot per widget.

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

Target UI plugins:

- `ui-frame`
- `ui-command-bar`
- `ui-sidebar`
- `ui-session-list`
- `ui-conversation`
- `ui-details`
- `ui-command-palette`
- `ui-status-bar`
- `ui-settings`
- `ui-plugin-manager`
- `ui-agent-matrix`
- `ui-artifact-canvas`

UX requirements:

- Keyboard-first navigation and plugin-registered commands
- Resizable sidebar, inspector, and terminal with per-profile persistence
- Clear empty, loading, failure, disabled, and dependency-blocked states
- System/light/dark themes, reduced motion, high contrast, visible focus states
- Responsive compact behavior and sensible minimum window dimensions
- Lazy load expensive terminal, editor, browser, and artifact components
- No giant decorative canvas or permanent animation loop
- Always-visible agent/security state and emergency-stop control

## Vulkan And GPU Policy

Vulkan is an optional acceleration preference, not a claim that the desktop UI is natively Vulkan-rendered.

```
GPU probe
  ├─ Vulkan loader + usable device + validated Electron path → prefer Vulkan
  ├─ Vulkan unavailable → normal accelerated Chromium path
  └─ GPU/backend error → diagnostic software fallback
```

Settings:

```yaml
graphics:
  mode: auto # auto | vulkan | accelerated | software
  requireVulkan: false
  effects: true
```

Rules:

- Default to `auto` on CachyOS.
- Prefer Vulkan only after target-machine validation.
- Keep `vulkan` as explicit user override with visible failure reporting.
- Keep `software` as an emergency diagnostic mode.
- Never make Vulkan a correctness dependency.
- Never default to `--ignore-gpu-blocklist`.
- Explicitly test Wayland and X11.
- Do not describe Canvas, Monaco, browser, terminal, screenshots, or WebGL as directly Vulkan-rendered without a technically defensible direct Vulkan implementation.

The GPU diagnostic service/CLI must report:

- OS and session type
- GPU vendor, renderer, and driver
- Vulkan loader and device/API information when available
- Electron/Chromium GPU feature status and selected backend
- Hardware acceleration state
- Requested mode, selected mode, and fallback reason

`vulkaninfo` is useful when installed but must not be a runtime hard dependency.

## CachyOS Installation Principle

One-line installation must be deterministic, visible about what it changes, and never silently replace an NVIDIA driver or run a full system upgrade.

The release installer should:

1. Verify CachyOS/Arch compatibility and supported architecture.
2. Check Node/Corepack/toolchain prerequisites and explain missing dependencies.
3. Detect GPU and report recommended Vulkan userspace packages without silently changing drivers.
4. Initialize submodules and immutable dependencies.
5. Build/install a user-local package or a verified release artifact.
6. Install a launcher and `.desktop` entry.
7. Run a non-destructive GPU and application smoke check.

Do not use `curl | sudo sh`. If a remote bootstrap is used, pin a version/tag/checksum and run unprivileged except for explicit package installation.

## Ten Sessions

### Session 01 — Baseline, Runtime, Installer

Audit local Git/submodule state, manifests, scripts, existing tests, plugins, UI surfaces, Linux behavior, and current GPU behavior before changes.

Deliver:

- `docs/architecture/BASELINE-AUDIT.md`
- documented inherited-versus-owned boundary
- baseline command results and known failures
- CachyOS installer design with dry-run/check mode
- GPU diagnostics CLI/service scaffold

Verify:

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop-Linux
git status --short
git submodule status --recursive
corepack yarn install --immutable
corepack yarn check
corepack yarn typecheck
corepack yarn test
```

Commit: `chore: establish desktop baseline and cachyos runtime`

### Session 02 — Plugin Contract And Lifecycle

Formalize the desktop plugin manifest, dependency graph, lifecycle health, API-version compatibility, persistent enablement, deterministic cleanup, and plugin authoring documentation.

Verify enable, disable, duplicate ID, ordering, cycles, optional dependency, platform gating, disposal, settings persistence, invalid configuration, and failure recovery.

Commit: `feat: formalize cordis plugin capabilities`

### Session 03 — Capability Broker And Secure Host Bridge

Implement typed capability brokering and policy evaluation; audit preload, IPC, navigation, CSP, and browser handling.

Verify sender spoof rejection, permission denial, workspace/path traversal/symlink handling, destructive-review behavior, emergency stop, browser restriction enforcement, and preload/CSP contract smoke tests.

Commit: `feat: add capability policy and secure host bridge`

### Session 04 — Desktop Shell And Plugin-Composed UI

Create stable UI slots and a polished, accessible, keyboard-first shell. Make core panels independently composable where meaningful, with persistent layout and lazy loading.

Verify sidebar, inspector, palette, status bar, visual effects, and all optional UI plugins can be disabled and restored without stale UI or listener leakage.

Commit: `feat: refresh desktop shell and plugin slots`

### Session 05 — Agent Runtime And Task Matrix

Map real DSH runtime events; create a normalized task model with parent/child relations, state transitions, cancellation, approvals, errors, and event throttling.

Do not fabricate progress percentages. Show state and elapsed time where exact progress is unavailable.

Commit: `feat: add agent task telemetry and matrix`

### Session 06 — Artifact Canvas And Review

Create an artifact reference model and a plugin for text, Markdown, JSON, images, PDFs, code diffs, structured comments, and policy-gated accept/reject/apply actions.

Stream/page large artifacts; never render unbounded content into one DOM tree.

Commit: `feat: add artifact canvas and review workflow`

### Session 07 — Terminal, Browser, And Appshots

Add host-capability-backed terminal, browser preview/automation, and screenshots/Appshots plugins. Reuse existing terminal/browser services whenever present.

Separate local previews from remote browsing and enforce browser security policy. Use platform-appropriate capture APIs rather than renderer-only global shortcut assumptions.

Commit: `feat: add terminal browser and appshots plugins`

### Session 08 — Context Broker And Command Palette

Implement fetch-on-demand context references, explicit inclusion controls, soft/hard budgets, approximate token accounting, and command registration from plugins.

Use summaries, IDs, paths, hashes, and targeted reads instead of automatically loading repositories, memories, logs, or skills into context.

Commit: `feat: add context broker command palette and token hud`

### Session 09 — Scheduler, Git, Settings, And Recovery

Add policy-gated scheduler and Git operations, persistent plugin settings, graphics preferences, diagnostics export, reset/recovery flow, and visible explanations for disabled or failed plugins.

Commit: `feat: add scheduler git and operational controls`

### Session 10 — Vulkan Validation, Packaging, Docs, Release

Implement and validate GPU policy, Wayland/X11 behavior, packaged Linux launch, launcher/desktop integration, Arch/CachyOS package path, release installer, documentation, CI/release gates, and compatibility mode.

Required documentation:

- README and installation guide
- `docs/PLUGIN_ARCHITECTURE.md`
- `docs/SECURITY_MODEL.md`
- `docs/VULKAN.md`
- plugin authoring guide
- troubleshooting and release notes

Commit: `release: validate cachyos build and finalize documentation`

## Common Agent Rules

Apply to every session:

- Read `AGENTS.md`, this blueprint, and relevant existing code before editing.
- Work only in `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
- Do not edit `deepseek-harness/` unless explicitly authorized after a justified architectural review.
- Preserve uncommitted work; inspect `git status` before changes.
- Reuse existing DSH/Cordis services before introducing packages or parallel systems.
- Make the smallest coherent change and keep commits session-scoped.
- Run focused tests first, then the full session gate.
- Do not proceed with known failures unless they are clearly unrelated and recorded.
- Do not fabricate feature, security, GPU, performance, progress, or token claims.
- At session end print: changed files, tests run, results, remaining issues, and commit SHA.

## Final Acceptance Gate

A release is accepted only when all are true:

- Immutable dependency install succeeds from a clean checkout.
- Static checks, typecheck, unit tests, integration checks, and packaging complete successfully.
- Compatibility mode boots the baseline DSH experience.
- Required plugin failure blocks boot cleanly; optional failures remain recoverable.
- Plugin enable/disable, dependency handling, persistent settings, rollback/recovery, and disposal are tested.
- Privileged operations pass capability and policy tests.
- Packaged app launches under CachyOS; desktop entry and launcher work.
- Wayland and X11 results are pass/fail documented.
- Vulkan `auto`, unavailable-Vulkan fallback, and software diagnostic mode are tested.
- No GPU driver is silently replaced and no default install performs a full system upgrade.
- README and docs make only source-backed, tested claims.
- `git diff --check` is clean and generated artifacts are excluded unless intentionally packaged.

A feature is accepted only when it is **implemented, composable, disableable where optional, capability-safe, tested, documented, observable, and recoverable**.
