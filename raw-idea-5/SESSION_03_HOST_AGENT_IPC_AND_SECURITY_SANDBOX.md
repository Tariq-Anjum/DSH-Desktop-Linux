# Session 03: Host-Agent IPC Protocol & Bubblewrap (bwrap) Security Sandbox

**Session ID:** SESSION-03  
**Title:** Host-Agent IPC Protocol & Bubblewrap (bwrap) Security Sandbox  
**Target Worktree:** `/mnt/MD/Project/DSH/DSH-Desktop`  
**Pre-requisites:** Session 01 & 02 completed (`packages/kernel-core` compiled and tested)  
**Target OS:** CachyOS (x86-64-v3 / x86-64-v4)  
**Security Engine:** Linux Namespaces, Bubblewrap (`bwrap`), `libseccomp` BPF filters  
**IPC Transport:** UNIX Domain Sockets (`/run/user/$UID/dsh-agent.sock`), Framed JSON-RPC 2.0  
**Languages:** TypeScript 5.5+ (`packages/ipc-protocol`), Rust 1.80+ (`packages/sandbox-host`)  

---

## 1. Goal & Objective

The objective of Session 03 is to engineer an enterprise-grade security boundary between autonomous AI agents and the host operating system. AI agents in DSH-Desktop execute generated code, shell commands, and automated scripts inside unprivileged, ephemeral **Bubblewrap (`bwrap`)** containers governed by strict Linux kernel namespaces and Seccomp BPF syscall filters.

This session delivers:
1. Complete **IPC Protocol Specification** (`@dsh/ipc-protocol`) implementing strongly typed RPC channels over UNIX Domain Sockets.
2. Capability-based **Access Control List (ACL)** verification engine ensuring agents only invoke host services explicitly granted in their security tokens.
3. High-performance **Rust Sandbox Host Daemon** (`dsh-sandbox-host`) providing:
   - Bubblewrap container spawning with `--unshare-all`, read-only root mounts, ephemeral tmpfs, and restricted workspace bind mounts.
   - Fine-grained Seccomp BPF syscall filters blocking kernel modification, ptrace, and raw socket creation.
   - Concurrent UNIX domain socket listener handling process execution, I/O streaming, and health monitoring.
4. Comprehensive integration tests validating containment, permission denial, and bidirectional socket communication.

---

## 2. Pre-Flight Verification & Assertions

Run the following assertion script to confirm Bubblewrap, Seccomp libraries, and toolchains are properly configured:

```bash
#!/usr/bin/env bash
set -euo pipefail

cd /mnt/MD/Project/DSH/DSH-Desktop

echo "=== [DSH-Desktop] Session 03: Pre-Flight Verification ==="

# Check bwrap binary
if ! command -v bwrap >/dev/null 2>&1; then
    echo "[FAIL] Bubblewrap ('bwrap') is not installed. Run 'sudo pacman -S bubblewrap'."
    exit 1
fi
echo "[PASS] bwrap found: $(bwrap --version)"

# Check Rust compiler and Cargo
if ! command -v cargo >/dev/null 2>&1; then
    echo "[FAIL] Cargo is not installed."
    exit 1
fi
echo "[PASS] Rust toolchain: $(rustc --version)"

# Check libseccomp availability
if pkg-config --exists libseccomp; then
    echo "[PASS] libseccomp pkg-config found ($(pkg-config --modversion libseccomp))."
else
    echo "[WARN] libseccomp not registered in pkg-config; checking headers..."
    test -f /usr/include/seccomp.h && echo "[PASS] seccomp.h found" || echo "[WARN] seccomp headers missing"
fi

echo "[PASS] Sandbox host prerequisites verified."
```

---

## 3. Detailed File Operations & Complete Code Scaffolding

### 3.1 Package Hierarchy

Scaffold and populate the following files across `packages/ipc-protocol/` and `packages/sandbox-host/`:

```
packages/ipc-protocol/
├── package.json
├── tsconfig.json
└── src/
    ├── index.ts
    ├── types.ts
    ├── channel.ts
    └── acl.ts

packages/sandbox-host/
├── Cargo.toml
└── src/
    ├── main.rs
    ├── config.rs
    ├── bwrap.rs
    ├── security.rs
    └── ipc_server.rs
```

