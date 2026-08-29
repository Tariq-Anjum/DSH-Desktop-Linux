# Session 07 — Terminal, Browser, And Appshots

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Capability And Security Model) and the
> repository's `AGENTS.md` first.

## Goal

Add high-value interaction tools as plugins backed by existing desktop host
capabilities.

## Terminal

- Reuse existing terminal/runtime services where available.
- Expose PTY only through the capability broker.
- Support tabs, resize, search, copy, clear, and session persistence.

## Browser

- Reuse the repository's existing browser-access implementation instead of adding a
  second browser stack.
- Separate local preview from remote/untrusted browsing.
- Enforce navigation/permission policies and isolate browser state.
- Build annotation support around stable browser events/coordinates; do not assume
  arbitrary DOM access from the host.

## Appshots

- Implement OS-appropriate global capture only where supported.
- Do not rely solely on renderer key events for a system-wide shortcut.
- Capture into a compact attachment/reference, then inject a reference (not full
  content) into the DSH context pipeline.

## Tests

- PTY lifecycle
- Browser policy
- Navigation denial
- Screenshot/capture permissions
- Plugin disable cleanup

## Deliverables

- Terminal plugin
- Browser plugin
- Appshots plugin
- Platform capability diagnostics

## Commit

`feat: add terminal browser and appshots plugins`

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
