# CachyOS One-Line Installation (Development Build)

This document describes the recommended one-line installation pattern for DSH Desktop Linux on CachyOS/Arch-based systems.

## One-Line Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/Tariq-Anjum/DSH-Desktop-Linux/main/scripts/install-cachyos.sh -o install-cachyos.sh && chmod +x install-cachyos.sh && ./install-cachyos.sh
```

This command:

1. Downloads a versioned installer script from this repository.
2. Makes it executable.
3. Runs it in your user session.

The installer itself:

- Verifies OS compatibility (CachyOS/Arch/Manjaro/EndeavourOS, with a manual override).
- Checks for `git`, `node`, and `corepack` and explains missing prerequisites.
- Detects your GPU and reports recommended Vulkan userspace packages.
- Asks before installing any Vulkan packages; never silently replaces your NVIDIA driver.
- Clones or updates the repository into `~/.local/dsh-desktop-linux` (or `$DSH_INSTALL_DIR`).
- Runs `corepack yarn install --immutable`, `yarn check`, and `yarn build`.
- Installs a user-local launcher (`~/.local/bin/dsh-desktop-linux`) and `.desktop` entry.
- Runs a non-destructive smoke check.

## Manual Alternative (Local Checkout)

If you already have a local checkout at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`, you can use:

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop-Linux && \
  git submodule update --init --recursive && \
  corepack enable && \
  corepack yarn install --immutable && \
  corepack yarn check && \
  corepack yarn build && \
  corepack yarn start
```

This assumes:

- Node.js and Corepack are already installed.
- Required system build dependencies (git, base-devel, Vulkan/Mesa as needed) are present.

## GPU And Vulkan Notes

- The installer will detect AMD, Intel, or NVIDIA GPUs and print recommended Vulkan packages.
- It will not auto-install NVIDIA kernel drivers; you must choose `nvidia`, `nvidia-dkms`, `nvidia-open`, etc. yourself.
- Vulkan is preferred on CachyOS only when the runtime probe confirms a working configuration.
- If Vulkan is unavailable, the application will fall back to normal accelerated Chromium paths.

## Uninstall

To remove a user-local installation:

```bash
rm -rf ~/.local/dsh-desktop-linux
rm -f ~/.local/bin/dsh-desktop-linux
rm -f ~/.local/share/applications/dsh-desktop-linux.desktop
rm -f ~/.local/share/icons/hicolor/256x256/apps/dsh-desktop-linux.png
```

Then refresh your desktop database if needed:

```bash
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```
