# Loopany Storia Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install loopany on the local machine and add a small, repo-assisted Storia wrapper plus docs so future work can use a Storia-scoped loopany workspace without changing the existing Pi/Symphony harness.

**Architecture:** Keep the actual loopany CLI and its runtime state outside the repo, following upstream installation guidance. Inside `storia-mobile`, add only a thin Bash wrapper and concise documentation that points users to a Storia-specific `LOOPANY_HOME` and preserves upstream loopany command behavior.

**Tech Stack:** Bash, Markdown, Bun, loopany CLI

---

### Task 1: Install and verify the global loopany CLI

**Files:**
- Modify: none (local machine setup only)
- Reference: `docs/superpowers/specs/2026-06-02-loopany-storia-design.md`
- Reference: upstream `INSTALL_FOR_AGENTS.md` commands from `https://github.com/superdesigndev/loopany`

- [ ] **Step 1: Check the current local tool state**

Run:

```bash
command -v bun >/dev/null 2>&1 && echo "bun:present" || echo "bun:missing"
command -v loopany >/dev/null 2>&1 && echo "loopany:present" || echo "loopany:missing"
[ -d "$HOME/loopany-src/.git" ] && echo "loopany-src:present" || echo "loopany-src:missing"
```

Expected:
- Prints the current status for Bun, `loopany`, and `~/loopany-src`
- Does not modify the repo

- [ ] **Step 2: Ensure Bun is installed and available on PATH**

Run:

```bash
if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$PATH"
grep -qxF 'export PATH="$HOME/.bun/bin:$PATH"' "$HOME/.zshrc" || printf '\nexport PATH="$HOME/.bun/bin:$PATH"\n' >> "$HOME/.zshrc"
command -v bun
```

Expected:
- `command -v bun` prints a path, typically under `$HOME/.bun/bin`
- `~/.zshrc` contains the PATH export exactly once

- [ ] **Step 3: Clone or update the upstream loopany source checkout**

Run:

```bash
if [ -d "$HOME/loopany-src/.git" ]; then
  git -C "$HOME/loopany-src" pull --ff-only
else
  git clone https://github.com/superdesigndev/loopany.git "$HOME/loopany-src"
fi
```

Expected:
- `~/loopany-src` exists and is a git checkout of `superdesigndev/loopany`

- [ ] **Step 4: Install dependencies, link the CLI, and verify the binary**

Run:

```bash
export PATH="$HOME/.bun/bin:$PATH"
cd "$HOME/loopany-src"
bun install
bun link
loopany --version
```

Expected:
- `bun install` completes successfully
- `bun link` exposes `loopany` on PATH
- `loopany --version` prints a non-empty version string

- [ ] **Step 5: Confirm the install is visible from the `storia-mobile` repo root**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
export PATH="$HOME/.bun/bin:$PATH"
command -v loopany
loopany --version
```

Expected:
- The repo-root shell can resolve `loopany`
- Version output matches the linked install from `~/loopany-src`

### Task 2: Add the Storia-specific loopany wrapper script

**Files:**
- Create: `bin/loopany-storia.sh`
- Reference: `bin/bootstrap.sh`
- Reference: `docs/superpowers/specs/2026-06-02-loopany-storia-design.md`

- [ ] **Step 1: Verify the wrapper script does not already exist**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
test ! -f bin/loopany-storia.sh && echo "wrapper:missing"
```

Expected:
- Prints `wrapper:missing`
- If the file already exists, stop and diff it before overwriting

- [ ] **Step 2: Write the minimal wrapper script**

Create `bin/loopany-storia.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

loopany_home="${LOOPANY_HOME:-$HOME/.loopany/storia-mobile}"

if ! command -v loopany >/dev/null 2>&1; then
  cat >&2 <<'EOF'
[loopany-storia] loopany is not installed or not on PATH.
Install it with the upstream flow:
  git clone https://github.com/superdesigndev/loopany.git ~/loopany-src
  export PATH="$HOME/.bun/bin:$PATH"
  cd ~/loopany-src && bun install && bun link
If needed, add `export PATH="$HOME/.bun/bin:$PATH"` to ~/.zshrc and source it.
EOF
  exit 1
fi

mkdir -p "$loopany_home"
export LOOPANY_HOME="$loopany_home"

exec loopany "$@"
```

- [ ] **Step 3: Mark the wrapper executable and verify the implementation matches the file**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
chmod +x bin/loopany-storia.sh
sed -n '1,200p' bin/loopany-storia.sh
```

Expected:
- The file is executable
- The printed content matches the wrapper from Step 2 exactly

- [ ] **Step 4: Smoke-test passthrough behavior**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
export PATH="$HOME/.bun/bin:$PATH"
./bin/loopany-storia.sh --version
```

Expected:
- Prints the same non-empty version string as `loopany --version`
- Exits with status 0

