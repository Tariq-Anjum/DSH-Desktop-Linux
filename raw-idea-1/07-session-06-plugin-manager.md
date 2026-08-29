# Session 06 — Plugin Manager, Settings and Feature Flags

## Objective

Make enable/disable operations a first-class user experience.

## AI prompt

Implement a plugin manager using the existing DSH/Cordis plugin workflow.

## UI

Create a plugin settings page:

```text
Installed
  [ON] Desktop Shell
  [ON] Sidebar
  [ON] Conversation
  [ON] Command Palette
  [ON] Vulkan Runtime
  [ON] Notifications
  [OFF] Anti-Gravity
  [OFF] Experimental Materials
```

Each plugin shows:

- name;
- description;
- version;
- status;
- dependencies;
- platform support;
- restart requirement;
- settings;
- diagnostics.

## Rules

Required plugins cannot be disabled.

Disabling a dependency must explain which plugins will be affected.

Plugin changes should be staged and then applied with one restart.

## Configuration

Use a namespaced configuration structure:

```yaml
dsh-desktop:
  plugins:
    enabled:
      - desktop-shell
      - ui-sidebar
      - ui-conversation
      - gpu-capability
      - vulkan-runtime
    disabled:
      - anti-gravity
```

Do not create a second incompatible plugin database.

## Safety

- invalid config falls back to defaults;
- unknown plugins remain preserved but inactive;
- plugin crash does not corrupt settings;
- configuration writes are atomic;
- restart is orderly.

## Tests

- enable;
- disable;
- dependency resolution;
- invalid config;
- upgrade;
- rollback;
- restart persistence.
