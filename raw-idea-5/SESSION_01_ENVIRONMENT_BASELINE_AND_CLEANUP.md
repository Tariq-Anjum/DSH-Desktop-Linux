# Session 01: Environment Baseline, Repository Audit & CachyOS Toolchain Configuration

**Session ID:** SESSION-01  
**Title:** Environment Baseline, Repository Audit & CachyOS Toolchain Configuration  
**Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`  
**Pre-requisites:** CachyOS (Arch-based) clean installation or compatible Linux environment with root/sudo access  
**Target OS:** CachyOS (x86-64-v3 / x86-64-v4, linux-cachyos kernel with BORE/sched-ext scheduler)  
**Graphics API:** Vulkan Native Hardware Acceleration (`vulkan-icd-loader`, `vulkan-headers`, `vulkan-radeon`/`vulkan-intel`/`nvidia-utils`)  
**Core Architecture:** Monorepo Workspace (pnpm 9+, Node.js 22 LTS, Rust 1.80+ with CachyOS CPU microarchitecture flags)  
**Upstream Repositories:**  
- Architecture Reference: `https://github.com/Tariq-Anjum/DSH-Desktop-Linux`  
- Implementation Target: `https://github.com/Tariq-Anjum/dsh-desktop`

---

## 1. Goal & Objective

The primary objective of Session 01 is to establish an uncompromised, reproducible, and high-performance development baseline on **CachyOS** for the **DSH-Desktop** project. 

This session delivers:
1. Complete system-level dependency auditing and automated provisioning across pacman, rustup, and pnpm.
2. Architecture-optimized compiler flags (`x86-64-v3`/`x86-64-v4`, AVX2/AVX-512, `mold`/`lld` fast linkers) for both Rust native crates and C/C++ extensions.
3. Monorepo workspace configuration via `pnpm-workspace.yaml` and root TypeScript project references.
4. Baseline directory scaffolding across core micro-kernel modules, native daemons, and hot-pluggable plugin suites.
5. Deterministic verification scripts to assert environment integrity before subsequent sessions execute.

---

## 2. Pre-Flight Verification & Assertions

Before modifying any repository files, run the following pre-flight verification script to inspect host capabilities, CPU microarchitecture level, kernel schedulers, and package availability.

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== [DSH-Desktop] Session 01: Pre-Flight Verification ==="

# 1. Verify Target Operating System & Kernel
OS_ID=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL_VER=$(uname -r)
echo "[INFO] Detected OS: ${OS_ID}"
echo "[INFO] Detected Kernel: ${KERNEL_VER}"

# 2. Check CPU Microarchitecture Support (x86-64-v3 / v4)
if /lib64/ld-linux-x86-64.so.2 --help | grep -q "x86-64-v3 (supported, loaded)"; then
    echo "[PASS] CPU supports x86-64-v3 microarchitecture"
else
    echo "[WARN] x86-64-v3 not explicitly marked as loaded. Checking AVX2/BMI2 flags manually..."
    grep -E '(avx2|bmi2|fma)' /proc/cpuinfo > /dev/null && echo "[PASS] AVX2/BMI2 hardware instructions detected" || echo "[FAIL] CPU lacks required AVX2 instructions"
fi

# 3. Verify Target Worktree Mount & Directory Permissions
TARGET_DIR="/mnt/MD/Project/DSH/DSH-Desktop"
echo "[INFO] Asserting target worktree directory: ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
if [ ! -w "${TARGET_DIR}" ]; then
    echo "[FAIL] Target directory ${TARGET_DIR} is not writable."
    exit 1
fi
echo "[PASS] Target worktree directory is writable."

# 4. Check Core System Utilities
for cmd in git curl gcc clang lld mold pkg-config rustc cargo pnpm node bwrap; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[PASS] Command present: $cmd ($(command -v "$cmd"))"
    else
        echo "[MISSING] System command missing: $cmd (will be provisioned in bootstrap)"
    fi
done

echo "=== Pre-Flight Verification Completed ==="
```

---

## 3. Detailed File Operations & Complete Code Scaffolding

### 3.1 Repository Layout & Monorepo Structure

Create the following explicit directory hierarchy inside `/mnt/MD/Project/DSH/DSH-Desktop`:

```
/mnt/MD/Project/DSH/DSH-Desktop/
├── .cargo/
│   └── config.toml
├── .github/
│   └── workflows/
│       └── ci.yml
├── .gitignore
├── .npmrc
├── .nvmrc
├── package.json
├── pnpm-workspace.yaml
├── tsconfig.base.json
├── tsconfig.json
├── scripts/
│   ├── bootstrap-cachyos.sh
│   ├── audit-env.sh
│   └── build-all.sh
├── packages/
│   ├── kernel-core/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       └── index.ts
│   ├── ipc-protocol/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       └── index.ts
│   ├── sandbox-host/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── main.rs
│   ├── native-shell/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       └── index.ts
│   └── ui-shell/
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           └── index.ts
└── plugins/
    ├── README.md
    └── .gitkeep
