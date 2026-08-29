# Session 03 — Capability Broker And Secure Host Bridge

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Capability And Security Model) and the
> repository's `AGENTS.md` first.

## Goal

Create the security boundary between UI plugins and privileged desktop operations.

## Tasks

1. Audit current preload/contextBridge/IPC exposure and remote-content handling.
2. Keep `nodeIntegration: false`, `contextIsolation: true`, renderer sandboxing, and
   secure CSP for owned UI. Validate all IPC senders.
3. Introduce a typed host capability broker. Every privileged request has: plugin ID,
   capability, operation, target/resource, request ID, and policy context.
4. Implement policy evaluation with `Sandbox`, `Review`, and `Full Access` as
   user-facing presets only; decisions remain per capability/resource underneath.
5. Model resources explicitly: workspace roots, allowed file paths, executable classes,
   network hosts, browser profiles, Git repositories.
6. Destructive actions require review unless explicitly permitted by policy.
7. Add an emergency stop that cancels active agent/task/process operations where
   supported.
8. Add audit events with secrets redacted.
9. Add browser restrictions: navigation policy, permission request policy, external-
   window policy, no arbitrary privileged remote renderer.

## Security Baseline (must hold after this session)

- `nodeIntegration: false`
- `contextIsolation: true`
- Renderer sandboxing where the current architecture permits it
- Sender validation for every IPC entry point
- Strict navigation, permission, external-window, and CSP policy
- External links handled by the OS after validation
- No arbitrary shell API exposed to renderers
- Remote browser content treated as untrusted
- Audit events redact secrets
- Destructive operations require review unless policy explicitly grants them
- Emergency stop cancels active agent/task/process work where supported

## Tests

- IPC sender spoof rejection
- Denied capability
- Path traversal/symlink policy cases
- Destructive operation review
- Emergency stop
- Browser navigation restrictions
- CSP and preload contract smoke tests

## Deliverables

- Policy engine
- Typed capability broker
- Permission presets
- Audit/event schema
- Security tests

## Commit

`feat: add capability policy and secure host bridge`

## Agent Operating Rules

- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly
  recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
