# Mobile Word Pronunciation Task Checklist

Status: Draft  
Date: 2026-04-24  
Scope: `storia-mobile`  
Source spec: `../storia/specs/word-pronunciation-cross-platform-spec.md`

## Goal

Break the mobile pronunciation work into implementation-ready tasks with owners, dependencies, and acceptance criteria suitable for engineering tickets.

## Milestone summary

- **M1:** Data contract and normalization
- **M2:** Manifest-backed long-press playback
- **M3:** Safe audio orchestration
- **M4:** Cache, preload, and offline fallback polish
- **M5:** Test and QA readiness

---

## M1 — Data contract and normalization

### M1.1 Add Flutter pronunciation manifest models

**Goal**
Add typed Flutter models for the shared pronunciation manifest contract.

**Files**
- `lib/src/data/pronunciation_models.dart`
- optional light changes in `lib/src/data/models.dart`

**Tasks**
- [ ] Add `PronunciationAudioAsset`
- [ ] Add `WordPronunciation`
- [ ] Add `BookPronunciationManifest`
- [ ] Add JSON parsing for nested audio fields
- [ ] Make model parsing tolerant of partial entries and missing optional fields

**Acceptance criteria**
- [ ] A manifest JSON payload can be parsed into strongly typed Flutter models
- [ ] Missing optional audio fields do not throw
- [ ] Unknown or extra fields do not break parsing
- [ ] No changes are required to `WordTimestamp`

**Dependencies**
- none

---

### M1.2 Expose book-level pronunciation metadata

**Goal**
Allow the mobile app to know whether a book has pronunciation support and where to fetch the manifest.

**Files**
- `lib/src/data/book_repository.dart`
- `lib/src/data/models.dart`

**Tasks**
- [ ] Add `hasPronunciations` and/or `pronunciationManifestUrl` support to `Book`
- [ ] Update Supabase query to fetch pronunciation metadata if available
- [ ] Keep parsing backward-compatible for books without pronunciation support

**Acceptance criteria**
- [ ] Books without pronunciation metadata still load normally
- [ ] Books with pronunciation metadata expose it through the mobile data layer
- [ ] Reader code can distinguish manifest-present vs manifest-absent paths

**Dependencies**
- [ ] backend/runtime contract confirmed

---

### M1.3 Add shared mobile word normalizer

**Goal**
Align mobile lookup keys with the shared backend/web normalization contract.

**Files**
- `lib/src/features/reader/runtime/internal/word_normalizer.dart`
- `lib/src/features/reader/runtime/internal/page_words_indexer.dart`

**Tasks**
- [ ] Implement lowercase normalization
- [ ] Implement punctuation stripping
- [ ] Implement apostrophe handling
- [ ] Implement hyphen handling
- [ ] Implement unicode normalization or equivalent canonicalization strategy
- [ ] Return null/invalid result for tokens that should not be looked up
- [ ] Replace ad hoc `_cleanWord` usage in `page_words_indexer.dart`

**Acceptance criteria**
- [ ] The same visible token resolves to the same key expected by backend/web examples
- [ ] Punctuation-only tokens are rejected safely
- [ ] Contractions and hyphenated words behave deterministically
- [ ] Existing page indexing still works after the change

**Dependencies**
- [ ] shared normalization rules/examples from source spec or backend implementation

---

### M1.4 Add pronunciation repository and provider wiring

**Goal**
Create the data access layer for manifest fetching and caching.

**Files**
- `lib/src/data/pronunciation_repository.dart`
- `lib/src/data/providers.dart`

**Tasks**
- [ ] Add repository for manifest fetch by book metadata or book ID
- [ ] Add in-memory cache keyed by `book.id`
- [ ] Return graceful null on missing support or fetch failure
- [ ] Add Riverpod provider wiring

**Acceptance criteria**
- [ ] First manifest request fetches data successfully when supported
- [ ] Repeated requests in the same session reuse cache
- [ ] Missing manifest support returns a safe null path
- [ ] Fetch failure does not throw into the reader UI

**Dependencies**
- [ ] M1.1
- [ ] M1.2

---

## M2 — Manifest-backed long-press playback

### M2.1 Replace long-press TTS-first logic with manifest-first lookup

