# Session 07 — Terminal, Browser Preview/Automation & Appshots

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop`.
> Read `00_MASTER_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal
Add high-value interaction tools as plugins backed by existing desktop host capabilities.

### Terminal
- Reuse existing terminal/runtime services where available.
- Expose PTY only through a capability broker.
- Support tabs, resize, search, copy, clear, and session persistence.

### Browser
- Reuse the repository's existing browser-access implementation instead of adding a second browser stack.
- Separate local preview from remote/untrusted browsing.
- Enforce navigation/permission policies and isolate browser state.
- Build annotation support around stable browser events/coordinates; do not assume arbitrary DOM access from the host.

### Appshots
- Implement OS-appropriate global capture only where supported.
- Do not rely solely on renderer key events for a system-wide shortcut.
- Capture into a compact attachment/reference, then inject a reference into the DSH context pipeline.

### Tests
- PTY lifecycle
- browser policy
- navigation denial
- screenshot/capture permissions
- plugin disable cleanup

### Deliverables
- terminal plugin
- browser plugin
- Appshots plugin
- platform capability diagnostics

### Commit
`git add . && git commit -m "feat: add terminal browser and appshots plugins"`


## Agent operating rules
- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