```

---

### 3.2 File Implementations

#### File: `scripts/bootstrap-cachyos.sh`
```bash
#!/usr/bin/env bash
# ==============================================================================
# DSH-Desktop CachyOS System Toolchain & Dependency Provisioner
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " Starting DSH-Desktop CachyOS Toolchain Bootstrap"
echo " Target Worktree: /mnt/MD/Project/DSH/DSH-Desktop"
echo "======================================================================"

# Ensure running on an Arch-based / CachyOS system
if [ ! -f /etc/arch-release ] && [ ! -f /etc/cachyos-release ]; then
    echo "[WARN] /etc/arch-release or /etc/cachyos-release not found. Proceeding with caution..."
fi

# 1. System Package Provisioning via pacman
echo "[1/5] Synchronizing and installing native packages..."
PACKAGES=(
    base-devel
    git
    curl
    wget
    clang
    llvm
    lld
    mold
    pkgconf
    rustup
    nodejs
    npm
    pnpm
    vulkan-devel
    vulkan-tools
    vulkan-headers
    vulkan-icd-loader
    mesa
    bubblewrap
    libseccomp
    wayland
    wayland-protocols
    libxkbcommon
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    nss
    nspr
    alsa-lib
    dbus
    libsecret
)

if command -v pacman >/dev/null 2>&1; then
    if [ "$EUID" -eq 0 ]; then
        pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
    elif command -v sudo >/dev/null 2>&1; then
        sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
    else
        echo "[ERROR] Root access or sudo required to install dependencies via pacman."
        exit 1
    fi
else
    echo "[SKIP] pacman not detected in this container/environment. Ensuring user binaries exist."
fi

# 2. Rust Toolchain Configuration
echo "[2/5] Configuring Rust toolchain via rustup..."
if command -v rustup >/dev/null 2>&1; then
    rustup default stable
    rustup component add rustfmt clippy rust-src
else
    echo "[INFO] rustup not found directly; checking cargo..."
    if ! command -v cargo >/dev/null 2>&1; then
        echo "[ERROR] Cargo is missing. Please ensure Rust is installed."
        exit 1
    fi
fi

# 3. Node & pnpm Setup
echo "[3/5] Verifying Node.js and pnpm..."
NODE_VERSION=$(node -v || echo "none")
PNPM_VERSION=$(pnpm -v || echo "none")
echo "[INFO] Active Node: ${NODE_VERSION}"
echo "[INFO] Active pnpm: ${PNPM_VERSION}"

# 4. Bubblewrap Capabilities Verification
echo "[4/5] Checking bubblewrap permissions..."
if command -v bwrap >/dev/null 2>&1; then
    BWRAP_PATH=$(command -v bwrap)
    echo "[INFO] bwrap binary located at: ${BWRAP_PATH}"
    # Verify unprivileged user namespace or setuid
    if bwrap --ro-bind / / /bin/true 2>/dev/null; then
        echo "[PASS] Bubblewrap sandbox execution validated."
    else
        echo "[WARN] bwrap requires user namespaces (kernel.unprivileged_userns_clone=1) or SUID bit."
    fi
fi

# 5. Vulkan ICD Diagnostics
echo "[5/5] Checking Vulkan ICD configurations..."
if [ -d "/usr/share/vulkan/icd.d" ]; then
    echo "[INFO] Available Vulkan ICD drivers:"
    ls -l /usr/share/vulkan/icd.d/ || true
else
    echo "[WARN] /usr/share/vulkan/icd.d not found. Hardware Vulkan ICDs might need configuration."
fi

echo "======================================================================"
echo " CachyOS Toolchain Bootstrap Succeeded"
echo "======================================================================"
```

#### File: `.cargo/config.toml`
```toml
[target.x86_64-unknown-linux-gnu]
# Use the high-performance mold linker if available, otherwise lld
linker = "clang"
rustflags = [
    "-C", "link-arg=-fuse-ld=mold",
    "-C", "target-cpu=x86-64-v3",
    "-C", "opt-level=3",
    "-C", "codegen-units=1",
    "-C", "panic=abort",
    "-C", "relocation-model=pic"
]

