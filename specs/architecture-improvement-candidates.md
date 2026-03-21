# Architecture Improvement Candidates

Generated: 2026-03-20

Produced by codebase architectural analysis. Each candidate is a place where a shallow module, tight coupling, or global mutable state creates testing friction or navigation friction.

---

## Candidate 1 — ReaderScreen audio state management

**Cluster:** `lib/src/features/reader/reader_screen.dart`, `lib/src/audio/audio_engine.dart`, `lib/src/audio/audio_providers.dart`

**Why coupled:** `ReaderScreen` directly subscribes to 3 audio streams in `initState`, manually mirrors engine state into ValueNotifiers (`_narrationPositionNotifier`, `_isNarrationPlayingNotifier`), and calls engine methods directly. Three state patterns coexist inside one widget: engine-internal state, streams, and ValueNotifiers.

**Dependency category:** Co-owned concept (audio playback state)

**Problem in detail:**
- `initState` wires subscriptions to `narrationPositionStream`, `narrationPlayingStream`, and `soundscapePlayingStream` manually
- UI reads ValueNotifiers (`ValueListenableBuilder`) that are manually synced from streams
- Lifecycle management (subscribe/cancel) lives in the screen rather than a dedicated layer
- Any change to AudioEngine's exposed streams requires updating ReaderScreen

**Test impact:** Currently impossible to test page transitions with audio sync without a real `just_audio` player. A boundary test at an `AudioPlaybackState` abstraction would replace fragile integration tests.

**Status:** Selected for implementation — see agent team plan below.

---

## Candidate 2 — Soundscape resolution logic buried in `models.dart`

**Cluster:** `lib/src/data/models.dart` (lines 417–525), `lib/src/data/book_repository.dart`, `lib/src/data/providers.dart`

**Why coupled:** 108 lines of fallback logic for soundscape resolution (page assignments vs. scene relations with admin approval, range precedence, sorting) lives in `PageData.fromJson()`. Callers get parsed data but have no visibility into which resolution path was taken.

**Dependency category:** Shallow module — interface complexity ≈ implementation complexity

**Test impact:** Currently needs diverse JSON fixtures with no way to assert which resolution path was taken. A `SoundscapeResolver` boundary would let you test each fallback path in isolation.

---

## Candidate 3 — App router redirect function

**Cluster:** `lib/src/routing/app_router.dart`, `lib/src/features/auth/data/auth_providers.dart`, `lib/src/features/onboarding/data/app_review_flow_providers.dart`

**Why coupled:** A single `redirect` function watches two ChangeNotifiers and encodes all navigation rules — auth state, onboarding completion, first-time setup, app review bypass — in nested conditionals.

**Dependency category:** Cross-boundary dependency (auth + review + routing)

**Test impact:** Currently untestable without a full router + auth + review stack. A `NavigationPolicy` abstraction would let you unit test each redirect rule as a pure function.

---

## Candidate 4 — `ParentalGate` static lockout state

**Cluster:** `lib/src/core/widgets/parental_gate.dart`, `lib/src/features/library/library_screen.dart`

**Why coupled:** `GateLockout` is a global static, meaning test isolation is impossible — one test's lockout state bleeds into the next. Timer-based second-by-second mutation makes timing-dependent tests flaky.

**Dependency category:** Global mutable state

**Test impact:** Current tests (if any) must reset global state manually. An injected `GateLockoutPolicy` would enable deterministic testing.

---

## Candidate 5 — Authentication flow screen-to-repository coupling

**Cluster:** `lib/src/features/auth/presentation/sign_in_screen.dart`, `lib/src/features/auth/data/auth_repository.dart`, `lib/src/features/auth/data/auth_providers.dart`, `lib/src/routing/app_router.dart`

**Why coupled:** `SignInScreen` directly calls repository methods, watches `authViewStateProvider` to decide when to navigate, and has hardcoded route strings. Changes to auth methods or navigation rules require updating the screen.

**Dependency category:** Presentation coupled to data layer

**Test impact:** Widget tests for `SignInScreen` require a real or mocked `AuthRepository`. A `SignInController` or use-case layer would let you test login flows independently of the UI.
