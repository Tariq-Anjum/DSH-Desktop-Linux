# Session 01 — Repository Audit and Safety Baseline

## Objective

Establish an exact local baseline before changing architecture.

## AI prompt

Work only on repository inspection and safe scaffolding.

### Commands

```bash
cd /mnt/MD/Project/DSH/DSH-Desktop

git status --short
git branch --show-current
git remote -v
git submodule status --recursive

corepack yarn --version
node --version

find . -maxdepth 2 -type f | sort | sed -n '1,240p'

corepack yarn check
corepack yarn typecheck
corepack yarn test
```

If the repository uses `yarn` rather than `corepack yarn`, prefer the repository's documented toolchain.

## Inspect

- `package.json`
- `yarn.lock`
- `.gitmodules`
- `upstream.json`
- `AGENTS.md`
- `CLAUDE.md`
- `dsh-plugin-desktop/package.json`
- `dsh-plugin-desktop/cordis.patch.yml`
- `dsh-plugin-desktop/src/**`
- `dsh-plugin-desktop/tests/**`
- `docs/**`
- `INSTALL_CACHYOS.md`
- README variants
- CI workflows

## Produce

Create:

`docs/architecture/BASELINE-AUDIT.md`

Include:

- repository tree;
- dependency graph;
- current plugin inventory;
- current UI surfaces;
- current Linux behavior;
- current GPU behavior;
- current test commands/results;
- current known failures;
- exact upstream pin;
- proposed changes;
- files that must not be modified.

## Hard constraints

Do not:
- update the upstream pin;
- remove dependencies;
- rewrite the UI;
- introduce a new framework;
- change installer behavior.

## Exit criteria

Session is complete only when the audit exists and the pre-change test baseline is recorded.