[build]
target = "x86_64-unknown-linux-gnu"
incremental = false

[profile.release]
opt-level = 3
lto = "fat"
codegen-units = 1
panic = "abort"
strip = true

[profile.dev]
opt-level = 1
debug = 2
incremental = true
```

#### File: `package.json`
```json
{
  "name": "dsh-desktop-monorepo",
  "version": "0.1.0",
  "private": true,
  "description": "DSH-Desktop: Modular AI Agent Operating Workspace on CachyOS",
  "packageManager": "pnpm@9.7.1",
  "type": "module",
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  },
  "scripts": {
    "audit:env": "bash scripts/audit-env.sh",
    "bootstrap": "bash scripts/bootstrap-cachyos.sh",
    "build": "pnpm -r --filter './packages/**' build",
    "build:native": "cargo build --release --manifest-path packages/sandbox-host/Cargo.toml",
    "build:all": "bash scripts/build-all.sh",
    "test": "pnpm -r --filter './packages/**' test",
    "lint": "pnpm -r --filter './packages/**' lint",
    "typecheck": "tsc -b tsconfig.json",
    "clean": "pnpm -r exec rimraf dist .turbo target && rimraf node_modules"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "rimraf": "^6.0.1",
    "typescript": "^5.5.4"
  }
}
```

#### File: `pnpm-workspace.yaml`
```yaml
packages:
  - 'packages/*'
  - 'plugins/*'
```

#### File: `.npmrc`
```ini
auto-install-peers=true
dedupe-peer-dependents=true
shamefully-hoist=false
strict-peer-dependencies=false
prefer-frozen-lockfile=true
```

#### File: `.nvmrc`
```
22.5.0
```

#### File: `.gitignore`
```gitignore
# Dependencies
node_modules/
.pnpm-store/

# Build outputs
dist/
build/
out/
target/
*.o
*.so
*.dylib
*.dll
*.wasm

# TypeScript
*.tsbuildinfo

# Environment and secrets
.env
.env.local
.env.*.local
*.pem
*.key

# Sandboxes & Temporary execution worktrees
/tmp/
/run/
/workspace/
/sandbox/
.dsh_agent_socket*

# OS and IDE files
.DS_Store
Thumbs.db
.idea/
.vscode/
*.swp
*.swo
```

#### File: `tsconfig.base.json`
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "composite": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": false
  }
}
```

#### File: `tsconfig.json`
```json
{
  "files": [],
  "references": [
    { "path": "./packages/kernel-core" },
    { "path": "./packages/ipc-protocol" },
    { "path": "./packages/native-shell" },
    { "path": "./packages/ui-shell" }
  ]
}
```

#### File: `scripts/audit-env.sh`
```bash
#!/usr/bin/env bash
# ==============================================================================
# DSH-Desktop Environment Auditor & Microarchitecture Checker
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " Running DSH-Desktop Baseline Audit"
echo "======================================================================"

EXIT_CODE=0

# Check Node.js
if command -v node >/dev/null 2>&1; then
    NODE_MAJ=$(node -v | cut -d'.' -f1 | tr -d 'v')
    if [ "$NODE_MAJ" -ge 20 ]; then
        echo "[PASS] Node.js version $(node -v) (>= 20.0.0 requirement met)"
    else
        echo "[FAIL] Node.js version $(node -v) is below 20.0.0"
        EXIT_CODE=1
    fi
else
    echo "[FAIL] Node.js is not installed."
    EXIT_CODE=1
fi

# Check pnpm
if command -v pnpm >/dev/null 2>&1; then
    echo "[PASS] pnpm version $(pnpm -v) installed."
else
    echo "[FAIL] pnpm is not installed. Run 'npm install -g pnpm'"
    EXIT_CODE=1
fi

# Check Cargo / Rustc
if command -v rustc >/dev/null 2>&1; then
    echo "[PASS] Rustc $(rustc --version) available."
else
    echo "[FAIL] Rust compiler not found."
    EXIT_CODE=1
fi

# Check Bubblewrap
if command -v bwrap >/dev/null 2>&1; then
    echo "[PASS] Bubblewrap binary found at $(command -v bwrap)"
else
    echo "[WARN] Bubblewrap (bwrap) not found in PATH."
fi

# Check Vulkan Loader
if command -v vulkaninfo >/dev/null 2>&1; then
    echo "[PASS] vulkaninfo is available."
elif [ -f /usr/lib/libvulkan.so ] || [ -f /usr/lib64/libvulkan.so ]; then
    echo "[PASS] libvulkan.so shared object found."
else
    echo "[WARN] Vulkan development libraries may be missing."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "======================================================================"
    echo " All core baseline checks PASSED."
    echo "======================================================================"
else
    echo "======================================================================"
    echo " Baseline audit failed with one or more errors."
    echo "======================================================================"
fi

exit $EXIT_CODE
```

