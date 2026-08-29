# Session 08 — Testing, Security, Reliability and Release Gates

## Objective

Turn the architecture into contractor-executable quality gates.

## Test layers

### Unit

- plugin graph;
- config;
- GPU probe parser;
- Vulkan policy;
- feature flags;
- lifecycle.

### Integration

- Host Cordis boot;
- Web client boot;
- plugin enable/disable;
- profile switch;
- restart;
- terminal;
- notification;
- diagnostics.

### Linux smoke

```bash
corepack yarn check
corepack yarn typecheck
corepack yarn test
corepack yarn package:dir
```

Then launch the packaged binary in a graphical CachyOS session.

## Security gates

Verify:

- renderer sandbox;
- context isolation;
- no Node integration;
- navigation restricted to loopback;
- external links use OS handlers;
- no arbitrary shell API exposed to renderer;
- plugin manifests cannot silently execute arbitrary renderer-native APIs;
- update/download paths validate expected artifacts;
- logs do not intentionally include secrets.

## Failure injection

Test:

- Vulkan absent;
- Vulkan command missing;
- GPU driver error;
- plugin load failure;
- plugin dependency missing;
- DSH subprocess crash;
- port conflict;
- malformed settings;
- corrupted profile;
- renderer crash;
- shutdown timeout.

## Release gates

A release is blocked if:

- required plugin fails;
- package omits runtime;
- Linux launcher is missing;
- desktop entry is invalid;
- Vulkan auto mode crashes;
- documentation describes nonexistent features;
- tests fail;
- local uncommitted generated artifacts are accidentally packaged.


# Final Session 10 — Build and Acceptance

# Session 10 — Final Build, Acceptance and Handoff

## Objective

Produce the contractor-ready MVP and prove the complete system.

## Full execution

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop

git status --short
git submodule update --init --recursive

corepack yarn install --immutable

corepack yarn check
corepack yarn typecheck
corepack yarn test

corepack yarn build
corepack yarn package:dir
```

## Runtime validation

Launch the packaged application and verify:

### Core

- application starts;
- DSH starts;
- profile loads;
- session works;
- conversation works;
- app closes cleanly;
- tray restores app.

### Plugins

- plugin list renders;
- optional plugin can be disabled;
- disabled plugin contributes no UI;
- plugin can be re-enabled;
- dependencies are enforced;
- restart applies staged changes.

### UI

- command bar;
- sidebar;
- session list;
- conversation;
- details;
- command palette;
- settings;
- status bar;
- keyboard navigation;
- dark/light/system theme.

### Graphics

Record:

```text
Session:
GPU:
Driver:
Electron:
Renderer:
Vulkan loader:
Vulkan API:
Selected mode:
Fallback:
```

Test:

- Vulkan working;
- Vulkan unavailable;
- explicit software mode.

### Linux

Test:

- CachyOS;
- Wayland;
- X11;
- desktop launcher;
- single instance;
- clean uninstall/reinstall.

## Acceptance scorecard

| Gate | Required |
|---|---|
| Build | PASS |
| Typecheck | PASS |
| Unit tests | PASS |
| Plugin graph | PASS |
| UI plugin enable/disable | PASS |
| Vulkan auto detection | PASS |
| Vulkan fallback | PASS |
| Wayland | PASS or documented platform limitation |
| X11 | PASS |
| CachyOS install | PASS |
| Desktop launcher | PASS |
| Security checks | PASS |
| Documentation | PASS |

## Final deliverables

Produce:

- source changes;
- updated README/docs;
- CachyOS package/installer;
- plugin architecture documentation;
- Vulkan documentation;
- test evidence;
- release notes;
- migration notes.

## Final engineering rule

Do not merge a feature because it looks good.

Merge it only when:

```text
implemented
+ composable
+ disableable
+ tested
+ documented
+ recoverable
= accepted
```
