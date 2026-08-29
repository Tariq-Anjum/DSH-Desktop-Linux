# DSH Desktop Linux — 10-Session Execution Package

This directory is meant to be committed to `Tariq-Anjum/DSH-Desktop-Linux` alongside
`FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md`, which each session file treats as its
architecture authority. Run the sessions in order — each depends on infrastructure the
previous ones establish (plugin contract before capability broker, capability broker
before UI, etc.). Do not skip ahead unless a dependency is already present.

## Files

- `SESSION_01.md` — Baseline, Runtime, Installer
- `SESSION_02.md` — Plugin Contract And Lifecycle
- `SESSION_03.md` — Capability Broker And Secure Host Bridge
- `SESSION_04.md` — Desktop Shell And Plugin-Composed UI
- `SESSION_05.md` — Agent Runtime And Task Matrix
- `SESSION_06.md` — Artifact Canvas And Review
- `SESSION_07.md` — Terminal, Browser, And Appshots
- `SESSION_08.md` — Context Broker And Command Palette
- `SESSION_09.md` — Scheduler, Git, Settings, And Recovery
- `SESSION_10.md` — Vulkan Validation, Packaging, Docs, Release

## How To Use

Hand one file at a time to the implementation agent, e.g.:

> Execute `raw-session/SESSION_01.md` against
> `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.

Each file is self-contained (Goal, Tasks, Tests, Deliverables, Commit, Agent Operating
Rules) but assumes the agent also reads `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` for the
architecture it must not violate, and the repository's `AGENTS.md` for local
conventions. A release is only accepted once all ten sessions pass the **Final
Acceptance Gate** defined in the blueprint.
