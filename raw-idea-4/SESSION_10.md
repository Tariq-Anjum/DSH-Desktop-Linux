# Session 10 — Vulkan Validation, Packaging, Docs, Release

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Vulkan And GPU Policy, CachyOS
> Installation Principle, Final Acceptance Gate) and the repository's `AGENTS.md` first.

## Goal

Turn the work into a verifiable CachyOS release without overstating Vulkan support.

## Vulkan

1. Add a GPU diagnostics page/CLI showing vendor, renderer, API version, Electron GPU
   feature status, and selected backend.
2. Prefer Vulkan through supported Chromium/Electron configuration only when verified on
   the target environment.
3. Keep automatic fallback.
4. Do not use `--ignore-gpu-blocklist` as a normal production flag.
5. Do not describe Monaco, terminal, browser, or screenshots as directly Vulkan-rendered
   unless the implementation actually uses a Vulkan rendering path.
6. Add a benchmark/smoke report for startup time, renderer responsiveness, memory, and
   GPU feature status.

## Packaging

1. Build Linux artifacts suitable for CachyOS/Arch distribution.
2. Provide a user-friendly one-line installer that points at the fork's versioned
   installer script (`scripts/install-cachyos.sh`).
3. Never pipe an unpinned remote shell into root. The installer must run unprivileged
   except for explicitly required package installation steps and must explain those
   steps.
4. Prefer user-local application installation for development builds; package/AUR
   instructions may be separate.

## Documentation

Update, in one coherent pass:

- Root README
- `dsh-plugin-desktop/README.md`
- CachyOS installation guide
- `docs/architecture/*`
- `docs/PLUGIN_ARCHITECTURE.md`
- `docs/SECURITY_MODEL.md`
- `docs/VULKAN.md`
- Plugin authoring docs
- Troubleshooting
- Contribution/agent instructions (`AGENTS.md`)
- Release notes/changelog

## Final Verification

- Clean checkout from the fork
- Submodule initialization
- Immutable dependency install
- Build
- Typecheck
- Unit tests
- Runtime closure
- Loader/profile smokes
- Security tests
- Packaging tests
- CachyOS install test
- Launch test
- Plugin enable/disable test
- Compatibility mode test

## Deliverables

- Release-ready tree
- Verified one-line installer
- Complete documentation
- Reproducible verification report

## Commit

`release: validate cachyos build and finalize documentation`

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
