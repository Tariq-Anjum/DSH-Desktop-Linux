# Session 03 — UI as Plugins and Interface Redesign

## Objective

Improve the interface without creating a monolith.

## AI prompt

Refactor the desktop UI so major visual surfaces are independently composable Cordis/UI plugins.

## Target layout

```text
┌──────────────────────────────────────────────────────────────┐
│ DSH command bar | profile | GPU/Vulkan | commands            │
├─────────────┬──────────────────────────────┬─────────────────┤
│ Workspace   │ Conversation / Agent         │ Inspector       │
│ + Sessions  │                              │                 │
│ + Plugins   │                              │                 │
│ + Search    │                              │                 │
├─────────────┴──────────────────────────────┴─────────────────┤
│ Status / task progress / model / runtime / plugin indicators │
└──────────────────────────────────────────────────────────────┘
```

## UI plugins

Each must be independently disableable:

- `ui-command-bar`
- `ui-sidebar`
- `ui-session-list`
- `ui-conversation`
- `ui-details`
- `ui-command-palette`
- `ui-status-bar`
- `ui-settings`
- `ui-plugin-manager`

## UX requirements

- keyboard-first;
- command palette shortcut;
- resizable sidebar and inspector;
- persistent layout;
- reduced-motion setting;
- high contrast;
- system/light/dark theme;
- empty/loading/error states;
- responsive minimum window dimensions;
- no hidden blocking modal for normal actions.

## Visual design direction

Use the existing component system and design tokens where possible. Prefer restrained desktop glass/material effects rather than animation-heavy effects.

## Plugin rule

No UI plugin may import Electron directly.

Native behavior must go through typed Desktop services.

## Acceptance tests

- disable sidebar;
- disable inspector;
- disable command palette;
- disable visual effects;
- disable status bar;
- start with all optional UI plugins disabled;
- restore all plugins;
- verify settings persist.
