# AGENTS.md

Index for autonomous coding agents (Symphony, Codex, Claude Code, Pi). Cold-start orientation for picking up a Linear ticket in this repo.

For the full Symphony Linear orchestration SOP, read **`WORKFLOW.md`** at repo root. This file gives the **map**; WORKFLOW.md gives the **process**.

## Boot

```bash
./bin/bootstrap.sh
```

Idempotent. Runs `flutter pub get`, copies `.env.example → .env` if missing, runs `pod install` on macOS when `ios/Podfile` exists. Symphony's `after_create` hook should call this.

## Verify (run before moving ticket to Human Review)

```bash
./bin/verify.sh        # flutter analyze + flutter test
```

Targeted alternatives:

```bash
flutter analyze
flutter test test/features/<feature>/         # one feature
flutter test test/features/reader/runtime/    # one subsystem
```

UI/web proof is mandatory for UI/browser-verifiable tickets — see Playwright section below.

## Repo layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | Entry point. Loads `.env`, initializes Supabase, mounts `app.dart`. |
| `lib/src/app.dart` | App root. Theme + router wiring. |
| `lib/src/audio/` | Audio engine + Riverpod providers (`audio_engine.dart`, `audio_providers.dart`). |
| `lib/src/core/theme/` | Design tokens. `storia_colors.dart`, `storia_text_theme.dart`, `storia_spacing.dart`, `storia_motion.dart`, `app_theme.dart`. **Use these tokens; do not hardcode colors/sizes.** |
| `lib/src/core/widgets/` | Shared UI primitives (sketch buttons/cards/inputs, watercolor scaffold, parental gate). Reuse these before creating new ones. |
| `lib/src/core/utils/` | Cross-cutting helpers. |
| `lib/src/core/resilient_cache_manager.dart` | Network/asset cache. |
| `lib/src/data/` | Repositories + models + top-level providers. `book_repository.dart`, `analytics_repository.dart`, `pronunciation_repository.dart`, `models.dart`, `providers.dart`. |
| `lib/src/features/<name>/` | One feature per folder. Internal structure varies; complex features use `data/`, `domain/`, `presentation/` (see `auth/`). |
| `lib/src/routing/app_router.dart` | GoRouter config. Wire new screens here. |
| `test/` | Mirrors `lib/src/` layout (`test/features/...`, `test/data/...`). |
| `assets/{images,svgs,gifs,tiles}/` | Listed in `pubspec.yaml`. Add new dirs there too. |
| `specs/` | Feature implementation plans + audits. Read the matching one before non-trivial feature work. |
| `docs/` | Long-form docs. |
| `WORKFLOW.md` | Symphony Linear SOP (workpad template, status map, validation gates). |
| `.wolf/` | OpenWolf state — see Gotchas. |
| `.pi/` | Pi Coding Agent harness (orchestrator, leads, workers, expertise, evolution). Canonical agent location — see Gotchas. |
| `skills-lock.json` | Pins the official Dart & Flutter skills (sourced from the `flutter/skills` GitHub repo) installed globally under `~/.agents/skills/`. |
| `bin/` | `bootstrap.sh` (env setup), `verify.sh` (analyze + test gate), `pi-symphony.sh` (Linear poller). |
| `coverage/`, `build/`, `.dart_tool/` | Generated. Do not commit. |

## Stack + conventions

- **Flutter** (single package, no melos). `pubspec.yaml` is authoritative.
- **State**: `flutter_riverpod ^2.6.1`. **No codegen** in this repo (no `build_runner`, no `riverpod_generator`, no `freezed`). Hand-written `Provider`/`StateNotifierProvider` patterns. Don't introduce codegen without ticket approval.
- **Routing**: `go_router ^15.1.2` configured in `lib/src/routing/app_router.dart`.
- **Backend**: `supabase_flutter ^2.9.1` (auth + data). Initialized in `main.dart` from `.env`.
- **Audio/TTS**: `flutter_tts`, `speech_to_text`, custom engine in `lib/src/audio/`.
- **Games**: `flame ^1.21.0` + `flame_tiled` for the gamified library.
- **Animation**: `flutter_animate`, `rive`, `gooey`, `cue`, `confetti`.
- **HTTP**: `dio` for app traffic, `http` available.
- **Lint**: `flutter_lints ^5.0.0` via `analysis_options.yaml`. **`flutter analyze` must pass with zero warnings before handoff.**

