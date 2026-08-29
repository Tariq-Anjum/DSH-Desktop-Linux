# Session 09 — Documentation, Repository Cleanup and Final Validation

## Objective

Synchronize every project-facing document with the implemented product.

## Update

- `README.md`
- `README.en.md`
- `README.zh.md`
- `INSTALL_CACHYOS.md`
- `CONTRIBUTING.md`
- `CONTRIBUTING.en.md`
- `AGENTS.md`
- `CLAUDE.md`
- plugin README files
- architecture docs
- privacy docs if behavior changed
- release notes
- `.desktop` documentation
- plugin developer documentation

## Documentation truth policy

Every feature in README must point to:

1. implementation;
2. test;
3. configuration;
4. support status.

Remove unsupported claims.

In particular, do not call an Electron canvas feature "Vulkan" unless the actual implementation uses/depends on Vulkan in a technically defensible way.

## Add

`docs/PLUGIN_ARCHITECTURE.md`

Include:

- plugin lifecycle;
- manifest;
- dependencies;
- UI slots;
- native services;
- settings;
- examples;
- testing;
- failure handling.

Add:

`docs/VULKAN.md`

Include:

- detection;
- supported GPUs;
- Wayland/X11 behavior;
- auto mode;
- explicit override;
- diagnostics;
- fallback.

## Repository hygiene

Check:

```bash
git status --short
git diff --check
```

Remove generated artifacts from source control unless intentionally required.

## Exit criteria

A new contractor can clone the repository and understand:

- how it starts;
- how plugins work;
- how UI is composed;
- how Vulkan works;
- how CachyOS installation works;
- how to add a plugin;
- how to run tests.
