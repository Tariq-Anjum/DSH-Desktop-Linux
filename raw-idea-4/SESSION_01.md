# Session 01 — Baseline, Runtime, Installer

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Baseline Assumptions To Verify, CachyOS
> Installation Principle) and the repository's `AGENTS.md` first. If `AGENTS.md` does not
> exist yet, that is itself a finding for this session — see Task 7.

## Goal

Audit and stabilize the existing fork before feature work. Establish a reproducible
CachyOS developer/runtime path using the existing Yarn/Cordis architecture.

## Tasks

1. Record the current git SHA, submodule SHA, Node/Yarn versions, and available scripts.
2. Run the existing headless gate before changes. Capture failures.
3. Audit the existing Linux installer and CachyOS documentation
   (`scripts/install-cachyos.sh`, `docs/INSTALL_CACHYOS_ONE_LINER.md`). Remove any claim
   or behavior that performs an unnecessary full `pacman -Syu`.
4. Extend the existing CachyOS installer so it: checks OS, checks Node/Corepack/Yarn
   prerequisites, initializes the repo/runtime only when needed, detects GPU, installs
   only missing Vulkan runtime packages when authorized, builds the existing desktop
   package, installs a user-level launcher/desktop entry, and verifies the launch/runtime
   state.
5. Keep the one-line bootstrap command thin: it downloads a versioned installer from this
   fork and runs it; the installer performs checks and prints exactly what it changes.
6. Add `scripts/linux/check-gpu.mjs` (or equivalent) to report GPU vendor, Vulkan loader
   availability, Vulkan device list, and Electron/Chromium GPU diagnostics when the app is
   run — this does not yet exist in the repo.
7. Locate `AGENTS.md` in the actual local checkout, or create it at the repository root if
   it genuinely does not exist — every later session assumes it is present.
8. Create `docs/architecture/BASELINE-AUDIT.md` describing what is inherited versus owned,
   including repository tree, dependency graph, current plugin inventory, current UI
   surfaces, current Linux behavior, current GPU behavior, current test commands/results,
   current known failures, exact upstream pin, proposed changes, and files that must not
   be modified.

## Hard Constraints

Do not:

- update the upstream pin;
- remove dependencies;
- rewrite the UI;
- introduce a new framework;
- change installer behavior beyond what this session specifies.

## Required Verification

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop-Linux
git status --short
git submodule status --recursive
corepack yarn install --immutable
corepack yarn check
corepack yarn typecheck
corepack yarn test
```

Also verify: installer dry-run/check mode; GPU diagnostic command.

## Deliverables

- `docs/architecture/BASELINE-AUDIT.md`
- Documented inherited-versus-owned boundary
- Baseline command results and known failures
- Extended CachyOS installer with dry-run/check mode
- GPU diagnostics CLI/service scaffold (`scripts/linux/check-gpu.mjs`)

## Commit

`chore: establish desktop baseline and cachyos runtime`

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