**Goal**
Keep mobile interaction semantics the same while changing the backing implementation for long-press.

**Files**
- `lib/src/features/reader/runtime/providers/word_tts_provider.dart`
  - or rename to `word_pronunciation_provider.dart`
- `lib/src/features/reader/reader_screen.dart`

**Tasks**
- [ ] Keep tap behavior as quick whole-word playback for phase 1
- [ ] Change long-press flow to:
  - normalize token
  - lookup manifest entry
  - choose manifest-backed path when possible
  - fall back to current TTS path when needed
- [ ] Preserve current highlight / tapped-word state behavior
- [ ] Ensure only the active request clears its own transient state

**Acceptance criteria**
- [ ] Tap still plays whole-word help as before
- [ ] Long-press uses manifest-backed pronunciation when a valid entry exists
- [ ] Long-press falls back safely when entry is missing
- [ ] Missing or invalid lookup never crashes the reader
- [ ] Highlight state is not left stuck after playback ends or is replaced

**Dependencies**
- [ ] M1.3
- [ ] M1.4

---

### M2.2 Implement pronunciation playback resolution order

**Goal**
Apply the phase-1 playback policy consistently.

**Files**
- pronunciation provider/service layer
- optional helper in `lib/src/audio/audio_engine.dart`

**Tasks**
- [ ] If `breakdown` exists, play it first
- [ ] If `fullWord` exists, replay whole word after breakdown or as standalone fallback
- [ ] If no usable manifest audio exists, fall back to TTS `soundOut(...)`
- [ ] Keep fallback path explicit and observable in code

**Acceptance criteria**
- [ ] `breakdown + fullWord` entries play in the correct order
- [ ] `fullWord`-only entries still produce useful playback
- [ ] entries with no usable audio fall back to TTS instead of failing silently

**Dependencies**
- [ ] M2.1

---

### M2.3 Add optional manifest preload on reader start

**Goal**
Reduce first-interaction latency when pronunciation support exists.

**Files**
- `lib/src/features/reader/reader_screen.dart`
- provider or repository preload helper

**Tasks**
- [ ] Detect whether active book supports pronunciations
- [ ] Trigger preload once on reader start if support exists
- [ ] Avoid duplicate preload storms across rebuilds

**Acceptance criteria**
- [ ] Manifest preload happens at most once per reader session/book load
- [ ] Reader remains usable even if preload fails
- [ ] First long-press still works whether preload succeeded or not

**Dependencies**
- [ ] M1.4

---

## M3 — Safe audio orchestration

### M3.1 Add pronunciation interaction channel to `AudioEngine`

**Goal**
Move manifest-backed pronunciation audio onto a deterministic player path.

**Files**
- `lib/src/audio/audio_engine.dart`

**Tasks**
- [ ] Add dedicated pronunciation `AudioPlayer`
- [ ] Add pronunciation stop method
- [ ] Add sequence playback helper for breakdown/full-word clips
- [ ] Add internal request ID or cancellation token tracking

**Acceptance criteria**
- [ ] Manifest-backed audio can be played independently of narration and soundscape players
- [ ] New pronunciation requests cancel or replace the old one deterministically
- [ ] Stale requests cannot complete and mutate current reader state incorrectly

**Dependencies**
- [ ] M2.2

---

### M3.2 Implement narration coexistence rules

**Goal**
Match the source spec’s pause/resume behavior on mobile.

**Files**
- `lib/src/audio/audio_engine.dart`
- pronunciation provider/service layer
- `lib/src/features/reader/runtime/providers/reader_session_provider.dart` if needed

**Tasks**
- [ ] Detect whether narration was playing before pronunciation started
- [ ] Pause narration before pronunciation playback begins
- [ ] Resume narration only if it was active before and user intent has not changed
- [ ] Keep paused narration paused when it was already paused

**Acceptance criteria**
- [ ] Narration active -> pronunciation -> resume works reliably
- [ ] Narration paused -> pronunciation does not auto-start narration
- [ ] User override during playback prevents unwanted auto-resume

**Dependencies**
- [ ] M3.1

---

### M3.3 Preserve practice/listening state safely

**Goal**
Ensure pronunciation playback does not corrupt practice-mode or listening state.