## Where to put new code

| Change type | Goes in |
|-------------|---------|
| New screen | `lib/src/features/<feature>/presentation/` (or feature root for simple features) + register route in `lib/src/routing/app_router.dart` |
| New provider for shared state | `lib/src/data/providers.dart` (cross-feature) or feature-local `*_providers.dart` |
| New repository | `lib/src/data/<thing>_repository.dart` + provider |
| New shared widget | `lib/src/core/widgets/` (use existing sketch/watercolor primitives first) |
| Theme token change | `lib/src/core/theme/storia_*.dart` — never inline values |
| New asset | drop in `assets/<kind>/` AND add the dir to `pubspec.yaml` flutter.assets if it's a new kind |

## Playwright CLI (required UI proof in Linear tickets)

`playwright-cli` is on PATH globally. Playwright WebM proof is mandatory when a ticket has UI/browser-verifiable acceptance criteria (screens, navigation, copy, visual state, auth/onboarding, or layout). Pure Dart/data-only changes can skip Playwright if the workpad says why.

Canonical App Review auth bypass flow for UI proof:

```text
Start your journey -> app-review@storia.kids -> parent birth year -> onboarding -> library
```

Use a valid adult parent birth year such as `1980`, complete onboarding selections, and end on the library screen.

```bash
flutter run -d chrome &      # leave running on its default port
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# perform the ticket-specific UI flow
playwright-cli video-stop --filename=recordings/<ticket-id>-proof.webm
playwright-cli close
```

Record `recordings/<ticket-id>-proof.webm` (or `recordings/<ticket-id>-<flow>.webm` for multiple flows) in the Linear workpad and PR. At handoff, the runner first accepts an existing ticket-specific WebM; if missing, it automatically runs `PLAYWRIGHT_PROOF_CAPTURE_CMD` or the default `bin/symphony-capture-playwright-proof.sh` App Review flow, then re-validates evidence. The default script serves Flutter with the `web-server` device and creates/removes a temporary `web/` scaffold when the repo has no tracked web target. The runner requires an uploaded/shareable artifact link by default via `PLAYWRIGHT_PROOF_UPLOAD_CMD`; use `PLAYWRIGHT_PROOF_REQUIRE_UPLOAD=0` only for local dry runs where a repo-local path is acceptable. `PLAYWRIGHT_PROOF_CAPTURE_DRY_RUN=1` creates placeholder files for harness tests only, not valid PR evidence. Prefer Flutter widget/integration tests for Dart-side behavior; Playwright proof is the human-reviewable UI evidence.

## Gotchas

- **Read `.wolf/buglog.json` BEFORE fixing any bug.** Project rule: known fixes are logged here. After fixing, append a new entry with `error_message`, `root_cause`, `fix`, `tags`.
- **Read `.wolf/cerebrum.md` BEFORE generating code.** Contains the project Do-Not-Repeat list, learned preferences, and conventions discovered from prior corrections.
- **`.wolf/anatomy.md` is auto-generated** by OpenWolf hooks and lists every tracked file with token estimates. Do not hand-edit. After writing/editing files, the OpenWolf hook will update it.
- **`.pi/` is the canonical agent harness location.** A near-duplicate `.claude/agents/` tree exists with the same 13 filenames; some files differ (e.g. `storia-orchestrator.md`). When in doubt, `.pi/` matches what `WORKFLOW.md` and `README.md` reference. Do not edit both — pick `.pi/` and flag the duplication if a ticket touches it.
- **No codegen.** Don't run `dart run build_runner` — there's nothing to generate and no `*.g.dart` / `*.freezed.dart` files to regenerate.
- **`.env` is a Flutter asset** (declared in `pubspec.yaml`). Missing it breaks startup. `bootstrap.sh` provisions it from `.env.example`.
- **iOS Sign-in-with-Apple** has a manual `xcodebuild -exportArchive` path documented in `README.md`. Do not change signing config (bundle ID, team ID, profile, certs) unless the ticket explicitly asks.
- **Generated logs in `logs/`** may be dirty in the repo. Don't include log churn in PRs unless the ticket calls for it.

