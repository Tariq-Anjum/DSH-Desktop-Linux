# DSH Desktop Linux — Final Execution Blueprint

> **Consolidation note:** This document merges four prior planning artifacts into one
> authoritative reference. `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (prior version) supplied
> the architecture decisions, which remain authoritative wherever sources disagreed.
> `raw-idea-3` supplied the per-session execution template, expanded here in full for all
> ten sessions. `raw-idea-2` supplied additional requirement detail (repo facts, target
> experience, context/token efficiency, definition-of-done) folded into the relevant
> sections below. `raw-idea-1` is preserved only as historical rationale in Appendix A —
> its differing ten-session breakdown is superseded and not used. See **Appendix B** for
> a full list of what changed in this consolidation and open gaps found during review.

## Execution Target

- **Repository:** `https://github.com/Tariq-Anjum/DSH-Desktop-Linux`
- **Local checkout:** `/mnt/MD/Project/DSH/DSH-Desktop-Linux`
- **Reference-only fork:** `https://github.com/Tariq-Anjum/dsh-desktop`
- **Upstream boundary:** `deepseek-harness/` remains a pinned submodule and is not edited by desktop feature work.

## Product Goal

Build a CachyOS/Linux-first, secure, high-performance DSH desktop workspace. Extend the existing DSH/Cordis architecture rather than replacing it with a generic Electron shell.

The product must provide a polished desktop experience with plugin-composable UI, capability-gated native features, persistent and recoverable plugin configuration, practical AI-agent workflows, and GPU diagnostics with a safe Vulkan preference policy.

### Target Experience

A compact, high-performance DSH desktop composed of: project/session sidebar; central conversation/workspace; contextual right panel (inspector/telemetry); command palette; agent/task telemetry (Agent Matrix); artifact/canvas review with diffing; terminal; browser preview/automation; context/token HUD; scheduler; permission/policy controls; Git actions; screenshots/Appshots; settings; diagnostics.

### Context And Token Efficiency Principle

The desktop must not automatically preload large memories, skills, logs, repository trees, or session history into agent context. Provide a compact **Context Broker** that exposes summaries and fetch-on-demand references instead. Prefer IDs, hashes, paths, state summaries, and targeted reads over repeated full-content loads. This is a standing product principle (not only a Session 08 deliverable) and should inform every plugin that touches agent context.

## Baseline Assumptions To Verify

Before writing implementation code, inspect the actual local checkout and record all differences from this blueprint.

Expected inherited foundation:

- `dsh-plugin-desktop` owns the Electron/Cordis desktop host, profile composition, packaging, diagnostics, browser access, settings, and plugin state.
- Root tooling uses Yarn via Corepack and Node compatible with the repository's declared engine.
- `deepseek-harness/` is a pinned submodule.
- Existing scripts include some combination of `check`, `typecheck`, `test`, `build`, `start`, and packaging commands.
- Existing docs and CachyOS claims are hypotheses until corroborated by source and a local test run.

Unverified reference data points (carried over from an earlier planning pass against the `dsh-desktop` fork — confirm or correct against the actual `DSH-Desktop-Linux` checkout, do not assume these still hold):

- Root package manager: Yarn 4.18.0 via Corepack.
- Root Node requirement: `^22.19.0 || >=24.0.0`.
- Default branch: `master` (verify — GitHub UI referenced `main` for this repo).
- Fork lineage: `Tariq-Anjum/dsh-desktop` forked from `anywhere-labs/dsh-desktop`; `DSH-Desktop-Linux` is a further Linux-first evolution of that fork.

Findings from reviewing the `DSH-Desktop-Linux` GitHub repository directly (as of this consolidation):