- [ ] **Step 5: Commit the wrapper script**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
git add bin/loopany-storia.sh
git commit -m "chore: add loopany wrapper"
```

Expected:
- One commit containing only the new wrapper script

### Task 3: Document the Storia loopany workflow

**Files:**
- Create: `docs/tooling/loopany.md`
- Modify: `README.md`
- Reference: `README.md`
- Reference: `docs/superpowers/specs/2026-06-02-loopany-storia-design.md`

- [ ] **Step 1: Create the repo-specific loopany guide**

Create `docs/tooling/loopany.md` with exactly this content:

````md
# Loopany for Storia Mobile

This repo supports using the globally-installed [`loopany`](https://github.com/superdesigndev/loopany) CLI with a Storia-specific workspace.

## What this is for

Use loopany when you want long-running, local agent memory for work connected to `storia-mobile` without changing the repo's existing Pi / Symphony automation.

## What this setup does

- keeps the actual `loopany` install outside this repo
- stores Storia loopany state under `~/.loopany/storia-mobile` by default
- provides a repo-local wrapper at `./bin/loopany-storia.sh`

## Install the global CLI

Follow the upstream install flow:

```bash
git clone https://github.com/superdesigndev/loopany.git ~/loopany-src
curl -fsSL https://bun.sh/install | bash       # if Bun is not yet installed
export PATH="$HOME/.bun/bin:$PATH"
cd ~/loopany-src
bun install
bun link
loopany --version
```

If `loopany` is not found, add this line to `~/.zshrc` and reload your shell:

```bash
export PATH="$HOME/.bun/bin:$PATH"
```

## Initialize the Storia workspace

```bash
./bin/loopany-storia.sh init
```

This creates or updates the Storia-scoped loopany home at:

```text
~/.loopany/storia-mobile
```

## Normal usage

Run upstream loopany commands through the wrapper so the Storia-specific home is applied automatically:

```bash
./bin/loopany-storia.sh --version
./bin/loopany-storia.sh init
```

If you need a different location temporarily, override `LOOPANY_HOME`:

```bash
LOOPANY_HOME=/tmp/storia-loopany ./bin/loopany-storia.sh init
```

## What is not integrated yet

This first pass does **not**:

- modify `.pi` orchestration
- modify `bin/pi-symphony.sh`
- auto-run inside Flutter bootstrap/test flows
- commit loopany runtime state into the repo
````

- [ ] **Step 2: Add a README pointer so future users can discover the wrapper**

In `README.md`, update the `## Repository Scripts` bullet list by appending this bullet after the existing `bin/pi-symphony.sh` item:

```md
- `bin/loopany-storia.sh` runs the globally-installed loopany CLI with a Storia-scoped `LOOPANY_HOME`; see `docs/tooling/loopany.md`.
```

- [ ] **Step 3: Verify the docs mention the exact checked-in entrypoint and state location**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
grep -n "bin/loopany-storia.sh" README.md docs/tooling/loopany.md
grep -n "~/.loopany/storia-mobile" docs/tooling/loopany.md
```

Expected:
- The wrapper path appears in both files
- The state location appears in the new doc exactly once in the dedicated location section

- [ ] **Step 4: Review the rendered docs for obvious mistakes**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
sed -n '1,220p' README.md
printf '\n---\n'
sed -n '1,260p' docs/tooling/loopany.md
```

Expected:
- The README bullet reads naturally in the existing list
- The new guide contains no placeholders, contradictory paths, or missing commands

- [ ] **Step 5: Commit the documentation changes**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
git add README.md docs/tooling/loopany.md
git commit -m "docs: add loopany usage guide"
```

Expected:
- One commit containing the README pointer and the new guide

### Task 4: Initialize the Storia-scoped workspace and run final verification

**Files:**
- Modify: none expected (runtime state should be written outside the repo)
- Verify: `bin/loopany-storia.sh`
- Verify: `docs/tooling/loopany.md`
- Verify: `README.md`

- [ ] **Step 1: Initialize the Storia-scoped loopany workspace through the wrapper**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
export PATH="$HOME/.bun/bin:$PATH"
./bin/loopany-storia.sh init
```

Expected:
- Command exits successfully
- Loopany creates or updates `~/.loopany/storia-mobile`

- [ ] **Step 2: Verify the expected Storia-scoped files exist outside the repo**

Run:

```bash
test -f "$HOME/.loopany/storia-mobile/config.yaml"
test -d "$HOME/.loopany/storia-mobile/kinds"
test -f "$HOME/.loopany/storia-mobile/kinds/task.md"
printf 'loopany-home=%s\n' "$HOME/.loopany/storia-mobile"
```

Expected:
- All three filesystem checks succeed
- The printed path is the Storia-specific location from the design and docs

- [ ] **Step 3: Verify the wrapper preserves normal CLI passthrough after initialization**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
./bin/loopany-storia.sh --version
```

Expected:
- Prints a non-empty version string
- Confirms that the wrapper works after `init`, not only before it

- [ ] **Step 4: Run repo validation before handoff**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
./bin/verify.sh
```

Expected:
- `flutter analyze` passes
- `flutter test` passes

- [ ] **Step 5: Capture the final repo diff and runtime boundary check**

Run:

```bash
cd /Users/akinpound/Documents/experiments/storia-mobile
git status --short
find "$HOME/.loopany/storia-mobile" -maxdepth 2 | sort | sed -n '1,40p'
```

Expected:
- Git status shows only the intended tracked repo changes
- Loopany runtime files are present outside the repo, not under the project tree
