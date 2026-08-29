# Session 08 — Context Broker And Command Palette

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Context And Token Efficiency Principle)
> and the repository's `AGENTS.md` first.

## Goal

Make the desktop agent workflow fast and context-efficient. Memory, skills, logs, and
repository trees must never be preloaded into agent context automatically — only
summaries and fetch-on-demand references.

## Tasks

1. Build a Context Broker (`context-broker`) that exposes compact summaries and
   fetch-on-demand references for files, sessions, plugins, memory, and tool results.
2. Define context items with source ID, type, size/token estimate, freshness,
   relevance, and inclusion policy.
3. Add explicit include/exclude controls for folders/files/session artifacts.
4. Add context budget management with soft/hard limits and truncation strategies.
5. Add a Token/Context HUD showing approximate current usage and what categories
   consume it; never claim provider-exact counts unless sourced from the provider.
6. Build a global command palette (`ui-command-palette`) using the desktop's existing
   command infrastructure. Commands should be registered by plugins rather than
   hardcoded in a giant switch.
7. Support commands such as goal/task, browser, terminal, diff, plugin enable/disable,
   profile switching, diagnostics.
8. Make all command results structured and short by default.

## Tests

- Context ranking
- Budget enforcement
- Stale references
- Command registration/removal
- Keyboard shortcut cleanup

## Deliverables

- Context broker
- Command registry
- Command palette plugin
- Context/token HUD

## Commit

`feat: add context broker command palette and token hud`

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