**Files**
- pronunciation provider/service layer
- `lib/src/features/reader/runtime/reader_session_impl.dart`

**Tasks**
- [ ] Capture whether listening/practice state is active before pronunciation starts
- [ ] Pause or suspend listening interaction only if required by current behavior
- [ ] Restore prior state only when the triggering pronunciation request still owns restoration

**Acceptance criteria**
- [ ] Starting pronunciation during listening does not leave the session stuck
- [ ] Restoring state after interrupted pronunciation does not fight newer user actions
- [ ] Practice mode remains usable after repeated pronunciation interactions

**Dependencies**
- [ ] M2.1
- [ ] M3.2

---

### M3.4 Cancel pronunciation work on page change

**Goal**
Prevent cross-page audio leakage and stale state restoration.

**Files**
- `lib/src/audio/audio_engine.dart`
- pronunciation provider/service layer
- `lib/src/features/reader/runtime/reader_session_impl.dart`

**Tasks**
- [ ] Stop or invalidate active pronunciation request on page transition
- [ ] Ensure page change does not leave stale highlight state behind
- [ ] Prevent old page playback completion from resuming narration incorrectly

**Acceptance criteria**
- [ ] Navigating to another page cancels or safely ignores old pronunciation work
- [ ] No prior-page pronunciation continues playing after page transition unless explicitly allowed
- [ ] Destination page remains fully interactive

**Dependencies**
- [ ] M3.1

---

## M4 — Cache, preload, and offline fallback polish

### M4.1 Harden manifest session cache

**Goal**
Prevent unnecessary refetches and keep failure behavior predictable.

**Files**
- `lib/src/data/pronunciation_repository.dart`

**Tasks**
- [ ] Cache successful manifest fetches by book ID
- [ ] Decide whether failures are cached briefly or retried immediately
- [ ] Clear or reset cache correctly when switching books or app session resets

**Acceptance criteria**
- [ ] Repeated interactions on the same book do not refetch manifest unnecessarily
- [ ] A prior failure does not permanently poison future recovery after network returns
- [ ] Cache does not leak data across different books

**Dependencies**
- [ ] M1.4

---

### M4.2 Define audio asset caching approach

**Goal**
Improve repeat-play performance without blocking phase 1.

**Files**
- `lib/src/audio/audio_engine.dart`
- caching helper if needed

**Tasks**
- [ ] Decide whether platform/network cache is enough for phase 1
- [ ] If needed, prototype prefetch for selected URLs
- [ ] Keep cache policy compatible with stable CDN URLs

**Acceptance criteria**
- [ ] Repeat playback latency is acceptable on supported devices/network conditions
- [ ] Lack of explicit prefetch does not break core functionality
- [ ] Future prefetch can be added without changing reader UI contracts

**Dependencies**
- [ ] M3.1

---

### M4.3 Define offline fallback behavior

**Goal**
Ensure long-press remains useful when offline or when assets are unavailable.

**Files**
- pronunciation provider/service layer
- `word_tts_service.dart`

**Tasks**
- [ ] Handle manifest fetch failure gracefully
- [ ] Handle asset playback failure gracefully
- [ ] Fall back to local TTS when possible
- [ ] Exit transient UI state cleanly on failure

**Acceptance criteria**
- [ ] Offline manifest failure does not break the reader
- [ ] Missing or forbidden audio URLs do not leave stuck playback state
- [ ] TTS fallback remains available when manifest-backed assets fail

**Dependencies**
- [ ] M2.1
- [ ] M3.1

---

## M5 — Test and QA readiness

### M5.1 Add normalization unit tests

**Goal**
Lock cross-platform-compatible lookup rules with tests.

**Files**
- `test/features/reader/runtime/word_normalizer_test.dart`

**Tasks**
- [ ] Add capitalization cases
- [ ] Add punctuation cases
- [ ] Add apostrophe cases
- [ ] Add hyphen cases
- [ ] Add punctuation-only invalid-token cases
- [ ] Add unicode variant cases where supported

**Acceptance criteria**
- [ ] Test coverage exists for the main normalization rules from the shared contract
- [ ] Regressions in normalization fail fast in CI/local test runs

