# Session 01 — Repository Baseline, Runtime Audit & CachyOS Installer

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop`.
> Read `00_MASTER_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal
Audit and stabilize the existing fork before feature work. Establish a reproducible CachyOS developer/runtime path using the existing Yarn/Cordis architecture.

### Agent instructions
- Work only in `/mnt/MD/Project/DSH/DSH-Desktop` for local execution.
- Inspect current tree, `AGENTS.md`, package manifests, scripts, profile files, tests, and the pinned submodule state.
- Do not edit `deepseek-harness/`.
- Preserve existing behavior unless a change is explicitly part of this session.

### Tasks
1. Record the current git SHA, submodule SHA, Node/Yarn versions, and available scripts.
2. Run the existing headless gate before changes. Capture failures.
3. Audit the existing Linux installer and CachyOS documentation. Remove any claim or behavior that performs an unnecessary full `pacman -Syu`.
4. Create/update a dedicated CachyOS installer that: checks OS, checks Node/Corepack/Yarn prerequisites, initializes the repo/runtime only when needed, detects GPU, installs only missing Vulkan runtime packages when authorized, builds the existing desktop package, installs a user-level launcher/desktop entry, and verifies the launch/runtime state.
5. Keep the one-line bootstrap command thin: it downloads a versioned installer from this fork and runs it; the installer performs checks and prints exactly what it changes.
6. Add `scripts/linux/check-gpu.mjs` or equivalent to report GPU vendor, Vulkan loader availability, Vulkan device list, and Electron/Chromium GPU diagnostics when the app is run.
7. Add `docs/architecture/baseline.md` describing what is inherited versus owned.

### Required verification
- `corepack yarn install --immutable`
- `corepack yarn typecheck`
- `corepack yarn test`
- `corepack yarn check` if the baseline is green; otherwise fix only baseline breakage or document it precisely.
- installer dry-run/check mode
- GPU diagnostic command

### Deliverables
- audited installer
- baseline architecture note
- current-state diagnostics
- updated CachyOS install docs

### Commit
`git add . && git commit -m "chore: establish desktop baseline and cachyos runtime"`


## Agent operating rules
- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
