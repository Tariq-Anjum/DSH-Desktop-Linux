# DSH Desktop — Master Execution Blueprint

## Objective
Build Tariq-Anjum/dsh-desktop into a polished, fast, plugin-first desktop AI workspace for DeepSeek Harness (DSH), using the existing fork as the foundation. The project must preserve the pinned upstream DSH submodule and extend only desktop-owned layers.

## Current repository facts
- Fork: `https://github.com/Tariq-Anjum/dsh-desktop`
- Upstream: `anywhere-labs/dsh-desktop`
- Default branch: `master`
- Root package manager: Yarn 4.18.0 via Corepack
- Root Node requirement: `^22.19.0 || >=24.0.0`
- Upstream DSH is a pinned submodule and must not be edited from desktop feature branches.
- `dsh-plugin-desktop` already owns the Electron/Cordis desktop host, profile composition, packaging, diagnostics, browser access, settings, and plugin enable/disable persistence.
- The current package already depends on `@deepseek-ai/cordis` and the DSH runtime/plugin ecosystem.

## Non-negotiable architecture
1. Extend the existing Cordis/DSH architecture; do not replace it with a new generic Electron plugin microkernel.
2. Keep `deepseek-harness/` untouched.
3. UI capabilities should be desktop-owned plugins and profile-composable.
4. The host, plugin loader, capability broker, IPC boundary, security policy, emergency stop, and lifecycle status remain core infrastructure, not optional plugins.
5. Plugins never receive arbitrary Node/Electron APIs. Use narrowly scoped host capabilities over IPC/contextBridge.
6. Plugin enable/disable must be persistent, recoverable, dependency-aware, and safe.
7. Vulkan is an acceleration capability, not a claim that every UI subsystem is rendered directly by Vulkan.
8. Prefer automatic GPU backend selection with Vulkan as the desired CachyOS backend when supported, plus fallback. Never default to `--ignore-gpu-blocklist` in production.
9. Remote browser content is treated as untrusted. Enforce navigation, permissions, CSP, isolation, and IPC sender validation.
10. Build/test/check must remain headless-safe unless a specific graphical smoke is being run.

## Target experience
A compact, high-performance DSH desktop with: project/session sidebar; central conversation/workspace; contextual right panel; command palette; agent/task telemetry; artifact/canvas review; terminal; browser preview/automation; context/token HUD; scheduler; permission/policy controls; Git actions; screenshots/Appshots; settings; diagnostics.

## Token/context efficiency
Do not automatically preload large memories, skills, logs, or repository trees into agent context. Add a compact context broker that exposes summaries and fetch-on-demand references. Prefer IDs, hashes, paths, state summaries, and targeted reads over repeated full content.

## Definition of done
- Existing compatibility mode still boots the upstream default client unchanged.
- Advanced UI is composed from desktop plugins/profile bundles.
- Plugins can be disabled without destabilizing the desktop.
- All privileged operations are capability-checked.
- CachyOS installation is one command and does not force a full system upgrade.
- AMD/Vulkan detection and actual Electron GPU status are verified, not assumed.
- CI validates typecheck, unit tests, runtime closure, loader/profile boot, security-sensitive policy tests, and packaging.
- Documentation, README, CachyOS installation, architecture docs, and agent instructions match the implementation.
