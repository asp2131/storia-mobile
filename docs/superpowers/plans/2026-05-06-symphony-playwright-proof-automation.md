# Symphony Playwright Proof Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `pi-symphony` automatically attempt the standard Playwright WebM proof capture when a UI ticket reaches PR handoff without ticket-specific evidence.

**Architecture:** Keep `bin/symphony-proof.sh` as the shared policy/enforcement library and add capture helpers there. Add a focused default capture script for the Flutter web + Playwright flow, then call the helper from `bin/pi-symphony.sh` and `bin/opencode-symphony.sh` before blocking. Tests exercise the shell helpers with fake capture commands so CI does not need Flutter, Chrome, or Playwright.

**Tech Stack:** Bash 3.2-compatible shell scripts, existing `playwright-cli`, Flutter web runner, current shell tests under `test/bin/`.

---

### Task 1: Add proof capture helper tests

**Files:**
- Create: `test/bin/symphony_proof_capture_fallback_test.sh`

- [ ] **Step 1: Write failing shell tests**

Create `test/bin/symphony_proof_capture_fallback_test.sh` that sources `bin/symphony-proof.sh` and verifies:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=bin/symphony-proof.sh
. "$repo_root/bin/symphony-proof.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
mkdir -p recordings

PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0
export PLAYWRIGHT_PROOF_REQUIRE_UPLOAD

if symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected missing capture command/default script to fail" >&2
  exit 1
fi
if ! grep -q 'No ticket-specific Playwright WebM proof found' /tmp/symphony-capture.err; then
  echo "expected missing proof diagnostic" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi

PLAYWRIGHT_PROOF_CAPTURE_CMD='mkdir -p recordings; printf video > "recordings/${PLAYWRIGHT_PROOF_TICKET}-proof.webm"'
export PLAYWRIGHT_PROOF_CAPTURE_CMD
if ! symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected capture fallback to satisfy proof" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi
if ! grep -q 'Local artifact: `recordings/STO-77-proof.webm`' /tmp/symphony-capture.out; then
  echo "expected markdown for captured artifact" >&2
  cat /tmp/symphony-capture.out >&2
  exit 1
fi

rm -f recordings/STO-77-proof.webm
PLAYWRIGHT_PROOF_CAPTURE_CMD='echo capture-ran >&2; exit 42'
export PLAYWRIGHT_PROOF_CAPTURE_CMD
if symphony_ensure_playwright_proof STO-77 >/tmp/symphony-capture.out 2>/tmp/symphony-capture.err; then
  echo "expected failed capture command to fail proof" >&2
  exit 1
fi
if ! grep -q 'Playwright proof capture failed' /tmp/symphony-capture.err; then
  echo "expected failed capture diagnostic" >&2
  cat /tmp/symphony-capture.err >&2
  exit 1
fi
```

- [ ] **Step 2: Run test to verify RED**

Run: `bash test/bin/symphony_proof_capture_fallback_test.sh`

Expected: FAIL because `symphony_ensure_playwright_proof` is not defined.

### Task 2: Implement shared capture helper

**Files:**
- Modify: `bin/symphony-proof.sh`

- [ ] **Step 1: Add Bash 3.2-safe helpers**

Add functions:

```bash
symphony_default_playwright_capture_script() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s/symphony-capture-playwright-proof.sh' "$script_dir"
}

symphony_capture_playwright_proof() {
  local ticket="$1" cmd="${PLAYWRIGHT_PROOF_CAPTURE_CMD:-}"
  if [ -n "$cmd" ]; then
    PLAYWRIGHT_PROOF_TICKET="$ticket" bash -lc "$cmd"
    return $?
  fi

  local default_script
  default_script="$(symphony_default_playwright_capture_script)"
  if [ ! -x "$default_script" ]; then
    echo "No PLAYWRIGHT_PROOF_CAPTURE_CMD set and default capture script is not executable: $default_script" >&2
    return 127
  fi
  PLAYWRIGHT_PROOF_TICKET="$ticket" "$default_script"
}

symphony_ensure_playwright_proof() {
  local ticket="$1"
  if symphony_build_playwright_proof_markdown "$ticket"; then
    return 0
  fi

  echo "Attempting automated Playwright proof capture for $ticket..." >&2
  if ! symphony_capture_playwright_proof "$ticket"; then
    echo "Playwright proof capture failed for $ticket." >&2
    return 1
  fi

  symphony_build_playwright_proof_markdown "$ticket"
}
```

- [ ] **Step 2: Run helper test to verify GREEN**

Run: `bash test/bin/symphony_proof_capture_fallback_test.sh`

Expected: PASS.

### Task 3: Add default Flutter web capture script

**Files:**
- Create: `bin/symphony-capture-playwright-proof.sh`

- [ ] **Step 1: Create script**

Create an executable Bash 3.2-compatible script that:
- requires `PLAYWRIGHT_PROOF_TICKET`,
- starts `flutter run -d chrome --web-port 0`,
- parses the localhost URL from Flutter output,
- opens Playwright,
- starts tracing and video,
- uses robust text/eval interactions for the app-review flow,
- writes `recordings/${PLAYWRIGHT_PROOF_TICKET}-proof.webm`,
- stops tracing/video and closes Playwright in cleanup.

- [ ] **Step 2: Add dry-run support for tests/operators**

Support `PLAYWRIGHT_PROOF_CAPTURE_DRY_RUN=1` to create a non-empty placeholder WebM without starting Flutter. This is only for harness testing and must be documented as not acceptable for real PR evidence.

### Task 4: Wire fallback into Symphony runners

**Files:**
- Modify: `bin/pi-symphony.sh`
- Modify: `bin/opencode-symphony.sh`

- [ ] **Step 1: Replace direct proof markdown call**

In each runner, replace:

```bash
symphony_build_playwright_proof_markdown "$ident"
```

with:

```bash
symphony_ensure_playwright_proof "$ident"
```

Keep the existing blocker message when the helper fails.

### Task 5: Update docs

**Files:**
- Modify: `WORKFLOW.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Document automation**

Add concise notes for:
- `PLAYWRIGHT_PROOF_CAPTURE_CMD`,
- default `bin/symphony-capture-playwright-proof.sh`,
- fallback sequence: find existing proof → capture → upload/link → block only if still missing/invalid,
- dry-run caveat.

### Task 6: Verify

**Files:**
- No source edits unless failures reveal issues.

- [ ] **Step 1: Run shell tests**

Run:

```bash
bash test/bin/symphony_proof_capture_fallback_test.sh
bash test/bin/pi_symphony_bash32_compat_test.sh
bash test/bin/pi_symphony_process_ticket_dry_run_test.sh
bash test/bin/pi_symphony_running_count_test.sh
./bin/symphony-proof.sh --self-test
```

Expected: all pass.

- [ ] **Step 2: Run full verification when practical**

Run: `./bin/verify.sh`

Expected: Flutter analyze and Flutter tests pass.
