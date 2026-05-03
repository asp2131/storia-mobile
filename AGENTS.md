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

UI/web proof when relevant — see Playwright section below.

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
| `.claude/skills/` | Repo-local Flutter/Riverpod skill bodies. |
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

## Playwright CLI (visual proof in Linear tickets)

`playwright-cli` is on PATH globally. Use it when a ticket has a browser/web-verifiable surface or when video/screenshot proof helps a human reviewer.

```bash
mkdir -p recordings
playwright-cli open
playwright-cli video-start
# perform flow
playwright-cli video-stop --filename=recordings/<ticket>-proof.webm
playwright-cli close
```

Record the artifact path in the Linear workpad and PR. Prefer Flutter widget/integration tests for Dart-side behavior; reach for Playwright when the proof is visual or web.

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

## Skills (Flutter / Riverpod knowledge bodies)

Detailed how-tos live in `.claude/skills/<name>/SKILL.md`. Open the relevant skill body when a task matches its description. Available:

- flutter-accessibility, flutter-animation, flutter-app-size, flutter-architecture, flutter-caching, flutter-concurrency, flutter-databases, flutter-environment-setup-{linux,macos,windows}, flutter-home-screen-widget, flutter-http-and-json, flutter-layout, flutter-localization, flutter-native-interop, flutter-performance, flutter-platform-views, flutter-plugins, flutter-routing-and-navigation, flutter-state-management, flutter-testing, flutter-theming
- riverpod-3-0-migration, riverpod-auto-dispose, riverpod-cancel, riverpod-codegen-and-hooks, riverpod-consumers, riverpod-containers, riverpod-eager-initialization, riverpod-family, riverpod-faq-and-practices, riverpod-from-provider, riverpod-getting-started, riverpod-migration, riverpod-mutations, riverpod-observers, riverpod-offline, riverpod-overrides, riverpod-providers, riverpod-pull-to-refresh, riverpod-refs, riverpod-retry, riverpod-scoping, riverpod-select, riverpod-testing

**Note:** This repo currently uses Riverpod 2.6.1, not 3.x. The `riverpod-3-0-migration` skill is available but do not migrate without an explicit ticket.

### Skill usage rules

1. If a task clearly matches a skill's description, open `.claude/skills/<name>/SKILL.md` and follow its workflow.
2. Resolve relative paths inside SKILL.md against the skill directory.
3. Load files from `references/` only when needed.
4. Reuse `scripts/` and `assets/` if the skill ships them.
5. Multiple skills relevant? State the order, use the minimal set.
6. Skill missing or path unreadable? Say so and proceed with best-effort fallback.

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
