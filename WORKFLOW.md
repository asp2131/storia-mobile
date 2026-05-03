---
# Configuration consumed by ./bin/pi-symphony.sh — a Pi-native Linear orchestrator
# inspired by OpenAI Symphony but using Pi (`pi chain ...`) instead of Codex.
# These keys are documentation; the script reads env vars (LINEAR_API_KEY,
# PROJECT_SLUG, WORKSPACES, POLL_S, MAX_PARALLEL, PI_CHAIN). Override at launch:
#   PROJECT_SLUG=... POLL_S=15 MAX_PARALLEL=2 ./bin/pi-symphony.sh
runner: pi-symphony
tracker:
  kind: linear
  project_slug: "storia-web-b2f648c17c65"
  active_states:
    - Todo
    - In Progress
    - Merging
    - Rework
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
polling:
  interval_s: 15
workspace:
  root: ~/code/storia-mobile-symphony-workspaces
agent:
  max_concurrent_agents: 2
  pi_chain: storia-build-feature
  bootstrap: ./bin/bootstrap.sh
  verify: ./bin/verify.sh
---

## How this gets dispatched

`./bin/pi-symphony.sh` polls Linear for tickets in `Todo`, creates an isolated git worktree under `~/code/storia-mobile-symphony-workspaces/<ID>`, and invokes `pi chain storia-build-feature` with the ticket title + URL + description as input. This file is the SOP that pi-and-its-leads should follow inside that worktree. Pi's storia-orchestrator agent should `read` this file as part of its planning step.

Ticket fields the runner injects into the pi prompt:

- Identifier (e.g. `STO-123`)
- Title
- URL
- Description

## Operating mode

1. This is an unattended pi-symphony orchestration session. Do not ask a human to perform follow-up work unless there is a true external blocker.
2. Work only inside the provided git-worktree copy of `storia-mobile`. Do not touch files outside the worktree.
3. Keep changes narrowly scoped to the Linear ticket. Avoid unrelated refactors.
4. Use one persistent Linear workpad comment as the source of truth for plan, acceptance criteria, validation, notes, and blockers. Marker header: `## Symphony Workpad`.
5. Final response must report completed actions and blockers only. Do not include optional next steps for the user.

## Linear access

The runner (`bin/pi-symphony.sh`) handles Linear state transitions, workpad comment creation, and PR opening. Pi agents do not need direct Linear API access. If pi needs to add notes during execution, write them to the workpad section of the working branch's commit message — the runner appends them.

## Repo context

Storia Mobile is a Flutter mobile app for Storia Kids.

Important repo files and conventions:

- `AGENTS.md` is the cold-start orientation map: layout, conventions, where-to-put-code, gotchas, and the skills index. **Read this first.**
- `README.md` documents setup, iOS Sign in with Apple, App Store build/export, and the Pi Coding Agent harness.
- `pubspec.yaml` defines Flutter dependencies and assets. The repo uses Riverpod 2.6.1 with **no codegen** (no `build_runner`, no `*.g.dart` / `*.freezed.dart`).
- `analysis_options.yaml` configures static analysis (`flutter_lints ^5.0.0`).
- `bin/bootstrap.sh` is the canonical env setup (already wired into `after_create`). `bin/verify.sh` is the canonical pre-handoff check.
- `.pi/` contains the Pi Coding Agent harness (canonical): orchestrator, teams, pipelines, expertise, and quality protocols. A near-duplicate `.claude/agents/` tree exists; prefer `.pi/`.
- `.claude/skills/` and `.pi/skills/` both hold Flutter/Riverpod skill bodies (46 entries each, mirrored). Either path resolves the same content.
- `.wolf/buglog.json` records known fixes — **read before fixing any bug, append after fixing**. `.wolf/cerebrum.md` holds project-wide preferences and the do-not-repeat list.
- `specs/` holds feature implementation plans and audits (e.g. `mobile-word-pronunciation-implementation-plan.md`, `gamified-library-flame-plan.md`). Read the matching one before non-trivial feature work.
- `lib/src/` is the canonical source layout: `audio/`, `core/{theme,widgets,utils}/`, `data/`, `features/<name>/`, `routing/app_router.dart`. Match existing patterns.
- Existing logs and generated artifacts (e.g. files under `logs/`) may be dirty in the source repo; do not modify generated logs unless the ticket explicitly requires it.

## Available repo harnesses

### Pi Coding Agent CLI

This repo includes a Pi Coding Agent harness. Use the `pi` CLI when it helps with repo-local planning, audits, or specialized Storia feature work.

Examples:

```bash
pi chain storia-plan "Plan the requested Linear issue"
pi chain storia-audit "Audit the current change"
pi team storia-quality
```

The runner has already invoked `pi chain storia-build-feature` to start this session. Use additional `pi chain` invocations only if the ticket genuinely needs a different specialized chain (e.g. `storia-fix-bug`, `storia-audit`).

### Playwright CLI self-verification

`playwright-cli` is available globally for browser-verifiable flows, screenshots, traces, and WebM video proof.

Use it when the change has a browser/web-verifiable surface or when visual proof is valuable:

```bash
playwright-cli open
playwright-cli tracing-start
playwright-cli video-start
# perform browser actions
playwright-cli video-stop --filename=recordings/<flow>.webm
playwright-cli tracing-stop
```

Prefer Flutter unit/widget/integration tests for Dart, widget, and mobile-device behavior. When Playwright is used, record the screenshot/video/trace artifact path in the workpad and PR.

## Status map