#### File: `scripts/build-all.sh`
```bash
#!/usr/bin/env bash
# ==============================================================================
# DSH-Desktop Master Build Script (Packages + Rust Native Extensions)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "======================================================================"
echo " Building DSH-Desktop Monorepo Workspaces"
echo " Working Directory: ${ROOT_DIR}"
echo "======================================================================"

# 1. Typecheck and build TypeScript packages
echo "[1/2] Compiling TypeScript workspaces..."
pnpm install
pnpm typecheck
pnpm build

# 2. Build Rust native sandbox host
echo "[2/2] Compiling Rust native sandbox host (x86-64-v3 optimized)..."
if [ -f "packages/sandbox-host/Cargo.toml" ]; then
    cargo build --release --manifest-path packages/sandbox-host/Cargo.toml
fi

echo "======================================================================"
echo " Master Build Completed Successfully"
echo "======================================================================"
```

---

### 3.3 Initial Package Scaffolding

#### Package: `packages/kernel-core/package.json`
```json
{
  "name": "@dsh/kernel-core",
  "version": "0.1.0",
  "description": "DSH-Desktop Micro-Kernel and Cordis Plugin Core Runtime",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc -b",
    "typecheck": "tsc -b --noEmit",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "cordis": "^3.18.1",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "typescript": "^5.5.4"
  }
}
```

#### Package: `packages/kernel-core/tsconfig.json`
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"]
}
```

#### Package: `packages/kernel-core/src/index.ts`
```typescript
/**
 * @dsh/kernel-core
 * Initial package entrypoint placeholder for Session 01 baseline.
 */
export const KERNEL_VERSION = "0.1.0";
export const RUNTIME_NAME = "DSH-Cordis-MicroKernel";
```

#### Package: `packages/ipc-protocol/package.json`
```json
{
  "name": "@dsh/ipc-protocol",
  "version": "0.1.0",
  "description": "Host-Agent IPC Protocols, Schema Definitions & ACL Engine",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc -b",
    "typecheck": "tsc -b --noEmit",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "typescript": "^5.5.4"
  }
}
```

#### Package: `packages/ipc-protocol/tsconfig.json`
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"]
}
```

#### Package: `packages/ipc-protocol/src/index.ts`
```typescript
/**
 * @dsh/ipc-protocol
 * Initial package entrypoint placeholder for Session 01 baseline.
 */
export const IPC_PROTOCOL_VERSION = "1.0.0";
export const SOCKET_NAME_DEFAULT = "dsh-agent.sock";
```

#### Package: `packages/sandbox-host/Cargo.toml`
```toml
[package]
name = "dsh-sandbox-host"
version = "0.1.0"
edition = "2021"
authors = ["DSH Architecture Team"]
description = "Native Bubblewrap Sandbox Daemon and Host IPC Enforcement Engine"

[dependencies]
tokio = { version = "1.39", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
nix = { version = "0.29", features = ["process", "signal", "user", "fs"] }
libseccomp = "0.3"
anyhow = "1.0"
thiserror = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

#### Package: `packages/sandbox-host/src/main.rs`
```rust
//! DSH-Desktop Native Sandbox Daemon Entrypoint
//! Provides host-level process isolation, Bubblewrap orchestration, and UNIX domain socket listeners.

use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    tracing::info!("DSH Sandbox Host Daemon initializing on CachyOS...");
    tracing::info!("Target CPU microarchitecture: x86-64-v3/v4 native");
    tracing::info!("Sandbox driver: Bubblewrap (/usr/bin/bwrap) + Seccomp BPF");
    println!("DSH Sandbox Host Daemon v0.1.0 ready.");
    Ok(())
}
```

#### Package: `packages/native-shell/package.json`
```json
{
  "name": "@dsh/native-shell",
  "version": "0.1.0",
  "description": "Vulkan-accelerated Native Shell Bootstrap and Electron Integration",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc -b",
    "typecheck": "tsc -b --noEmit",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "@dsh/kernel-core": "workspace:*",
    "@dsh/ipc-protocol": "workspace:*"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "electron": "^32.0.1",
    "typescript": "^5.5.4"
  }
}
```

#### Package: `packages/native-shell/tsconfig.json`
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../kernel-core" },
    { "path": "../ipc-protocol" }
  ]
}
```

