# Session 04 — Vulkan Capability, Detection and Safe Default

## Objective

Make Vulkan a first-class graphics capability on CachyOS while preserving reliability.

## Important engineering decision

Do NOT simply force Vulkan for every Electron/Wayland session.

Electron's current documentation exposes GPU-selection switches, but Linux Vulkan behavior can vary by Electron/Chromium version, compositor, GPU and driver. In particular, current Electron issue reports document Wayland/Vulkan incompatibilities in some configurations.

Therefore implement:

```text
GPU probe
   |
   +-- Vulkan available + validated --> Vulkan preferred
   |
   +-- Vulkan unavailable -----------> normal accelerated Chromium path
   |
   +-- GPU broken -------------------> safe fallback
```

## Plugin architecture

Create:

```text
gpu-capability
  └── gpuInfo service

vulkan-runtime
  └── vulkanStatus service
  └── preferredGraphicsMode setting

visual-effects
  └── optional GPU effects
```

## Probe

At startup collect:

- OS;
- session type: X11/Wayland;
- GPU vendor;
- renderer;
- driver;
- Vulkan loader presence;
- Vulkan API version;
- selected Electron GPU backend;
- hardware acceleration state.

Use system tools only from a native service, not the renderer.

Suggested Linux checks:

```bash
command -v vulkaninfo
vulkaninfo --summary
echo "$XDG_SESSION_TYPE"
lspci -nn | grep -Ei 'vga|3d|display'
```

Do not make `vulkaninfo` a runtime hard dependency.

## Electron policy

Implement a graphics policy service that decides whether to request Vulkan-related Chromium features.

The policy must support:

```yaml
graphics:
  mode: auto        # auto | vulkan | accelerated | software
  requireVulkan: false
  effects: true
```

Default on CachyOS:

```yaml
graphics:
  mode: auto
```

`auto` prefers Vulkan only after validation.

`vulkan` is an explicit user override and must still report failures.

`software` is the emergency diagnostic mode.

## Renderer

Use GPU acceleration for canvas/WebGL/WebGPU-style effects only where supported. Do not pretend a React canvas is "Vulkan" merely because Electron has GPU acceleration.

If a feature truly needs Vulkan compute/rendering, isolate it behind a native capability boundary.

## Acceptance

- AMD Vulkan;
- Intel Vulkan;
- NVIDIA Vulkan;
- missing Vulkan;
- broken Vulkan;
- Wayland;
- X11;
- software fallback.

No startup failure when Vulkan is unavailable.