## Pi Coding Agent harness

This repo ships a Pi orchestrator/leads/workers harness in `.pi/`. Use the `pi` CLI when it accelerates planning, audits, or specialized work:

```bash
pi chain storia-plan "Plan: <linear-issue-title>"
pi chain storia-audit "Audit: <change-area>"
pi team storia-quality
```

Symphony does **not** spawn nested long-running orchestration; the primary worker is the Codex app-server session. Use `pi` only when it helps the current ticket. See `README.md` "Agent Harness (Pi Coding Agent)" for full pipeline list.

## Skills (official Dart & Flutter knowledge bodies)

The official Dart & Flutter skills ([introduced by the Flutter team](https://blog.flutter.dev/introducing-skills-for-dart-and-flutter-23837c6ec0ae)) are installed globally under `~/.agents/skills/<name>/SKILL.md` and pinned for this repo via `skills-lock.json` (sourced from the `flutter/skills` GitHub repo). Open the relevant skill body when a task matches its description. Available:

- **Dart:** dart-add-unit-test, dart-build-cli-app, dart-collect-coverage, dart-fix-runtime-errors, dart-generate-test-mocks, dart-migrate-to-checks-package, dart-resolve-package-conflicts, dart-run-static-analysis, dart-use-pattern-matching
- **Flutter:** flutter-add-integration-test, flutter-add-widget-preview, flutter-add-widget-test, flutter-apply-architecture-best-practices, flutter-build-responsive-layout, flutter-fix-layout-issues, flutter-implement-json-serialization, flutter-setup-declarative-routing, flutter-setup-localization, flutter-use-http-package

**Notes:**
- This repo uses Riverpod 2.6.1 and **no codegen** (no `build_runner`/`freezed`). Skills that lean on codegen (e.g. `dart-generate-test-mocks` with `build_runner`) conflict with repo conventions — follow the hand-written patterns in this repo instead, and don't introduce codegen without a ticket.
- Prefer this repo's existing theme tokens, sketch/watercolor primitives, and provider patterns over a skill's generic scaffolding when they diverge.

### Skill usage rules

1. If a task clearly matches a skill's description, open `~/.agents/skills/<name>/SKILL.md` and follow its workflow.
2. Resolve relative paths inside SKILL.md against the skill directory.
3. Load files from `references/` only when needed.
4. Reuse `scripts/` and `assets/` if the skill ships them.
5. Multiple skills relevant? State the order, use the minimal set.
6. Where a skill conflicts with repo conventions (no codegen, design tokens, Riverpod 2.x patterns), repo conventions win.
7. Skill missing or path unreadable? Say so and proceed with best-effort fallback.

## Top files to bookmark

- `WORKFLOW.md` — pi-symphony SOP (read this when picking up a Linear ticket)
- `bin/pi-symphony.sh` — Linear-driven pi dispatcher
- `lib/src/app.dart` — root wiring
- `lib/src/routing/app_router.dart` — routes
- `lib/src/core/theme/app_theme.dart` — theme entry
- `lib/src/data/providers.dart` — top-level Riverpod providers
- `pubspec.yaml` — deps + assets
- `.wolf/buglog.json` — known fixes
- `.wolf/cerebrum.md` — preferences + do-not-repeat
- `analysis_options.yaml` — lint config