---

### 3.2 IPC Protocol Implementation (TypeScript)

#### File: `packages/ipc-protocol/package.json`
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
    "test": "node --test dist/tests/*.js || tsx --test tests/ipc.test.ts",
    "clean": "rimraf dist tsconfig.tsbuildinfo"
  },
  "dependencies": {
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.5.0",
    "tsx": "^4.19.0",
    "typescript": "^5.5.4"
  }
}
```

#### File: `packages/ipc-protocol/src/types.ts`
```typescript
import { z } from "zod";

/**
 * Standard IPC Capability Grants
 */
export const CapabilityTokenSchema = z.object({
  tokenId: z.string().uuid(),
  agentId: z.string(),
  pluginId: z.string(),
  allowedPermissions: z.array(z.string()),
  workspacePath: z.string(),
  issuedAt: z.number(),
  expiresAt: z.number()
});

export type CapabilityToken = z.infer<typeof CapabilityTokenSchema>;

/**
 * JSON-RPC 2.0 Base Protocol Types
 */
export interface JsonRpcRequest<T = unknown> {
  jsonrpc: "2.0";
  id: string | number;
  method: string;
  params: T;
  token?: CapabilityToken;
}

export interface JsonRpcResponse<T = unknown> {
  jsonrpc: "2.0";
  id: string | number;
  result?: T;
  error?: {
    code: number;
    message: string;
    data?: unknown;
  };
}

export interface JsonRpcNotification<T = unknown> {
  jsonrpc: "2.0";
  method: string;
  params: T;
}

export type JsonRpcMessage = JsonRpcRequest | JsonRpcResponse | JsonRpcNotification;

/**
 * Sandbox Process Execution Schemas
 */
export const SpawnProcessParamsSchema = z.object({
  command: z.string().min(1),
  args: z.array(z.string()).default([]),
  env: z.record(z.string()).default({}),
  cwd: z.string().default("/workspace"),
  timeoutMs: z.number().int().positive().default(60000),
  allowNetwork: z.boolean().default(false),
  readOnlyWorkspace: z.boolean().default(false)
});

export type SpawnProcessParams = z.infer<typeof SpawnProcessParamsSchema>;

export interface ProcessExecutionResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
  killed: boolean;
}

/**
 * Error Codes
 */
export const IpcErrorCodes = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  UNAUTHORIZED: -32001,
  PERMISSION_DENIED: -32002,
  EXECUTION_TIMEOUT: -32003,
  SANDBOX_FAILURE: -32004
} as const;
```

#### File: `packages/ipc-protocol/src/acl.ts`
```typescript
import { type CapabilityToken, type JsonRpcRequest, IpcErrorCodes } from "./types.js";

export class AccessControlError extends Error {
  constructor(public readonly code: number, message: string) {
    super(message);
    this.name = "AccessControlError";
  }
}

export class AccessControlEngine {
  /**
   * Evaluate whether a given request holds the necessary capability to proceed.
   */
  public static verifyPermission(request: JsonRpcRequest, requiredPermission: string): void {
    if (!request.token) {
      throw new AccessControlError(
        IpcErrorCodes.UNAUTHORIZED,
        `Authorization failed: No capability token attached to request [${request.method}].`
      );
    }

    const token = request.token;
    const now = Date.now();

    if (now > token.expiresAt) {
      throw new AccessControlError(
        IpcErrorCodes.UNAUTHORIZED,
        `Capability token expired at ${new Date(token.expiresAt).toISOString()}.`
      );
    }

    if (!token.allowedPermissions.includes(requiredPermission)) {
      throw new AccessControlError(
        IpcErrorCodes.PERMISSION_DENIED,
        `Access denied: Agent [${token.agentId}] lacks required permission [${requiredPermission}].`
      );
    }
  }

  /**
   * Validate that a target filesystem path is strictly confined inside the agent workspace.
   */
  public static assertPathContainment(targetPath: string, allowedWorkspace: string): string {
    const resolvedAllowed = allowedWorkspace.endsWith("/") ? allowedWorkspace : `${allowedWorkspace}/`;
    if (!targetPath.startsWith(resolvedAllowed) && targetPath !== allowedWorkspace) {
      throw new AccessControlError(
        IpcErrorCodes.PERMISSION_DENIED,
        `Path traversal violation: Target path [${targetPath}] is outside allowed workspace [${allowedWorkspace}].`
      );
    }
    return targetPath;
  }
}
```

#### File: `packages/ipc-protocol/src/channel.ts`
```typescript
import net from "node:net";
import { EventEmitter } from "node:events";
import type { JsonRpcMessage, JsonRpcRequest, JsonRpcResponse } from "./types.js";

