# Session 05 — Agent Runtime And Task Matrix

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` (Product Goal, Target Experience) and the
> repository's `AGENTS.md` first.

## Goal

Build a real execution telemetry model on top of existing DSH runtime events instead of
inventing a disconnected UI simulation.

## Tasks

1. Map current DSH session/agent/tool/goal events available to the desktop.
2. Define a normalized desktop event stream: task created, queued, running, waiting
   approval, tool start, tool end, blocked, completed, failed, cancelled.
3. Create task IDs and parent/child relationships for parallel work.
4. Implement an Agent Matrix (`ui-agent-matrix`) plugin that consumes the normalized
   stream.
5. Show only useful telemetry: status, current action, elapsed time, model/provider,
   token usage when available, pending approval, error.
6. Support collapse/grouping and stale-event handling.
7. Add backpressure/throttling so high-frequency events do not cause renderer storms.
8. Do not display fabricated progress percentages. If exact progress is unavailable, use
   state + elapsed time.

## Tests

- Event normalization
- Child task grouping
- Out-of-order event handling
- Cancellation
- High-frequency update throttling

## Deliverables

- Normalized task/event contract
- Agent Matrix plugin
- Telemetry tests

## Commit

`feat: add agent task telemetry and matrix`

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