- The repository currently contains only planning/documentation artifacts (this blueprint, `raw-idea-1/2/3`, `README.md`, `LICENSE`, `docs/INSTALL_CACHYOS_ONE_LINER.md`, `scripts/install-cachyos.sh`) — **no `package.json`, no `dsh-plugin-desktop/`, and no `deepseek-harness/` submodule are present in this repo.** Session 01 must confirm whether the local checkout at `/mnt/MD/Project/DSH/DSH-Desktop-Linux` already contains the application source (merged from the `dsh-desktop` fork) or whether that merge is still outstanding.
- No `AGENTS.md` exists yet in this repository, despite every session below instructing the agent to read it first. Session 01 must either locate it in the actual local checkout or create it as part of establishing the baseline.
- `scripts/install-cachyos.sh` and `docs/INSTALL_CACHYOS_ONE_LINER.md` already exist and largely satisfy the Session 01 installer deliverable and the CachyOS Installation Principle below (OS/prereq checks, GPU detection, no silent NVIDIA driver replacement, no blanket `pacman -Syu`, user-local install to `~/.local/dsh-desktop-linux`). They do **not** yet include a `scripts/linux/check-gpu.mjs` (or equivalent Node-based) GPU diagnostics script — only the shell installer's inline GPU detection exists. This is an open gap for Session 01.

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

## Plugin Taxonomy And Contract

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

### Plugin Inventory By Category

Indicative, not exhaustive — grow the graph only where a plugin has meaningful independent lifecycle/configuration value (see architecture rule 6).

```text
core:
  desktop-shell
  desktop-runtime
  desktop-profile

ui:
  ui-frame
  ui-command-bar
  ui-sidebar
  ui-session-list
  ui-conversation
  ui-details
  ui-command-palette
  ui-status-bar
  ui-settings
  ui-plugin-manager
  ui-agent-matrix
  ui-artifact-canvas

system:
  system-tray
  notifications
  updates
  diagnostics
  terminal
  linux-integration
  scheduler
  git-actions

interaction:
  browser
  appshots
  context-broker

graphics:
  gpu-capability
  vulkan-runtime
  visual-effects

experimental:
  anti-gravity
  enhanced-materials
```

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

**Current repo state:** `scripts/install-cachyos.sh` and `docs/INSTALL_CACHYOS_ONE_LINER.md` already implement most of this (OS check, prereq check, GPU detection with opt-in package install, clone/build to `~/.local/dsh-desktop-linux`, launcher + desktop entry, smoke check). Treat these as a Session 01 starting point to audit and extend, not as work to redo from scratch — the main gap is a dedicated Node-based `scripts/linux/check-gpu.mjs` diagnostic surfaced to the running app, distinct from the installer's inline shell GPU probe.

## Ten Sessions

Each session below is self-contained and execution-ready: read this blueprint (particularly the sections it draws on) and the repository's `AGENTS.md` first, then work only inside `/mnt/MD/Project/DSH/DSH-Desktop-Linux`. **Common Agent Rules** (below the sessions) and the **Final Acceptance Gate** apply throughout.

### Session 01 — Baseline, Runtime, Installer

**Goal:** Audit and stabilize the existing fork before feature work. Establish a reproducible CachyOS developer/runtime path using the existing Yarn/Cordis architecture.

**Tasks:**

1. Record the current git SHA, submodule SHA, Node/Yarn versions, and available scripts.
2. Run the existing headless gate before changes. Capture failures.
3. Audit the existing Linux installer and CachyOS documentation (`scripts/install-cachyos.sh`, `docs/INSTALL_CACHYOS_ONE_LINER.md`). Remove any claim or behavior that performs an unnecessary full `pacman -Syu`.
4. Extend the existing CachyOS installer so it: checks OS, checks Node/Corepack/Yarn prerequisites, initializes the repo/runtime only when needed, detects GPU, installs only missing Vulkan runtime packages when authorized, builds the existing desktop package, installs a user-level launcher/desktop entry, and verifies the launch/runtime state.
5. Keep the one-line bootstrap command thin: it downloads a versioned installer from this fork and runs it; the installer performs checks and prints exactly what it changes.
6. Add `scripts/linux/check-gpu.mjs` (or equivalent) to report GPU vendor, Vulkan loader availability, Vulkan device list, and Electron/Chromium GPU diagnostics when the app is run — this does not yet exist in the repo.
7. Locate or create `AGENTS.md` at the repository root — it is referenced by every session but was not found during this review.
8. Create `docs/architecture/BASELINE-AUDIT.md` describing what is inherited versus owned, including repository tree, dependency graph, current plugin inventory, current UI surfaces, current Linux behavior, current GPU behavior, current test commands/results, current known failures, exact upstream pin, proposed changes, and files that must not be modified.

