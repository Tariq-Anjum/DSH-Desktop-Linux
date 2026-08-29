# SPEC-001 — DSH Desktop: Master Prompt, Baseline Review & Execution Contract

## Background

Build a CachyOS/Linux-first evolution of the forked repository at:

`/mnt/MD/Project/DSH/DSH-Desktop`

The product vision is a modern native DSH Desktop based on the upstream/forked DSH Desktop project, but with a strict **everything-is-a-plugin** rule. The requested "cordin-plugin" feature is interpreted as the repository's existing **Cordis plugin composition** mechanism.

Important: this plan is based on remote inspection of the fork and upstream public repository because the requested local path was not mounted in this execution environment. Before modifying code, the implementing AI must inspect the local checkout and reconcile differences against this plan.

## Baseline review

The fork is already substantially more than a minimal Electron wrapper:

- The repository is a fork of `anywhere-labs/dsh-desktop`.
- It contains `dsh-plugin-desktop`, `deepseek-harness` as a pinned submodule, vendored DSH runtime artifacts, community fabric/market scaffolding, documentation, and a CachyOS installation guide.
- The desktop package already models Electron bootstrap, Cordis Host/Client composition, profiles, terminal, updates, native lifecycle, presentation modes, and plugin workflows.
- The fork already contains `INSTALL_CACHYOS.md` describing Vulkan, a Codex-like UI and Anti-Gravity UI. These claims must be validated against actual source before being retained in documentation.
- The package exposes `dev`, `start`, `package:dir`, typecheck, tests and architecture/layout checks.
- The current upstream architecture explicitly treats desktop capabilities as Cordis-composed plugins rather than an Electron-only hardcoded feature set.

## Rating

**Current architectural foundation: 8.2/10.**

### Strengths

| Area | Score | Assessment |
|---|---:|---|
| Plugin architecture | 9.2 | Strong Cordis composition and explicit plugin boundaries |
| Electron lifecycle | 8.8 | Mature process/window/profile lifecycle |
| DSH integration | 9.0 | Pinned upstream + explicit runtime boundary |
| Testing/scaffolding | 8.0 | Good headless checks and package tests |
| Documentation | 8.0 | Broad, but must be synchronized with the actual fork |
| Linux/CachyOS support | 6.8 | Installation guide exists, but Linux presentation/Vulkan needs validation |
| Vulkan strategy | 5.8 | "Vulkan capable" is not the same as safely defaulting to Vulkan |
| UI modularity | 8.0 | Good slot/plugin foundations; requested UI-as-plugin policy needs enforcement |
| Security boundary | 8.5 | Sandboxed renderer and loopback design are good foundations |
| Release/install path | 7.2 | Windows/macOS are stronger; Linux should become first-class |

## Critical architectural decision

Do **not** turn the application into a monolithic custom React/Electron shell.

Instead:

1. Keep DSH upstream isolated and pinned.
2. Keep Electron as a thin native bootstrap.
3. Make every desktop capability a Cordis plugin.
4. Make every UI surface a UI plugin/slot contribution.
5. Make Vulkan an infrastructure capability plugin with runtime detection and safe fallback.
6. Make Linux/CachyOS a first-class target.
7. Keep compatibility mode as the zero-override safety path.
8. Never make Vulkan a hard dependency for correctness.

## Complete AI execution prompt

> You are the implementation agent for DSH Desktop at `/mnt/MD/Project/DSH/DSH-Desktop`.
>
> Goal: evolve this repository into a Linux/CachyOS-first, Vulkan-capable, highly polished DSH Desktop where every desktop feature and UI surface is independently enabled/disabled through the existing Cordis plugin composition system.
>
> Before editing:
> - inspect the complete local repository;
> - inspect git status, branches, submodules and pinned upstream commit;
> - inspect package manifests and lockfiles;
> - inspect `dsh-plugin-desktop/src`, `tests`, `cordis.patch.yml`, build scripts and existing UI;
> - run existing checks before changing behavior;
> - do not overwrite working changes;
> - preserve upstream source as a pinned boundary unless a change is explicitly justified.
>
> Architecture rules:
> - Cordis is the composition mechanism.
> - No new feature may be hardcoded into the Electron bootstrap when it can be a plugin.
> - Every UI surface must have a plugin owner and a clear enable/disable contract.
> - Renderer code must not receive arbitrary Electron APIs.
> - Native capabilities must be exposed through narrow typed services.
> - Vulkan must be capability-detected, observable and reversible.
> - Vulkan must be preferred on CachyOS only when the runtime probe confirms a working configuration.
> - Wayland/X11 differences must be handled explicitly.
> - Failure to initialize Vulkan must fall back without making DSH unusable.
> - Keep a compatibility mode that exercises upstream UI with minimal overrides.
>
> UI goals:
> - modern desktop layout;
> - excellent keyboard navigation;
> - command palette;
> - workspace/session navigation;
> - resizable panels;
> - terminal/plugin developer surface;
> - settings for plugin enablement;
> - performance/status indicator;
> - clear GPU/Vulkan status;
> - accessible dark/light/system themes;
> - no permanent dependency on a single visual feature.
>
> Plugin goals:
> - desktop shell;
> - title/command bar;
> - sidebar;
> - session list;
> - conversation;
> - inspector/details;
> - command palette;
> - terminal;
> - notifications;
> - update checker;
> - diagnostics;
> - Vulkan/GPU capability;
> - visual effects;
> - settings;
> - plugin manager;
> - Linux integration;
> - optional experimental effects.
>
> For every plugin define:
> - id;
> - version;
> - dependencies;
> - optional dependencies;
> - capabilities;
> - contributed slots;
> - configuration schema;
> - enable/disable behavior;
> - disposal behavior;
> - tests;
> - failure policy.
>
> Do not claim a feature is implemented until source, tests and documentation agree.
>
> Run typecheck, unit tests, architecture checks and Linux smoke tests after each session. Keep commits small and session-scoped.

## Execution order

Implement exactly ten sessions, using files `02` through `10` as the session contracts. Do not skip ahead unless a dependency is already present.

## Acceptance gate

The project is complete only when:

- `yarn check` passes;
- typecheck passes;
- unit tests pass;
- plugin enable/disable tests pass;
- packaged Linux smoke test passes;
- Vulkan probe works on supported GPU/driver combinations;
- Vulkan failure falls back cleanly;
- every optional UI capability can be disabled;
- README/install docs describe the actual project;
- one-line CachyOS installation works from a release artifact or local build path;
- no feature requires modifying upstream DSH source unnecessarily.


## Ten-file execution map

1. `01-master-prompt-and-baseline.md` — scope, rating, master prompt
2. `02-session-01-repository-audit.md` — exact local baseline
3. `03-session-02-plugin-contract.md` — plugin contract
4. `04-session-03-ui-pluginization.md` — interface and UI plugins
5. `05-session-04-vulkan-gpu.md` — Vulkan/GPU architecture
6. `06-session-05-cachyos-installation.md` — CachyOS packaging/install
7. `07-session-06-plugin-manager.md` — enable/disable UX
8. `08-session-07-linux-native-polish.md` — Linux UX/performance
9. `09-session-08-testing-security-release.md` — quality/security/release
10. `10-session-09-docs-migration-and-final-validation.md` — documentation/handoff