- `Backlog` -> out of scope for this workflow; do not modify.
- `Todo` -> move to `In Progress`, create/update the workpad, then begin execution.
- `In Progress` -> continue implementation from the current workspace and workpad.
- `Human Review` -> wait for human approval or review feedback; do not code.
- `Merging` -> merge/land according to the repo's available land/PR workflow, then move to `Done` only after merge succeeds.
- `Rework` -> review feedback requires changes; reset approach, update the workpad, implement, validate, and return to `Human Review`.
- `Done`, `Closed`, `Cancelled`, `Canceled`, `Duplicate` -> terminal; do nothing.

## Step 0: Route by ticket state

1. The runner has already moved the ticket to `In Progress` and created a fresh `## Symphony Workpad` comment. Read both the ticket body and the existing workpad before doing anything else.
2. If state is `Backlog`, do not modify; stop. (You should not see Backlog tickets — the runner filters them.)
3. If a PR is already attached to the ticket, inspect PR comments/reviews/checks before new changes.
4. Record a compact environment stamp in the workpad:

```text
<hostname>:<abs-workdir>@<short-sha>
```

## Step 1: Plan before editing

Before code changes:

1. Read the ticket body and all comments.
2. Read `AGENTS.md` for the cold-start map, then inspect relevant repo files. If a matching plan exists in `specs/`, read it before designing.
3. If the ticket is a bug, read `.wolf/buglog.json` for known fixes before debugging. After fixing, append a new entry.
4. Update the workpad with:
   - plan checklist,
   - acceptance criteria,
   - validation checklist,
   - risks/confusions,
   - current environment stamp.
5. Reproduce or confirm the current behavior before changing code whenever possible.
6. Run `git fetch origin` and merge/rebase latest `origin/main` before implementation when safe; record the result.
7. Keep the workpad current throughout execution. Do not create separate progress comments.

## Step 2: Implementation rules

1. Use repo-local Flutter/Riverpod architecture and skills when relevant. Skill bodies live at `.claude/skills/<name>/SKILL.md` (mirrored at `.pi/skills/<name>/SKILL.md`).
2. Keep state-management, routing, data, and UI boundaries aligned with existing `lib/src/` patterns. Use design tokens from `lib/src/core/theme/`; do not hardcode colors/sizing.
3. Reuse shared widgets in `lib/src/core/widgets/` (sketch buttons/cards/inputs, watercolor scaffold, parental gate) before creating new ones.
4. Prefer small focused edits and tests over broad rewrites.
5. Do not introduce codegen (`build_runner`, `freezed`, `riverpod_generator`) — this repo does not use it.
6. Do not change native iOS/Android signing, bundle IDs, or release settings unless the ticket explicitly asks.
7. If the ticket touches auth, Apple Sign In, Supabase, audio/TTS, reader runtime, or gamification, inspect existing `specs/` plans before editing.
8. If meaningful out-of-scope improvements are found, file a separate Linear Backlog issue instead of expanding scope.

## Step 3: Validation requirements

Choose the narrowest validation that proves the change, then run broader checks before handoff when practical.

Primary Flutter validation (canonical pre-handoff gate):

```bash
./bin/verify.sh    # flutter analyze + flutter test
```

Targeted runs while iterating:

```bash
flutter analyze
flutter test test/path/to/specific_test.dart
flutter test test/features/<feature_name>/
```

Manual smoke / preview when a ticket is UI-relevant:

```bash
flutter run -d chrome      # web preview (fastest iteration; default for UI/web tickets)
flutter run -d ios          # iOS simulator
flutter run -d android      # Android emulator
```

Use platform/build checks only when the ticket touches build, native, or release surface:

```bash
flutter build web
flutter build ios --simulator
flutter build apk --debug
flutter build ipa --export-method app-store    # see README.md for the manual xcodebuild export path
```

For browser-verifiable UI proof, run the web target then capture with Playwright CLI:

```bash
flutter run -d chrome &      # leave running on its default port
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli tracing-start
playwright-cli video-start
# perform flow
playwright-cli video-stop --filename=recordings/<ticket>-proof.webm
playwright-cli tracing-stop
playwright-cli close
```

Record exact commands and outcomes in the workpad. If validation fails, fix or document a true blocker before handoff.

## PR and review flow

1. Commit logical changes with clear messages.
2. Push a branch for the ticket.
3. Open or update a GitHub PR and link it to the Linear issue.
4. Add the `symphony` label to the PR when possible.
5. Before moving to `Human Review`:
   - all acceptance criteria are checked,
   - required validation is checked with command evidence,
   - PR checks are green or blocker is documented,
   - PR comments/reviews have no outstanding actionable feedback,
   - the workpad reflects the latest plan, validation, and handoff notes.
6. Move the Linear issue to `Human Review` only after the completion bar is met.

## PR feedback sweep protocol

When a PR exists:

1. Gather top-level PR comments, inline review comments, review summaries, and check results.
2. Treat every actionable human or bot comment as blocking until addressed in code/tests/docs or explicitly answered with justified pushback.
3. Update the workpad checklist with each feedback item and resolution.
4. Re-run relevant validation after feedback changes.
5. Repeat until no outstanding actionable feedback remains.

## Blocked-access escape hatch

Use this only for missing required tools, auth, permissions, secrets, or external services that cannot be resolved in-session.

If blocked:

1. Keep or create the workpad.
2. Record:
   - what is missing,
   - why it blocks acceptance/validation,
   - exact human action required to unblock.
3. Move to `Human Review` only when the blocker prevents further autonomous progress.

## Workpad template

Use this exact structure and update it in place:

````md
## Symphony Workpad

```text
<hostname>:<abs-path>@<short-sha>
```

### Plan

- [ ] 1. Parent task
  - [ ] 1.1 Child task
  - [ ] 1.2 Child task
- [ ] 2. Parent task

### Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

### Validation

- [ ] `<command>` — expected proof

### Notes

- <timestamped short progress note>

### Confusions

- <only include when something was unclear during execution>
````
