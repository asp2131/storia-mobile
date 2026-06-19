# Loratone Mobile

Flutter mobile app for Loratone.

## Setup

1. Install Flutter and iOS tooling.
2. Run:

```bash
flutter pub get
```

3. Start the app:

```bash
flutter run
```

## Repository Scripts

The `bin/` directory contains helper scripts used by both humans and Symphony agents:

- `bin/bootstrap.sh` sets up a fresh checkout by running `flutter pub get`, creating `.env` from `.env.example` when needed, and running `pod install` on macOS when iOS pods are available.
- `bin/verify.sh` is the pre-handoff validation gate; it runs `flutter analyze` and `flutter test`.
- `bin/pi-symphony.sh` polls Linear and dispatches Pi/Symphony workspaces for automated ticket processing.
- `bin/loopany-storia.sh` runs the globally-installed loopany CLI with a Storia-scoped `LOOPANY_HOME`; see `docs/tooling/loopany.md`.

## iOS Sign In with Apple

The iPhone flow uses native Apple Sign In with Supabase as the backend session issuer.

Required Apple-side setup:

- App ID: `com.storia.storiaFlutter`
- Team ID: `FKB97T38LY`
- Capability enabled on the App ID: `Sign in with Apple`
- App Store provisioning profile: `Storia App Store Profile`
- Distribution certificate: `Apple Distribution`

The app entitlement lives in [ios/Runner/Runner.entitlements](/Users/akinpound/Documents/experiments/storia-mobile/ios/Runner/Runner.entitlements).

## iOS App Store Build

Archive with Flutter:

```bash
flutter build ipa --export-method app-store
```

If Flutter export fails with a provisioning/profile mismatch around `Sign in with Apple`, use the working two-step path below.

### 1. Build the archive

```bash
flutter build ipa --export-method app-store
```

If archive succeeds but IPA export fails, keep the generated archive at:

`build/ios/archive/Runner.xcarchive`

### 2. Export manually with Xcode

Create an export options plist that pins the bundle ID to the correct provisioning profile:

```bash
printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'  <key>method</key>' \
'  <string>app-store-connect</string>' \
'  <key>signingStyle</key>' \
'  <string>manual</string>' \
'  <key>teamID</key>' \
'  <string>FKB97T38LY</string>' \
'  <key>signingCertificate</key>' \
'  <string>Apple Distribution</string>' \
'  <key>provisioningProfiles</key>' \
'  <dict>' \
'    <key>com.storia.storiaFlutter</key>' \
'    <string>Storia App Store Profile</string>' \
'  </dict>' \
'</dict>' \
'</plist>' > /tmp/storia-export-options.plist
```

Then export:

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa-manual \
  -exportOptionsPlist /tmp/storia-export-options.plist
```

Successful output lands in:

`build/ios/ipa-manual`

## Agent Harness (Pi Coding Agent)

This repo includes a three-tier agent harness in `.pi/` built for use with Pi Coding Agent. It follows the Orchestrator → Team Leads → Workers architecture with a self-improvement loop.

### Architecture

| Tier | Agents | Model | Role |
|------|--------|-------|------|
| 1 | `storia-orchestrator` | opus | Decomposes goals, delegates to leads, never codes |
| 2 | `ui-lead`, `feature-lead`, `infra-lead`, `quality-lead` | opus | Plan domain work, delegate to workers, take over on failure |
| 3 | 10 specialized workers (e.g. `view-generator`, `state-architect`, `reader-engine`) | sonnet/haiku | Execute one task type per agent |
| Meta | `self-improver` | opus | Evolves expertise files and agent prompts after every cycle |

### Pipelines

```bash
# Plan a feature (no execution)
pi chain storia-plan "Add reading comprehension quizzes after chapters"

# Full feature build with quality gate + self-improvement
pi chain storia-build-feature "Add reading comprehension quizzes"

# Quick prototype (skip quality gate)
pi chain storia-rapid-build "Prototype quiz UI"

# Fix a bug with auto-learning
pi chain storia-fix-bug "TTS stops at chapter boundaries"

# Manual evolution cycle
pi chain storia-evolve "Review last 3 builds"

# Reader-specific work
pi chain storia-build-reader "Add word-level highlight tracking"

# Game-specific work
pi chain storia-build-game "Add achievement badges to map"

# Full quality audit
pi chain storia-audit "Audit reader feature changes"
```

### Teams

Use `pi team <name>` to activate a specific team:

- `storia-full` — All leads (orchestrator delegates)
- `storia-ui` — UI lead + view-generator, animation-specialist, theme-enforcer
- `storia-feature` — Feature lead + state-architect, reader-engine, game-builder, route-wirer
- `storia-quality` — Quality lead + test-writer, a11y-auditor, perf-validator
- `storia-reader` — Reader-focused cross-team
- `storia-game` — Gamification-focused cross-team
- `storia-rapid` — All leads, no quality gate

### Self-Improvement

Every pipeline ends with the `self-improver` agent, which:

1. Collects retrospectives from leads (what worked, what failed)
2. Updates expertise files in `.pi/expertise/` (agent mental models, max 7K tokens each)
3. Refines agent prompts when instructions are ambiguous or cause repeated failures
4. Logs all changes to `.pi/evolution/changelog.md`

Tracked in `.pi/evolution/`: `changelog.md`, `failures.jsonl`, `metrics.json`, `reverted.md`.

### Key Files

- `.pi/agents/storia-orchestrator.md` — Orchestrator definition
- `.pi/agents/storia-team/` — All lead and worker definitions
- `.pi/agents/teams.yaml` — Team compositions
- `.pi/agents/agent-chain.yaml` — Pipeline definitions
- `.pi/expertise/` — Agent mental models (hotloaded into prompts)
- `.pi/harness/` — Till-Done List, self-improvement, and model rotation protocols
- `.pi/evolution/` — Self-improvement tracking

## Why this is needed

`flutter build ipa` can successfully create the archive but still fail during `exportArchive` when Xcode picks the wrong signing context for a capability-enabled app. In this project, the failure showed up after native `Sign in with Apple` was added on iPhone.

The manual `xcodebuild -exportArchive` step works because it explicitly maps:

- `com.storia.storiaFlutter` -> `Storia App Store Profile`

That removes ambiguity during export.
