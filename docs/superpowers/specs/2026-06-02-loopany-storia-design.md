# Loopany Storia Integration Design

**Date:** 2026-06-02
**Status:** Approved for planning

## Goal

Install [loopany](https://github.com/superdesigndev/loopany) for use with the `storia-mobile` repo in a way that is easy to reuse, safe to adopt incrementally, and does not interfere with the repo's existing Pi / Symphony / Flutter workflows.

## Recommended approach

Use a **repo-assisted integration**:

1. Install loopany globally on the local machine using the upstream-supported installation flow.
2. Add a small Storia-specific helper layer in this repo.
3. Keep loopany runtime state outside git.
4. Do not deeply wire loopany into `.pi`, `WORKFLOW.md`, or ticket automation yet.

This gives the team a repeatable entrypoint without forcing a new default workflow before loopany has proven useful in practice.

## Why this approach

### Benefits
- Reusable across sessions and projects because the CLI is installed globally.
- Discoverable for future Storia agents because repo-local docs and a helper script are checked in.
- Low-risk because it does not replace or mutate the current harness.
- Easy to expand later into deeper workflow integration if it becomes valuable.

### Alternatives considered

#### 1. Local-only install
Fastest to set up, but the knowledge of how to use it stays with one machine or one operator.

#### 2. Repo-assisted install (**recommended**)
Adds enough structure for repeatable use here without coupling the repo to loopany internals.

#### 3. Full integration now
Too early. The repo already has `.pi`, `WORKFLOW.md`, and established automation. Wiring loopany directly into those systems before it proves useful would create overlap and maintenance risk.

## Architecture

### Global layer
Loopany is installed the way upstream expects, outside this repo, so the `loopany` CLI is available on the machine and can be upgraded independently.

Expected upstream footprint:
- source checkout, e.g. `~/loopany-src`
- installed CLI available on `PATH`
- loopany-managed workspace outside the repo

### Repo-assisted layer
The repo provides a tiny integration surface:
- a helper script in `bin/`
- a short usage document in `docs/` and/or a small README addition

This layer does not reimplement loopany. It only makes the Storia usage pattern obvious and repeatable.

### State location
Loopany working data should live outside the repo, under a Storia-specific home directory.

Recommended location:
- `~/.loopany/storia-mobile`

This avoids polluting the repository, prevents accidental commits of local memory/state, and keeps removal straightforward.

## Components

### 1. Global installation
Install loopany globally using the upstream `INSTALL_FOR_AGENTS.md` flow and verify that the command is available.

Responsibilities:
- install prerequisites
- install or link the CLI
- verify `loopany --version`

### 2. Repo helper script
Add `bin/loopany-storia.sh`.

Responsibilities:
- verify `loopany` is installed
- set `LOOPANY_HOME` to the Storia-specific directory
- forward all user arguments unchanged to `loopany`
- fail fast with a clear error if the CLI is missing

The script should preserve upstream command semantics so users can run normal loopany subcommands through the Storia wrapper.

### 3. Repo documentation
Add a short guide such as `docs/tooling/loopany.md`.

Responsibilities:
- explain what loopany is being used for in this repo
- show installation/verification prerequisites
- show first-time initialization through the helper script
- show normal usage through the helper script
- explain what is intentionally not integrated yet
- explain where local state is stored

## File layout

### Checked in
- `bin/loopany-storia.sh`
- `docs/tooling/loopany.md` (preferred) or equivalent concise repo documentation
- optional small README pointer if discoverability needs improvement

### Not checked in
- loopany artifacts
- loopany workspace state
- generated search/index/cache data
- automatic hooks into `.pi` or `bin/pi-symphony.sh`

## Operational behavior

### First-time use
1. Ensure `loopany` is installed globally.
2. Run the helper with `init`.
3. Use the helper for subsequent Storia-specific loopany commands.

### Normal use
The helper should act as a transparent wrapper:
- same subcommands as upstream loopany
- Storia-specific home automatically applied
- no background services
- no repo mutation except tracked docs/script updates

### Error behavior
If loopany is not installed or not on `PATH`, the helper should print a short actionable message telling the user how to install or expose the CLI.

## Boundaries and non-goals

### In scope
- local loopany installation
- repo helper script
- repo documentation
- verification that the Storia-scoped workspace initializes correctly

### Out of scope for this first pass
- replacing the existing Pi harness
- auto-running loopany inside ticket workflows
- adding loopany-generated state to the repo
- coupling loopany to Flutter bootstrap, analyze, or test commands
- deep customization of loopany internals

## Verification

The implementation should verify:
1. `loopany --version` succeeds.
2. `bin/loopany-storia.sh` exists and is executable.
3. `bin/loopany-storia.sh init` creates the Storia-specific workspace outside the repo.
4. Documentation commands match observed behavior.
5. Repo validation still passes for tracked-file changes.

## Future expansion

If the team gets repeated value from the repo-assisted setup, a future design can evaluate:
- adding loopany usage guidance to broader agent docs
- optional workflow hooks for specific ticket types
- deeper coordination with the existing `.pi` harness

That expansion should happen only after real usage demonstrates the benefit and the right integration points.
