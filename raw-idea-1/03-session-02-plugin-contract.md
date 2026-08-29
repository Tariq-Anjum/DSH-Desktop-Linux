# Session 02 — Unified Cordis Plugin Contract

## Objective

Turn the "everything is a plugin" vision into enforceable contracts.

## AI prompt

Design and implement a typed plugin metadata/registration contract that sits on top of the existing Cordis composition model without replacing it.

## Required plugin categories

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
  ui-settings
  ui-plugin-manager

system:
  system-tray
  notifications
  updates
  diagnostics
  terminal
  linux-integration

graphics:
  gpu-capability
  vulkan-runtime
  visual-effects

experimental:
  anti-gravity
  enhanced-materials
```

## Contract

Define a schema equivalent to:

```ts
interface DesktopPluginManifest {
  id: string
  version: string
  kind: 'host' | 'client' | 'native' | 'hybrid'
  enabledByDefault: boolean
  required?: boolean
  dependencies?: string[]
  optionalDependencies?: string[]
  capabilities?: string[]
  slots?: string[]
  settingsNamespace?: string
  platforms?: ('linux' | 'win32' | 'darwin')[]
}
```

Do not duplicate Cordis's actual loader contract. Adapt to it.

## Required behavior

- disabled plugin does not register its effects;
- dependent plugin receives a deterministic unavailable state;
- disposal removes all registrations;
- duplicate IDs fail deterministically;
- incompatible platform/plugin combinations are skipped with diagnostics;
- required plugin failure stops startup;
- optional plugin failure does not stop startup.

## Tests

Add tests for:

1. enable;
2. disable;
3. dependency;
4. optional dependency;
5. duplicate plugin;
6. disposal;
7. platform gating;
8. plugin startup failure;
9. plugin settings persistence.

## Exit criteria

The application can describe its desktop capabilities as a plugin graph and tests prove enable/disable behavior.
