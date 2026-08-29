# Session 10 — Vulkan Validation, Packaging, Documentation & Release

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop`.
> Read `00_MASTER_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal
Turn the work into a verifiable CachyOS release without overstating Vulkan support.

### Vulkan
1. Add a GPU diagnostics page/CLI showing vendor, renderer, API version, Electron GPU feature status, and selected backend.
2. Prefer Vulkan through supported Chromium/Electron configuration when verified on the target environment.
3. Keep automatic fallback.
4. Do not use `--ignore-gpu-blocklist` as a normal production flag.
5. Do not describe Monaco, terminal, browser, or screenshots as directly Vulkan-rendered unless the implementation actually uses a Vulkan rendering path.
6. Add a benchmark/smoke report for startup time, renderer responsiveness, memory, and GPU feature status.

### Packaging
1. Build Linux artifacts suitable for CachyOS/Arch distribution.
2. Provide a user-friendly one-line installer that points at the fork's versioned installer script.
3. Never pipe an unpinned remote shell into root. The installer must run unprivileged except for explicitly required package installation steps and must explain those steps.
4. Prefer user-local application installation for development builds; package/AUR instructions may be separate.

### Documentation
Update, in one coherent pass:
- root README
- `dsh-plugin-desktop/README.md`
- CachyOS installation guide
- architecture docs
- plugin authoring docs
- security model
- GPU/Vulkan diagnostics
- troubleshooting
- contribution/agent instructions
- release notes/changelog

### Final verification
- clean checkout from the fork
- submodule initialization
- immutable dependency install
- build
- typecheck
- unit tests
- runtime closure
- loader/profile smokes
- security tests
- packaging tests
- CachyOS install test
- launch test
- plugin enable/disable test
- compatibility mode test

### Deliverables
- release-ready tree
- verified one-line installer
- complete documentation
- reproducible verification report

### Commit
`git add . && git commit -m "release: validate cachyos build and finalize documentation"`


## Agent operating rules
- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
