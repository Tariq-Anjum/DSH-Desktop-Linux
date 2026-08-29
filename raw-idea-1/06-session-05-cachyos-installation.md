# Session 05 — CachyOS Installation, Packaging and One-Line Command

## Objective

Make local-source and release installation deterministic on CachyOS.

## One-line local installation/build command

For the requested local checkout, the recommended one-liner is:

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop && git submodule update --init --recursive && corepack yarn install --immutable && corepack yarn check && corepack yarn build && corepack yarn start
```

This assumes Node/Corepack and the repository's required system build dependencies are already available.

## One-line prerequisite + local build command

Use a separate documented prerequisite step rather than blindly installing GPU drivers:

```bash
sudo pacman -Syu --needed base-devel git nodejs npm vulkan-tools mesa && cd /mnt/MD/Project/DSH/DSH-Desktop && corepack enable && git submodule update --init --recursive && corepack yarn install --immutable && corepack yarn check && corepack yarn build && corepack yarn start
```

Do not automatically install NVIDIA kernel drivers because selecting `nvidia`, `nvidia-open`, or DKMS variants must match the user's GPU/kernel.

## Installation strategy

Implement:

1. source install;
2. unpacked local package;
3. Arch/CachyOS package;
4. `.desktop` launcher;
5. optional systemd user service only if explicitly enabled;
6. release artifact installation.

## Package requirements

The CachyOS package must:

- depend on appropriate Electron runtime strategy;
- declare filesystem paths;
- install desktop entry;
- install icon;
- install launcher;
- not overwrite user configuration;
- not require global Node;
- expose `dsh-desktop`.

## GPU dependencies

Use detection:

```text
AMD      -> vulkan-radeon
Intel    -> vulkan-intel
NVIDIA   -> user-selected compatible NVIDIA driver + Vulkan userspace
generic  -> vulkan-loader/vulkan-tools/mesa where appropriate
```

Never silently replace an existing NVIDIA driver.

## Launcher

Create:

`dsh-desktop-launcher`

It should:

- detect session;
- set safe environment;
- start packaged Electron;
- preserve diagnostic flags;
- report Vulkan status.

## Exit criteria

A fresh CachyOS machine can install and launch from a documented single command after the correct base GPU driver is present.