#### Package: `packages/native-shell/src/index.ts`
```typescript
/**
 * @dsh/native-shell
 * Initial package entrypoint placeholder for Session 01 baseline.
 */
export const SHELL_NAME = "DSH-Native-Shell";
export const GRAPHICS_BACKEND_DEFAULT = "Vulkan";
```

#### Package: `packages/ui-shell/package.json`
```json
{
  "name": "@dsh/ui-shell",
  "version": "0.1.0",
  "description": "Modular UI Shell, Dynamic Slotting Architecture & Theme Engine",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc -b",
    "typecheck": "tsc -b --noEmit",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "@dsh/kernel-core": "workspace:*"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "typescript": "^5.5.4"
  }
}
```

#### Package: `packages/ui-shell/tsconfig.json`
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../kernel-core" }
  ]
}
```

#### Package: `packages/ui-shell/src/index.ts`
```typescript
/**
 * @dsh/ui-shell
 * Initial package entrypoint placeholder for Session 01 baseline.
 */
export const UI_SHELL_VERSION = "0.1.0";
```

#### File: `plugins/README.md`
```markdown
# DSH-Desktop Plugins Directory

This directory hosts dynamically loaded, hot-pluggable Cordis plugins.
Each plugin is an independent package implementing the standard Cordis plugin interface with an accompanying `manifest.json`.
```

---

## 4. Capability & Security Declarations

1. **System Toolchain Boundary:**
   - Package manager execution (`pacman`, `rustup`, `pnpm`) is restricted to the host bootstrap phase.
   - Rust compilation utilizes `-C relocation-model=pic` and memory safety guarantees.
2. **Path Containment:**
   - All builds operate strictly within `/mnt/MD/Project/DSH/DSH-Desktop`.
   - Node workspaces are isolated through `pnpm` virtual stores to prevent dependency leakage.

---

## 5. Step-by-Step AI Execution Instructions

1. **Initialize Worktree & Filesystem:**
   - Execute `mkdir -p /mnt/MD/Project/DSH/DSH-Desktop`.
   - Change working directory: `cd /mnt/MD/Project/DSH/DSH-Desktop`.
2. **Deploy Configuration Files:**
   - Write `.cargo/config.toml` with x86-64-v3 flags.
   - Write root `package.json`, `pnpm-workspace.yaml`, `.npmrc`, `.gitignore`, `tsconfig.base.json`, `tsconfig.json`.
3. **Scaffold Package Hierarchy:**
   - Create directories for `packages/kernel-core`, `packages/ipc-protocol`, `packages/sandbox-host`, `packages/native-shell`, `packages/ui-shell`, and `plugins`.
   - Populate corresponding `package.json`, `tsconfig.json`, `Cargo.toml`, and initial source entrypoints.
4. **Deploy Automation Scripts:**
   - Create `scripts/bootstrap-cachyos.sh`, `scripts/audit-env.sh`, and `scripts/build-all.sh`.
   - Make all scripts executable: `chmod +x scripts/*.sh`.
5. **Execute Baseline Validation:**
   - Run `bash scripts/audit-env.sh`.

---

## 6. Validation & Verification Commands

Execute the following commands sequentially to confirm the session deliverable status:

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop

# 1. Audit Environment
bash scripts/audit-env.sh

# 2. Assert Workspace Structure
test -f package.json
test -f pnpm-workspace.yaml
test -f .cargo/config.toml
test -f tsconfig.base.json
test -f packages/kernel-core/package.json
test -f packages/ipc-protocol/package.json
test -f packages/sandbox-host/Cargo.toml
test -f packages/native-shell/package.json
test -f packages/ui-shell/package.json

echo "[SUCCESS] Session 01 Environment Baseline structure verified."
```

---

## 7. Definition of Done

- [ ] CachyOS development prerequisites inspected and verified.
- [ ] Optimized `.cargo/config.toml` generated with `target-cpu=x86-64-v3` and `mold`/`lld` linkers.
- [ ] Root `package.json` and `pnpm-workspace.yaml` configured.
- [ ] Monorepo package directory structure fully scaffolded without ellipses or placeholders.
- [ ] `scripts/bootstrap-cachyos.sh`, `scripts/audit-env.sh`, and `scripts/build-all.sh` implemented and executable.
- [ ] Baseline audit command executes cleanly with exit code 0.
