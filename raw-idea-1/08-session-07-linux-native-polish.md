# Session 07 — Linux Native Integration and Performance

## Objective

Make Linux/CachyOS feel native rather than a Windows/macOS port.

## Implement

### Window

- native Wayland/X11 compatibility;
- sensible default dimensions;
- remembered position/size where supported;
- high-DPI handling;
- fullscreen;
- minimize/restore;
- single-instance behavior.

### Tray

Implement as a plugin where platform APIs allow it.

### Desktop entry

Install:

```text
/usr/share/applications/dsh-desktop.desktop
```

Use a stable desktop ID and icon.

### MIME / URL behavior

Only register handlers that are actually implemented.

### Performance

Measure:

- cold startup;
- warm startup;
- first contentful paint;
- renderer memory;
- idle CPU;
- active GPU usage;
- plugin initialization time.

Avoid permanent polling.

## Performance plugin

Add a small optional diagnostics plugin exposing:

```text
FPS
Renderer
GPU
Vulkan
Memory
Plugin startup time
```

It should be disabled by default in production.

## Acceptance

- Wayland smoke test;
- X11 smoke test;
- single instance;
- tray;
- desktop menu launch;
- clean quit;
- no zombie DSH process.