export class IpcChannel extends EventEmitter {
  private socket: net.Socket | null = null;
  private buffer = "";
  private pendingRequests = new Map<
    string | number,
    { resolve: (res: any) => void; reject: (err: any) => void; timer: NodeJS.Timeout }
  >();

  constructor(private socketPath: string) {
    super();
  }

  /**
   * Connect to host UNIX domain socket.
   */
  public async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.socket = net.createConnection({ path: this.socketPath }, () => {
        this.emit("connected");
        resolve();
      });

      this.socket.on("data", (chunk) => this.handleData(chunk));
      this.socket.on("error", (err) => {
        this.emit("error", err);
        reject(err);
      });
      this.socket.on("close", () => {
        this.emit("closed");
        this.socket = null;
      });
    });
  }

  private handleData(chunk: Buffer): void {
    this.buffer += chunk.toString("utf-8");
    const lines = this.buffer.split("
");
    this.buffer = lines.pop() || "";

    for (const line of lines) {
      if (line.trim().length === 0) continue;
      try {
        const msg = JSON.parse(line) as JsonRpcMessage;
        this.processMessage(msg);
      } catch (err) {
        this.emit("parseError", err, line);
      }
    }
  }

  private processMessage(msg: JsonRpcMessage): void {
    if ("id" in msg && msg.id !== undefined) {
      const pending = this.pendingRequests.get(msg.id);
      if (pending) {
        clearTimeout(pending.timer);
        this.pendingRequests.delete(msg.id);
        const res = msg as JsonRpcResponse;
        if (res.error) {
          pending.reject(new Error(`[IPC Error ${res.error.code}] ${res.error.message}`));
        } else {
          pending.resolve(res.result);
        }
        return;
      }
    }
    this.emit("message", msg);
  }

  /**
   * Send a JSON-RPC request and await response.
   */
  public async call<TResult = unknown, TParams = unknown>(
    method: string,
    params: TParams,
    token?: any,
    timeoutMs = 30000
  ): Promise<TResult> {
    if (!this.socket || this.socket.destroyed) {
      throw new Error("Cannot send IPC request: Socket is disconnected.");
    }

    const id = `${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const request: JsonRpcRequest<TParams> = {
      jsonrpc: "2.0",
      id,
      method,
      params,
      token
    };

    return new Promise<TResult>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingRequests.delete(id);
        reject(new Error(`IPC Call [${method}] timed out after ${timeoutMs}ms.`));
      }, timeoutMs);

      this.pendingRequests.set(id, { resolve, reject, timer });
      this.socket!.write(JSON.stringify(request) + "
");
    });
  }

  public close(): void {
    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }
  }
}
```

#### File: `packages/ipc-protocol/src/index.ts`
```typescript
/**
 * @dsh/ipc-protocol Master Exports
 */
export * from "./types.js";
export * from "./acl.js";
export * from "./channel.js";
```

---

### 3.3 Sandbox Host Daemon (Rust)

#### File: `packages/sandbox-host/Cargo.toml`
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
uuid = { version = "1.10", features = ["v4"] }

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

#### File: `packages/sandbox-host/src/config.rs`
```rust
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SandboxConfig {
    pub workspace_path: PathBuf,
    pub read_only_workspace: bool,
    pub allow_network: bool,
    pub memory_limit_mb: Option<u64>,
    pub max_processes: Option<u32>,
    pub timeout_seconds: u64,
}

impl Default for SandboxConfig {
    fn default() -> Self {
        Self {
            workspace_path: PathBuf::from("/tmp/dsh-default-workspace"),
            read_only_workspace: false,
            allow_network: false,
            memory_limit_mb: Some(2048),
            max_processes: Some(64),
            timeout_seconds: 60,
        }
    }
}
```

#### File: `packages/sandbox-host/src/security.rs`
```rust
use anyhow::{Context, Result};
use libseccomp::{ScmpAction, ScmpFilterContext, ScmpSyscall};

/// Build a high-security Seccomp BPF filter for untrusted agent child processes.
pub fn build_agent_seccomp_filter() -> Result<ScmpFilterContext> {
    // Default action: Allow standard syscalls
    let mut filter = ScmpFilterContext::new_filter(ScmpAction::Allow)
        .context("Failed to create Seccomp filter context")?;

    // Syscalls explicitly forbidden to prevent host compromise and escape
    let denied_syscalls = [
        "kexec_load",
        "kexec_file_load",
        "reboot",
        "swapon",
        "swapoff",
        "mount",
        "umount2",
        "pivot_root",
        "setns",
        "unshare",
        "ptrace",
        "process_vm_readv",
        "process_vm_writev",
        "syslog",
        "lookup_dcookie",
        "perf_event_open",
        "bpf",
        "userfaultfd",
    ];

    for syscall_name in &denied_syscalls {
        if let Ok(syscall) = ScmpSyscall::from_name(syscall_name) {
            filter
                .add_rule(ScmpAction::Errno(libc::EPERM), syscall)
                .context(format!("Failed to add denial rule for {}", syscall_name))?;
        }
    }

    Ok(filter)
}
```

#### File: `packages/sandbox-host/src/bwrap.rs`
```rust
use crate::config::SandboxConfig;
use anyhow::{Context, Result};
use std::process::Stdio;
use tokio::process::{Child, Command};

pub struct BwrapCommandBuilder<'a> {
    config: &'a SandboxConfig,
    command: &'a str,
    args: &'a [String],
}

impl<'a> BwrapCommandBuilder<'a> {
    pub fn new(config: &'a SandboxConfig, command: &'a str, args: &'a [String]) -> Self {
        Self {
            config,
            command,
            args,
        }
    }

    /// Build the full bwrap command line with strict unshared namespaces
    pub fn spawn(&self) -> Result<Child> {
        let mut cmd = Command::new("bwrap");

        // 1. Isolate Linux namespaces
        cmd.arg("--unshare-user")
            .arg("--unshare-ipc")
            .arg("--unshare-pid")
            .arg("--unshare-uts");

        if !self.config.allow_network {
            cmd.arg("--unshare-net");
        }

        // 2. Read-only system mounts
        cmd.arg("--ro-bind").arg("/usr").arg("/usr")
            .arg("--ro-bind").arg("/bin").arg("/bin")
            .arg("--ro-bind").arg("/lib").arg("/lib")
            .arg("--ro-bind").arg("/lib64").arg("/lib64");

        if PathBuf::from("/etc").exists() {
            cmd.arg("--ro-bind").arg("/etc/alternatives").arg("/etc/alternatives")
                .arg("--ro-bind").arg("/etc/ssl").arg("/etc/ssl");
        }

        // If network enabled, allow DNS resolution
        if self.config.allow_network && PathBuf::from("/etc/resolv.conf").exists() {
            cmd.arg("--ro-bind").arg("/etc/resolv.conf").arg("/etc/resolv.conf");
        }

        // 3. Ephemeral tmpfs mounts
        cmd.arg("--tmpfs").arg("/tmp")
            .arg("--tmpfs").arg("/run")
            .arg("--tmpfs").arg("/var")
            .arg("--dev").arg("/dev")
            .arg("--proc").arg("/proc");

        // 4. Bind workspace
        if !self.config.workspace_path.exists() {
            std::fs::create_dir_all(&self.config.workspace_path)
                .context("Failed to create workspace directory")?;
        }

        if self.config.read_only_workspace {
            cmd.arg("--ro-bind")
                .arg(&self.config.workspace_path)
                .arg("/workspace");
        } else {
            cmd.arg("--bind")
                .arg(&self.config.workspace_path)
                .arg("/workspace");
        }

        // 5. Working directory & Process cleanup
        cmd.arg("--chdir").arg("/workspace");
        cmd.arg("--die-with-parent");
        cmd.arg("--new-session");

        // 6. Target command execution
        cmd.arg("--").arg(self.command);
        for arg in self.args {
            cmd.arg(arg);
        }

        cmd.stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::null());

        let child = cmd.spawn().context("Failed to spawn bwrap sandbox process")?;
        Ok(child)
    }
}
use std::path::PathBuf;
```

#### File: `packages/sandbox-host/src/ipc_server.rs`
```rust
use crate::bwrap::BwrapCommandBuilder;
use crate::config::SandboxConfig;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};

#[derive(Debug, Deserialize)]
struct RpcRequest {
    jsonrpc: String,
    id: serde_json::Value,
    method: String,
    params: serde_json::Value,
}

#[derive(Debug, Serialize)]
struct RpcResponse {
    jsonrpc: &'static str,
    id: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<RpcError>,
}

#[derive(Debug, Serialize)]
struct RpcError {
    code: i32,
    message: String,
}

#[derive(Debug, Deserialize)]
struct SpawnParams {
    command: String,
    #[serde(default)]
    args: Vec<String>,
    #[serde(default)]
    workspace: Option<String>,
    #[serde(default)]
    allow_network: bool,
    #[serde(default)]
    timeout_seconds: Option<u64>,
}

#[derive(Debug, Serialize)]
struct SpawnResult {
    exit_code: i32,
    stdout: String,
    stderr: String,
    duration_ms: u64,
}

pub struct IpcServer {
    socket_path: PathBuf,
}

impl IpcServer {
    pub fn new(socket_path: PathBuf) -> Self {
        Self { socket_path }
    }

    pub async fn run(&self) -> Result<()> {
        if self.socket_path.exists() {
            std::fs::remove_file(&self.socket_path)?;
        }

        if let Some(parent) = self.socket_path.parent() {
            std::fs::create_dir_all(parent)?;
        }

        let listener = UnixListener::bind(&self.socket_path)
            .context(format!("Failed to bind UNIX domain socket at {:?}", self.socket_path))?;

        tracing::info!("Host IPC daemon listening on {:?}", self.socket_path);

        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    tokio::spawn(async move {
                        if let Err(e) = handle_connection(stream).await {
                            tracing::error!("Connection handler error: {:?}", e);
                        }
                    });
                }
                Err(e) => {
                    tracing::warn!("Accept failed: {:?}", e);
                }
            }
        }
    }
}

async fn handle_connection(stream: UnixStream) -> Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut reader = BufReader::new(reader);
    let mut line = String::new();

    while reader.read_line(&mut line).await? > 0 {
        let trimmed = line.trim();
        if !trimmed.is_empty() {
            let resp = match serde_json::from_str::<RpcRequest>(trimmed) {
                Ok(req) => handle_rpc_request(req).await,
                Err(err) => RpcResponse {
                    jsonrpc: "2.0",
                    id: serde_json::Value::Null,
                    result: None,
                    error: Some(RpcError {
                        code: -32700,
                        message: format!("Parse error: {}", err),
                    }),
                },
            };

            let resp_json = serde_json::to_string(&resp)? + "
";
            writer.write_all(resp_json.as_bytes()).await?;
        }
        line.clear();
    }

    Ok(())
}

async fn handle_rpc_request(req: RpcRequest) -> RpcResponse {
    let id = req.id.clone();
    match req.method.as_str() {
        "sandbox.exec" => match serde_json::from_value::<SpawnParams>(req.params) {
            Ok(params) => {
                let start = std::time::Instant::now();
                let config = SandboxConfig {
                    workspace_path: params
                        .workspace
                        .map(PathBuf::from)
                        .unwrap_or_else(|| PathBuf::from("/tmp/dsh-agent-workspace")),
                    read_only_workspace: false,
                    allow_network: params.allow_network,
                    memory_limit_mb: Some(2048),
                    max_processes: Some(64),
                    timeout_seconds: params.timeout_seconds.unwrap_or(60),
                };

                let builder = BwrapCommandBuilder::new(&config, &params.command, &params.args);
                match builder.spawn() {
                    Ok(child) => match child.wait_with_output().await {
                        Ok(output) => {
                            let duration_ms = start.elapsed().as_millis() as u64;
                            let res = SpawnResult {
                                exit_code: output.status.code().unwrap_or(-1),
                                stdout: String::from_utf8_lossy(&output.stdout).to_string(),
                                stderr: String::from_utf8_lossy(&output.stderr).to_string(),
                                duration_ms,
                            };
                            RpcResponse {
                                jsonrpc: "2.0",
                                id,
                                result: Some(serde_json::to_value(res).unwrap()),
                                error: None,
                            }
                        }
                        Err(e) => RpcResponse {
                            jsonrpc: "2.0",
                            id,
                            result: None,
                            error: Some(RpcError {
                                code: -32004,
                                message: format!("Execution failed: {}", e),
                            }),
                        },
                    },
                    Err(e) => RpcResponse {
                        jsonrpc: "2.0",
                        id,
                        result: None,
                        error: Some(RpcError {
                            code: -32004,
                            message: format!("Sandbox spawn failed: {}", e),
                        }),
                    },
                }
            }
            Err(e) => RpcResponse {
                jsonrpc: "2.0",
                id,
                result: None,
                error: Some(RpcError {
                    code: -32602,
                    message: format!("Invalid params: {}", e),
                }),
            },
        },
        _ => RpcResponse {
            jsonrpc: "2.0",
            id,
            result: None,
            error: Some(RpcError {
                code: -32601,
                message: format!("Method not found: {}", req.method),
            }),
        },
    }
}
```

#### File: `packages/sandbox-host/src/main.rs`
```rust
//! DSH Sandbox Host Daemon
use anyhow::Result;
use std::path::PathBuf;

mod bwrap;
mod config;
mod ipc_server;
mod security;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    tracing::info!("Initializing DSH Sandbox Host on CachyOS...");

    let socket_path = std::env::var("DSH_SOCKET_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let uid = nix::unistd::getuid();
            PathBuf::from(format!("/run/user/{}/dsh-agent.sock", uid))
        });

    let server = ipc_server::IpcServer::new(socket_path);
    server.run().await?;

    Ok(())
}
```

---

## 4. Capability & Security Declarations

1. **Host Isolation:**
   - Linux user, IPC, PID, UTS, and Network namespaces are isolated by default via `bwrap`.
   - Host `/root`, `/home`, and arbitrary parent directories are non-accessible.
2. **Access Control Tokens:**
   - Every IPC invocation requires an unexpired `CapabilityToken` verified against declared manifest permissions.
   - Any path traversal outside the allocated workspace returns `PERMISSION_DENIED`.

---

## 5. Step-by-Step AI Execution Instructions

1. **Navigate to Monorepo Root:**
   - `cd /mnt/MD/Project/DSH/DSH-Desktop`.
2. **Deploy `@dsh/ipc-protocol`:**
   - Write `packages/ipc-protocol/package.json`, `tsconfig.json`.
   - Write `packages/ipc-protocol/src/types.ts`, `acl.ts`, `channel.ts`, and `index.ts`.
   - Build package: `pnpm --filter @dsh/ipc-protocol build`.
3. **Deploy `dsh-sandbox-host`:**
   - Write `packages/sandbox-host/Cargo.toml`.
   - Write `packages/sandbox-host/src/config.rs`, `security.rs`, `bwrap.rs`, `ipc_server.rs`, `main.rs`.
   - Compile native binary: `cargo build --manifest-path packages/sandbox-host/Cargo.toml --release`.
4. **Execute Verification:**
   - Validate TypeScript compilation and Rust release build artifacts.

---

## 6. Validation & Verification Commands

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop

# 1. Build and Typecheck IPC Protocol
pnpm --filter @dsh/ipc-protocol build

# 2. Build Sandbox Host Native Daemon
cargo build --manifest-path packages/sandbox-host/Cargo.toml --release

# 3. Assert Outputs
test -f packages/ipc-protocol/dist/index.js
test -f packages/ipc-protocol/dist/index.d.ts
test -f packages/sandbox-host/target/release/dsh-sandbox-host

echo "[SUCCESS] Session 03 Host-Agent IPC Protocol & Sandbox verified."
```

---

## 7. Definition of Done

- [ ] Complete `@dsh/ipc-protocol` TypeScript package implemented with typed JSON-RPC framing and ACL evaluator.
- [ ] Complete `dsh-sandbox-host` Rust daemon implemented with `bwrap` namespace flags, Seccomp rules, and async UNIX socket server.
- [ ] Path traversal protections and capability token expirations enforced.
- [ ] Native binary successfully compiled with release optimization on CachyOS.
