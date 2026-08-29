# Session 06 — Artifact Canvas And Review

> Execute this session against the repository at `/mnt/MD/Project/DSH/DSH-Desktop-Linux`.
> Read `FINAL_DSH_DESKTOP_LINUX_BLUEPRINT.md` and the repository's `AGENTS.md` first.

## Goal

Create a first-class artifact review experience integrated with DSH tool/session outputs.

## Tasks

1. Inventory existing attachment/file/artifact/session projection APIs.
2. Define an artifact reference model using path/ID/hash/mime/size rather than copying full content into every event.
3. Build a Canvas/Artifact plugin for text, Markdown, JSON, images, and PDFs using existing app capabilities where possible.
4. Add diff view for text/code. Prefer a proven diff/editor library already present or add the smallest justified dependency.
5. Support line/range comments as structured review objects.
6. Add accept/reject/apply semantics wired to the host capability broker and policy engine.
7. Large files should stream or page; never render unbounded content in one React/DOM tree.

## Tests

- artifact opening
- MIME handling
- diff correctness
- review comments
- approval/policy enforcement
- large-file protection

## Deliverables

- artifact model
- canvas/diff plugin
- review workflow

## Commit

`git add . && git commit -m "feat: add artifact canvas and review workflow"`

## Agent operating rules

- Inspect before editing.
- Reuse existing DSH/Cordis services before introducing dependencies.
- Keep changes inside desktop-owned code.
- Make the smallest coherent change that satisfies the session.
- Run targeted tests first, then the session gate.
- Do not proceed with known failing tests unless the failure is unrelated and explicitly recorded.
- Do not fabricate capability, GPU, progress, token, or security claims.
- At the end, print: changed files, tests run, remaining issues, and commit SHA.