**Hard constraints:** do not update the upstream pin; do not remove dependencies; do not rewrite the UI; do not introduce a new framework; do not change installer behavior beyond what this session specifies.

**Verify:**

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop-Linux
git status --short
git submodule status --recursive
corepack yarn install --immutable
corepack yarn check
corepack yarn typecheck
corepack yarn test
```

Plus: installer dry-run/check mode, GPU diagnostic command.

**Deliverables:** `docs/architecture/BASELINE-AUDIT.md`; documented inherited-versus-owned boundary; baseline command results and known failures; extended CachyOS installer with dry-run/check mode; GPU diagnostics CLI/service scaffold.

**Commit:** `chore: establish desktop baseline and cachyos runtime`

### Session 02 — Plugin Contract And Lifecycle

**Goal:** Formalize the desktop plugin manifest, dependency graph, lifecycle health, API-version compatibility, persistent enablement, deterministic cleanup, and plugin authoring documentation.

**Tasks:**

1. Inventory the existing `dsh-plugin-desktop` plugin loading/profile APIs.
2. Define a desktop-owned plugin contract compatible with current Cordis loading, matching the `DesktopPluginManifest` shape above (id, version, API version, capabilities, permissions, dependencies, commands, UI contributions, settings schema, lifecycle health).
3. Define typed capability IDs per the Capability And Security Model section.
4. Build a capability registry/broker. Plugins request named capabilities; they do not get unrestricted host objects.
5. Add dependency ordering, cycle detection, optional dependency handling, health state, and deterministic cleanup.
6. Preserve the existing persistent plugin enable/disable state and extend it only where needed.
7. Add plugin manifest validation and a compatibility check against the desktop plugin API version.

**Important constraints:** do not create a second plugin system beside Cordis; do not move upstream code; do not make every UI component a separate package unless it has meaningful independent lifecycle/configuration value.

**Tests:** enable; disable; dependency; optional dependency; duplicate plugin ID; disposal; platform gating; plugin startup failure; plugin settings persistence; malformed manifest.

**Deliverables:** typed plugin contract; capability registry/broker; validation and dependency resolver; compatibility tests; plugin authoring guide.

**Commit:** `feat: formalize cordis plugin capabilities`

### Session 03 — Capability Broker And Secure Host Bridge

**Goal:** Create the security boundary between UI plugins and privileged desktop operations.

**Tasks:**

1. Audit current preload/contextBridge/IPC exposure and remote-content handling.
2. Keep `nodeIntegration: false`, `contextIsolation: true`, renderer sandboxing, and secure CSP for owned UI. Validate all IPC senders.
3. Introduce a typed host capability broker. Every privileged request has: plugin ID, capability, operation, target/resource, request ID, and policy context.
4. Implement policy evaluation with `Sandbox`, `Review`, and `Full Access` as user-facing presets only; decisions remain per capability/resource underneath.
5. Model resources explicitly: workspace roots, allowed file paths, executable classes, network hosts, browser profiles, Git repositories.
6. Destructive actions require review unless explicitly permitted by policy.
7. Add an emergency stop that cancels active agent/task/process operations where supported.
8. Add audit events with secrets redacted.
9. Add browser restrictions: navigation policy, permission request policy, external-window policy, no arbitrary privileged remote renderer.

**Tests:** IPC sender spoof rejection; denied capability; path traversal/symlink policy cases; destructive operation review; emergency stop; browser navigation restrictions; CSP and preload contract smoke tests.

**Deliverables:** policy engine; typed capability broker; permission presets; audit/event schema; security tests.

**Commit:** `feat: add capability policy and secure host bridge`

### Session 04 — Desktop Shell And Plugin-Composed UI

**Goal:** Create stable UI slots and a polished, accessible, keyboard-first shell. Make core panels independently composable where meaningful, with persistent layout and lazy loading.

**Target shell:** compact title/toolbar; left — projects, sessions, workspaces, plugins; center — conversation + active artifact/workspace; right — optional inspector/agent telemetry/context; bottom — terminal/status when enabled; overlays — command palette, approvals, annotations. (Matches the UI Model ASCII layout above.)

**Tasks:**

1. Inspect the current renderer and client UI before changing layout. Reuse existing primitives where possible.
2. Define the small set of stable UI contribution slots from the UI Model section, not a slot per widget.
3. Make panels resizable and persist layout per profile.
4. Add responsive compact mode and floating/popup mode only where existing architecture supports it cleanly.
5. Add a consistent design system: spacing, typography, elevation, focus states, keyboard navigation, reduced motion.
6. Keep plugin panels lazy-loaded; disabled plugins must not add runtime listeners or large bundles to startup.
7. Add a plugin/settings screen to enable/disable optional capabilities.
8. Add an always-visible security/agent status indicator and emergency-stop control.

**Performance rules:** no expensive animation loops by default; no giant canvas just for decoration; lazy load large editor/browser/terminal components; measure renderer startup and interaction latency.

**Tests:** disable sidebar; disable inspector; disable command palette; disable visual effects; disable status bar; start with all optional UI plugins disabled; restore all plugins; verify settings persist; verify no stale UI or listener leakage.

**Deliverables:** refreshed shell; layout persistence; plugin slot contract; keyboard navigation/accessibility baseline.

**Commit:** `feat: refresh desktop shell and plugin slots`

### Session 05 — Agent Runtime And Task Matrix

**Goal:** Build a real execution telemetry model on top of existing DSH runtime events instead of inventing a disconnected UI simulation.

**Tasks:**

1. Map current DSH session/agent/tool/goal events available to the desktop.
2. Define a normalized desktop event stream: task created, queued, running, waiting approval, tool start, tool end, blocked, completed, failed, cancelled.
3. Create task IDs and parent/child relationships for parallel work.
4. Implement an Agent Matrix (`ui-agent-matrix`) plugin that consumes the normalized stream.
5. Show only useful telemetry: status, current action, elapsed time, model/provider, token usage when available, pending approval, error.
6. Support collapse/grouping and stale-event handling.
7. Add backpressure/throttling so high-frequency events do not cause renderer storms.
8. Do not display fabricated progress percentages. If exact progress is unavailable, use state + elapsed time.

**Tests:** event normalization; child task grouping; out-of-order event handling; cancellation; high-frequency update throttling.

**Deliverables:** normalized task/event contract; Agent Matrix plugin; telemetry tests.

**Commit:** `feat: add agent task telemetry and matrix`

### Session 06 — Artifact Canvas And Review

**Goal:** Create an artifact reference model and a plugin for text, Markdown, JSON, images, PDFs, code diffs, structured comments, and policy-gated accept/reject/apply actions.

**Tasks:**

1. Inventory existing attachment/file/artifact/session projection APIs.
2. Define an artifact reference model using path/ID/hash/mime/size rather than copying full content into every event.
3. Build a Canvas/Artifact (`ui-artifact-canvas`) plugin for text, Markdown, JSON, images, and PDFs using existing app capabilities where possible.
4. Add diff view for text/code. Prefer a proven diff/editor library already present, or add the smallest justified dependency.
5. Support line/range comments as structured review objects.
6. Add accept/reject/apply semantics wired to the host capability broker and policy engine.
7. Stream/page large artifacts; never render unbounded content into one DOM tree.

**Tests:** artifact opening; MIME handling; diff correctness; review comments; approval/policy enforcement; large-file protection.

**Deliverables:** artifact model; canvas/diff plugin; review workflow.

**Commit:** `feat: add artifact canvas and review workflow`

### Session 07 — Terminal, Browser, And Appshots

**Goal:** Add host-capability-backed terminal, browser preview/automation, and screenshots/Appshots plugins. Reuse existing terminal/browser services whenever present.

**Terminal:** reuse existing terminal/runtime services where available; expose PTY only through the capability broker; support tabs, resize, search, copy, clear, session persistence.

**Browser:** reuse the repository's existing browser-access implementation instead of adding a second browser stack; separate local previews from remote/untrusted browsing and enforce browser security policy; build annotation support around stable browser events/coordinates rather than assuming arbitrary DOM access from the host.

**Appshots:** implement OS-appropriate global capture only where supported; do not rely solely on renderer key events for a system-wide shortcut; capture into a compact attachment/reference, then inject a reference into the DSH context pipeline (not full content).

**Tests:** PTY lifecycle; browser policy; navigation denial; screenshot/capture permissions; plugin disable cleanup.

**Deliverables:** terminal plugin; browser plugin; Appshots plugin; platform capability diagnostics.

**Commit:** `feat: add terminal browser and appshots plugins`

### Session 08 — Context Broker And Command Palette

**Goal:** Make the desktop agent workflow fast and context-efficient, per the Context And Token Efficiency Principle above.

**Tasks:**

1. Build a Context Broker (`context-broker`) that exposes compact summaries and fetch-on-demand references for files, sessions, plugins, memory, and tool results.
2. Define context items with source ID, type, size/token estimate, freshness, relevance, and inclusion policy.
3. Add explicit include/exclude controls for folders/files/session artifacts.
4. Add context budget management with soft/hard limits and truncation strategies.
5. Add a Token/Context HUD showing approximate current usage and what categories consume it; never claim provider-exact counts unless sourced from the provider.
6. Build a global command palette (`ui-command-palette`) using the desktop's existing command infrastructure. Commands should be registered by plugins rather than hardcoded in a giant switch.
7. Support commands such as goal/task, browser, terminal, diff, plugin enable/disable, profile switching, diagnostics.
8. Make all command results structured and short by default.

**Tests:** context ranking; budget enforcement; stale references; command registration/removal; keyboard shortcut cleanup.

**Deliverables:** context broker; command registry; command palette plugin; context/token HUD.

**Commit:** `feat: add context broker command palette and token hud`

### Session 09 — Scheduler, Git, Settings, And Recovery

**Goal:** Finish the operational layer while keeping every optional UX feature plugin-controlled.

**Scheduler:** reuse existing DSH jobs/scheduler services where possible; UI creates/pauses/resumes/deletes schedules without directly owning privileged execution; show next run, last result, failures, policy status.

**Git:** expose status/diff/commit/push actions through typed host capabilities; confirm destructive Git operations.

**Settings:** plugin settings schema and profile persistence; GPU backend preference (`automatic` default, Vulkan preferred when verified, fallback available — matches the Vulkan And GPU Policy section); security mode; workspace roots; browser policy; telemetry; appearance; hotkeys.

**Operational controls:** diagnostics export; reset profile/plugin state; plugin recovery mode; visible disabled/failed plugin explanation.

**Tests:** scheduler lifecycle; Git policy; settings migration; plugin state persistence; recovery boot.

**Deliverables:** scheduler plugin; Git actions integration; settings/policy UI; recovery UX.

**Commit:** `feat: add scheduler git and operational controls`

### Session 10 — Vulkan Validation, Packaging, Docs, Release

**Goal:** Turn the work into a verifiable CachyOS release without overstating Vulkan support.

**Vulkan:**

1. Add a GPU diagnostics page/CLI showing vendor, renderer, API version, Electron GPU feature status, and selected backend (per the Vulkan And GPU Policy section).
2. Prefer Vulkan through supported Chromium/Electron configuration only when verified on the target environment.
3. Keep automatic fallback.
4. Do not use `--ignore-gpu-blocklist` as a normal production flag.
5. Do not describe Monaco, terminal, browser, or screenshots as directly Vulkan-rendered unless the implementation actually uses a Vulkan rendering path.
6. Add a benchmark/smoke report for startup time, renderer responsiveness, memory, and GPU feature status.

**Packaging:**

1. Build Linux artifacts suitable for CachyOS/Arch distribution.
2. Provide a user-friendly one-line installer that points at the fork's versioned installer script (`scripts/install-cachyos.sh`).
3. Never pipe an unpinned remote shell into root. The installer must run unprivileged except for explicitly required package installation steps and must explain those steps.
4. Prefer user-local application installation for development builds; package/AUR instructions may be separate.

**Documentation** — update in one coherent pass: root README; `dsh-plugin-desktop/README.md`; CachyOS installation guide; `docs/architecture/*`; `docs/PLUGIN_ARCHITECTURE.md`; `docs/SECURITY_MODEL.md`; `docs/VULKAN.md`; plugin authoring docs; troubleshooting; contribution/agent instructions (`AGENTS.md`); release notes/changelog.

**Final verification:** clean checkout from the fork; submodule initialization; immutable dependency install; build; typecheck; unit tests; runtime closure; loader/profile smokes; security tests; packaging tests; CachyOS install test; launch test; plugin enable/disable test; compatibility mode test.

**Deliverables:** release-ready tree; verified one-line installer; complete documentation; reproducible verification report.

**Commit:** `release: validate cachyos build and finalize documentation`

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
- CI validates typecheck, unit tests, runtime closure, loader/profile boot, security-sensitive policy tests, and packaging.
- Compatibility mode boots the baseline DSH experience unchanged.
- Advanced UI is composed from desktop plugins/profile bundles, not hardcoded into the Electron bootstrap.
- Required plugin failure blocks boot cleanly; optional failures remain recoverable and do not destabilize the desktop.
- Plugin enable/disable, dependency handling, persistent settings, rollback/recovery, and disposal are tested.
- Privileged operations pass capability and policy tests.
- Packaged app launches under CachyOS; desktop entry and launcher work.
- Wayland and X11 results are pass/fail documented.
- Vulkan `auto`, unavailable-Vulkan fallback, and software diagnostic mode are tested; AMD/Intel/NVIDIA and actual Electron GPU status are verified, not assumed.
- No GPU driver is silently replaced and no default install performs a full system upgrade.
- README, docs, architecture notes, and `AGENTS.md` make only source-backed, tested claims that match the implementation.
- `git diff --check` is clean and generated artifacts are excluded unless intentionally packaged.

A feature is accepted only when it is **implemented, composable, disableable where optional, capability-safe, tested, documented, observable, and recoverable**.

---

## Appendix A — Design Rationale (Historical)

Preserved for context only; superseded by the sections above wherever it conflicts. This reflects an earlier review of the predecessor fork (`Tariq-Anjum/dsh-desktop`, itself forked from `anywhere-labs/dsh-desktop`, local path `/mnt/MD/Project/DSH/DSH-Desktop`) before the project became `DSH-Desktop-Linux`.

**Baseline rating at the time: 8.2/10.** The fork was already substantially more than a minimal Electron wrapper — it modeled Electron bootstrap, Cordis Host/Client composition, profiles, terminal, updates, native lifecycle, presentation modes, and plugin workflows, with `deepseek-harness` as a pinned submodule.

| Area | Score | Assessment |
|---|---:|---|
| Plugin architecture | 9.2 | Strong Cordis composition and explicit plugin boundaries |
| Electron lifecycle | 8.8 | Mature process/window/profile lifecycle |
| DSH integration | 9.0 | Pinned upstream + explicit runtime boundary |
| Testing/scaffolding | 8.0 | Good headless checks and package tests |
| Documentation | 8.0 | Broad, but needed synchronization with the actual fork |
| Linux/CachyOS support | 6.8 | Installation guide existed, but Linux presentation/Vulkan needed validation |
| Vulkan strategy | 5.8 | "Vulkan capable" is not the same as safely defaulting to Vulkan |
| UI modularity | 8.0 | Good slot/plugin foundations; UI-as-plugin policy needed enforcement |
| Security boundary | 8.5 | Sandboxed renderer and loopback design were good foundations |
| Release/install path | 7.2 | Windows/macOS were stronger; Linux needed to become first-class |

**The critical architectural decision this blueprint still rests on:** do not turn the application into a monolithic custom React/Electron shell. Instead — keep DSH upstream isolated and pinned; keep Electron a thin native bootstrap; make every desktop capability a Cordis plugin; make every UI surface a UI plugin/slot contribution; make Vulkan an infrastructure capability plugin with runtime detection and safe fallback; make Linux/CachyOS a first-class target; keep compatibility mode as the zero-override safety path; never make Vulkan a hard dependency for correctness.

This rationale directly produced the Non-Negotiable Architecture list and the ten-session execution order used above (re-sequenced from an earlier, differently-divided ten-session plan that split UI/Vulkan/installer/plugin-manager/polish/testing/docs into separate sessions — that earlier split is superseded by the Session 01–10 structure in this document).

## Appendix B — Consolidation Notes

What this pass did:

- Took `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` as the architecture authority for every section where sources disagreed (non-negotiable architecture, plugin contract, capability/security model, UI model, Vulkan/GPU policy, install principle, acceptance gate).
- Expanded the "Ten Sessions" section from FINAL's condensed summaries into full, standalone-executable session specs using `raw-idea-3`'s template shape (Goal / Tasks / Tests / Deliverables / Commit), rather than repeating the "Agent operating rules" footer ten times — that footer is now the single **Common Agent Rules** section, which applies to all sessions.
- Folded in requirement detail unique to `raw-idea-2` that FINAL didn't have: the **Target Experience** list, the **Context And Token Efficiency Principle** as a standing product principle (not just a Session 08 task), specific repo facts as *unverified* baseline data points, and CI-validation detail merged into the **Final Acceptance Gate**.
- Kept `raw-idea-1` out of the operative sections (its ten-session breakdown is a different, superseded decomposition) and preserved only its rating table and core architectural rationale in **Appendix A**.
- Added a **Plugin Inventory By Category** (core/ui/system/interaction/graphics/experimental) synthesized from `raw-idea-1`/`raw-idea-2`'s plugin category lists plus every plugin named across the ten sessions — FINAL's UI Model only listed UI-kind plugins.
- Added findings from actually reviewing the live `DSH-Desktop-Linux` GitHub repository (not just the four source documents): the repo currently holds planning docs/scripts only with no application source or `AGENTS.md` present, and the existing `scripts/install-cachyos.sh` / `docs/INSTALL_CACHYOS_ONE_LINER.md` already satisfy most of the Session 01 installer deliverable except the `check-gpu.mjs` diagnostic script. These are called out inline in **Baseline Assumptions To Verify** and the **CachyOS Installation Principle** section so Session 01 doesn't redo existing work.

Recommended repo follow-up (not performed here, no push access): once this consolidated file is committed, archive or delete `raw-idea-1/`, `raw-idea-2/`, and `raw-idea-3/` so there's a single source of truth, and create the missing `AGENTS.md` referenced throughout.