**Dependencies**
- [ ] M1.3

---

### M5.2 Add manifest lookup tests

**Goal**
Verify correct entry resolution and fallback behavior.

**Files**
- `test/features/reader/runtime/pronunciation_lookup_test.dart`

**Tasks**
- [ ] Test manifest entry found
- [ ] Test manifest entry missing
- [ ] Test `breakdown + fullWord`
- [ ] Test `fullWord`-only
- [ ] Test malformed or incomplete entries

**Acceptance criteria**
- [ ] Lookup logic selects the expected playback path for each manifest shape
- [ ] Missing entries resolve to fallback logic without exception

**Dependencies**
- [ ] M1.1
- [ ] M1.4
- [ ] M2.2

---

### M5.3 Add playback transition tests

**Goal**
Verify narration/pronunciation state transitions and cancellation behavior.

**Files**
- `test/features/reader/runtime/pronunciation_playback_controller_test.dart`
- `test/audio/audio_engine_pronunciation_test.dart`

**Tasks**
- [ ] Test narration active -> pause -> pronunciation -> resume
- [ ] Test narration paused -> pronunciation -> remain paused
- [ ] Test repeated rapid long-press interactions
- [ ] Test page navigation cancellation
- [ ] Test fallback after manifest failure

**Acceptance criteria**
- [ ] State transitions are deterministic under repeated interactions
- [ ] No test case leaves the runtime in an ambiguous resume state
- [ ] Cancel-and-replace behavior is covered explicitly

**Dependencies**
- [ ] M3.1
- [ ] M3.2
- [ ] M3.4

---

### M5.4 Produce manual mobile QA checklist

**Goal**
Define the minimum manual verification required before rollout.

**Suggested coverage**
- [ ] iOS device path
- [ ] Android device path
- [ ] normal network
- [ ] slow network
- [ ] offline or failing manifest request
- [ ] narration playing
- [ ] narration paused
- [ ] repeated interactions
- [ ] page navigation during pronunciation
- [ ] partial manifest support
- [ ] no manifest support

**Acceptance criteria**
- [ ] A tester can execute the checklist without code-level knowledge
- [ ] Success, fallback, and failure paths all have expected outcomes documented

**Dependencies**
- [ ] M2.1
- [ ] M3.2
- [ ] M4.3

---

## Cross-cutting release criteria

The mobile phase-1 implementation is ready for rollout only when all of the following are true:

- [ ] Tap still preserves current quick whole-word behavior
- [ ] Long-press uses manifest-backed pronunciation where available
- [ ] Missing manifest support never breaks reading
- [ ] Narration pause/resume behavior is deterministic
- [ ] Repeated interactions do not create overlapping or stuck pronunciation state
- [ ] Page transitions do not leak old pronunciation playback
- [ ] Normalization rules are tested
- [ ] Fallback behavior is tested
- [ ] Manual QA has run on both iOS and Android

---

## Recommended implementation order

1. [ ] M1.1 Add manifest models
2. [ ] M1.2 Expose book pronunciation metadata
3. [ ] M1.3 Add shared word normalizer
4. [ ] M1.4 Add pronunciation repository and providers
5. [ ] M2.1 Replace long-press with manifest-first lookup
6. [ ] M2.2 Implement playback resolution order
7. [ ] M3.1 Add pronunciation channel to `AudioEngine`
8. [ ] M3.2 Implement narration coexistence rules
9. [ ] M3.3 Preserve practice/listening state safely
10. [ ] M3.4 Cancel pronunciation on page change
11. [ ] M4.1 Harden manifest cache
12. [ ] M4.3 Define offline fallback behavior
13. [ ] M5.1 Add normalization tests
14. [ ] M5.2 Add manifest lookup tests
15. [ ] M5.3 Add playback transition tests
16. [ ] M5.4 Run manual mobile QA checklist

---

## Notes for ticket creation

When these tasks are converted into implementation tickets:

- keep data-layer and runtime-layer work separate
- call out whether each ticket is blocked on backend contract availability
- make normalization parity a first-class acceptance criterion
- prefer cancel-and-replace language consistently across tickets
- keep phase-1 scope narrow: tap behavior unchanged, long-press upgraded
