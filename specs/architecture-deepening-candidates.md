# Architecture Deepening Candidates (2026-03-25)

## Context
Initial architecture exploration focused on AI navigability, module depth, and testability boundaries.

## 1) Reader runtime orchestration is spread across UI + engine + practice

- **Cluster**:
  - `lib/src/features/reader/reader_screen.dart`
  - `lib/src/audio/audio_engine.dart`
  - `lib/src/features/reader/reader_audio_state.dart`
  - `lib/src/features/reader/reader_practice_notifier.dart`
  - `lib/src/features/reader/page_renderer.dart`
- **Why they’re coupled**:
  - Page-change behavior, audio transitions, speech practice state, and celebration effects are coordinated from `ReaderScreen` directly.
  - Defects are likely in interaction timing (page flip + async audio + speech callbacks), not isolated helpers.
- **Dependency category**: **True external (Mock)** (audio/session/speech plugins) + in-process orchestration.
- **Test impact**:
  - Replace widget-internal choreography tests with boundary tests on one deep module (e.g., `ReaderSession`) covering `loadBook`, `goToPage`, `togglePractice`, `toggleNarration`, and celebration state transitions.

## 2) Navigation policy is embedded in router construction

- **Cluster**:
  - `lib/src/routing/app_router.dart`
  - `lib/src/features/auth/data/auth_providers.dart`
  - `lib/src/features/onboarding/data/app_review_flow_providers.dart`
- **Why they’re coupled**:
  - Route guarding depends on combined auth + app-review state with many conditional branches inside `redirect`.
- **Dependency category**: **In-process**.
- **Test impact**:
  - Replace ad-hoc navigation checks with boundary tests of a route-policy module (`nextRouteFor(state, location)`), keeping only thin router wiring tests.

## 3) Book decoding/mapping + soundscape resolution lives inside model constructors

- **Cluster**:
  - `lib/src/data/models.dart`
  - `lib/src/data/book_repository.dart`
- **Why they’re coupled**:
  - Domain parsing, sorting, fallback resolution, range assignment precedence, and backend-shape normalization are mixed in model constructors.
- **Dependency category**: **Remote but owned (Ports & Adapters)** + in-process transforms.
- **Test impact**:
  - Replace low-level parser-focused tests with boundary tests on a deep mapper/hydrator contract using fixture payloads and adapter seams.

## 4) Auth flow logic duplicated across screens and tied to provider/platform details

- **Cluster**:
  - `lib/src/features/auth/presentation/sign_in_screen.dart`
  - `lib/src/features/auth/presentation/sign_up_screen.dart`
  - `lib/src/features/auth/data/auth_repository.dart`
  - `lib/src/features/onboarding/data/app_review_flow_providers.dart`
- **Why they’re coupled**:
  - Similar submit/error/success flows are duplicated; app-review bypass is embedded in sign-up; provider-specific behavior leaks into UI.
- **Dependency category**: **True external (Mock)**.
- **Test impact**:
  - Replace duplicated screen behavior tests with boundary tests on an `AuthFlowController` intent/state contract.

## 5) Overlay text rendering pipeline split across micro-modules

- **Cluster**:
  - `lib/src/features/reader/overlay/overlay_text_layer.dart`
  - `lib/src/features/reader/overlay/overlay_text_element.dart`
  - `lib/src/features/reader/overlay/text_overlay_utils.dart`
  - `lib/src/features/reader/page_renderer.dart`
- **Why they’re coupled**:
  - Layout math, active-word timing, style resolution, and highlighting are fragmented.
- **Dependency category**: **In-process**.
- **Test impact**:
  - Replace utility-level tests with boundary tests for an `OverlayLayoutEngine` render-model output contract.
