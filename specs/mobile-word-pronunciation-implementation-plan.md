# Mobile Word Pronunciation Implementation Plan

Status: Draft  
Date: 2026-04-24  
Scope: `storia-mobile`  
Source spec: `../storia/specs/word-pronunciation-cross-platform-spec.md`

## Purpose

Translate the cross-platform word-pronunciation spec into a Flutter-native implementation plan that fits the current `storia-mobile` architecture.

## Current mobile baseline

Current reader behavior in mobile:

- tap word -> speak whole word via local TTS
- long-press word -> sound out word via local TTS syllable heuristic, then replay whole word
- narration and soundscape are managed separately from word pronunciation
- overlay token normalization is currently simplistic and not yet aligned with the shared cross-platform manifest contract

Relevant current files:

- `lib/src/features/reader/runtime/providers/word_tts_provider.dart`
- `lib/src/features/reader/runtime/services/word_tts_service.dart`
- `lib/src/audio/audio_engine.dart`
- `lib/src/features/reader/page_renderer.dart`
- `lib/src/features/reader/runtime/internal/page_words_indexer.dart`
- `lib/src/data/book_repository.dart`
- `lib/src/data/models.dart`

## Phase-1 mobile product behavior

Keep current semantics for the first mobile rollout:

- tap word = quick whole-word playback
- long-press word = pronunciation breakdown flow
- if no manifest-backed pronunciation is available, long-press falls back safely to the current TTS-based help path
- pronunciation playback pauses narration if narration is active
- narration resumes only if it was active before the pronunciation interaction began and the user has not overridden that intent

## Architectural direction

Implement mobile pronunciation as a manifest-first flow layered onto the current reader runtime.

### Data layer

Add a pronunciation-specific data path.

Responsibilities:

- expose manifest models
- fetch the book pronunciation manifest
- cache manifest data per book for the reader session
- resolve normalized word keys to manifest entries

Recommended additions:

- `lib/src/data/pronunciation_models.dart`
- `lib/src/data/pronunciation_repository.dart`
- provider wiring in `lib/src/data/providers.dart`

### Runtime / orchestration layer

Introduce a pronunciation coordinator instead of keeping all behavior inside the current TTS notifier.

Responsibilities:

- decide playback path for tap and long-press
- pause/resume narration safely
- stop or replace in-flight pronunciation work deterministically
- coordinate manifest-backed audio with fallback TTS
- respect reader session state such as practice mode or listening mode

Recommended additions:

- `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart`
- or a notifier/controller such as `word_pronunciation_provider.dart`

### Audio layer

Extend the audio stack to support a pronunciation interaction channel.

Current state:

- `AudioEngine` owns narration and soundscape players
- local word TTS is external to `AudioEngine`

Recommended phase-1 direction:

- keep TTS as fallback
- add a dedicated pronunciation audio player to `AudioEngine` for manifest-backed clips
- centralize cancel-and-replace behavior there

Recommended changes:

- add a third `AudioPlayer` inside `lib/src/audio/audio_engine.dart`
- add methods for pronunciation playback, interruption, and cleanup

### UI layer

Keep page and overlay UI changes minimal.

Recommended approach:

- keep `PageRenderer` callback shape unchanged if possible
- replace the TTS-only notifier with a pronunciation-aware notifier
- preserve current highlight behavior until product explicitly asks for a different pronunciation-specific state model

## Proposed file-by-file changes

## 1. `lib/src/data/models.dart`

### Goal
Extend runtime book payload support for pronunciation metadata.

### Changes

- add optional book-level fields if backend exposes them:
  - `hasPronunciations`
  - `pronunciationManifestUrl`
- avoid changing `WordTimestamp`
- keep existing page parsing stable

### Notes
If the repo prefers smaller model files, move pronunciation models into a dedicated file instead of expanding `models.dart` further.

## 2. `lib/src/data/pronunciation_models.dart`

### Goal
Represent the shared manifest contract in Flutter models.

### Recommended models

- `PronunciationAudioAsset`
- `WordPronunciation`
- `BookPronunciationManifest`

### Minimum shape for phase 1

- manifest version
- book id
- locale
- default playback mode
- entry map keyed by normalized word
- per-entry optional `breakdown` and `fullWord` audio

## 3. `lib/src/data/book_repository.dart`

### Goal
Expose pronunciation metadata on book fetch.

### Changes

- update Supabase select to include any pronunciation manifest fields available on published books
- keep behavior backward-compatible when fields are absent

### Risks

- backend may not yet expose manifest metadata to mobile payloads
- if not available yet, mobile should use a dedicated repository endpoint for manifest fetch by `bookId`

## 4. `lib/src/data/pronunciation_repository.dart`

### Goal
Fetch and cache manifest data.

### Responsibilities

- `Future<BookPronunciationManifest?> getManifestForBook(Book book)`
- hold in-memory cache for the current app session
- return null on missing manifest support instead of throwing to UI layer

### Behavior

- if book has no pronunciation support -> return `null`
- if manifest fetch fails -> return `null` and allow fallback path
- if manifest loads -> cache by `book.id`

## 5. `lib/src/data/providers.dart`

### Goal
Wire pronunciation repository into Riverpod.

### Additions

- `pronunciationRepositoryProvider`
- optional preload helpers later if needed

## 6. `lib/src/features/reader/runtime/internal/word_normalizer.dart`

### Goal
Align mobile word lookup with the shared cross-platform normalization contract.

### Responsibilities

- lowercase handling
- punctuation stripping
- apostrophe handling
- hyphen handling
- unicode normalization
- invalid-token rejection

### Consumers

- pronunciation lookup flow
- page word indexing
- analytics payload generation
- future QA helpers

## 7. `lib/src/features/reader/runtime/internal/page_words_indexer.dart`

### Goal
Stop using ad hoc word cleaning.

### Changes

- replace `_cleanWord` with shared `normalizeWordToken(...)`
- ensure overlay words and narration timestamp words resolve identically where possible

### Current gap

Current implementation uses:

```dart
word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '')
```

That is likely insufficient for contractions, smart apostrophes, hyphenated words, and unicode edge cases.

## 8. `lib/src/audio/audio_engine.dart`

### Goal
Make pronunciation playback deterministic and safe.

### Recommended additions

- dedicated pronunciation `AudioPlayer`
- request ID or cancellation token for pronunciation work
- helpers such as:
  - `playPronunciationClipSequence(...)`
  - `stopPronunciation()`
  - `isPronunciationPlaying`

### Required behavior

- cancel-and-replace on repeated pronunciation requests
- pause narration before pronunciation starts if narration was active
- resume narration only when appropriate
- avoid disturbing soundscape behavior unless product explicitly requires ducking later

## 9. `lib/src/features/reader/runtime/services/word_tts_service.dart`

### Goal
Keep TTS as fallback, not canonical path.

### Changes

- retain `speak(...)`
- retain `soundOut(...)`
- use only when manifest-backed audio is unavailable or unusable

### Notes
This keeps rollout safe while mobile transitions away from TTS-first pronunciation help.

## 10. `lib/src/features/reader/runtime/providers/word_tts_provider.dart`

### Goal
Replace TTS-only policy with pronunciation-aware interaction handling.

### Recommended direction

Either:

- rename to `word_pronunciation_provider.dart`, or
- keep file name temporarily and expand responsibilities

### New behavior

For tap:

- preserve current quick whole-word behavior in phase 1
- allow future feature flag for pronunciation-on-tap

For long-press:

1. stop any in-flight pronunciation/TTS
2. update highlight state
3. capture pre-interaction narration/listening state
4. resolve normalized token
5. fetch cached or remote manifest entry
6. choose playback path:
   - breakdown clip then full-word clip
   - full-word clip only
   - fallback TTS `soundOut(...)`
7. clear transient state if request survives to completion
8. conditionally restore prior narration/listening state

## 11. `lib/src/features/reader/page_renderer.dart`

### Goal
Minimize surface change.

### Changes

- keep `onWordTap` and `onWordLongPress`
- continue passing token text and global index
- no layout changes required for phase 1

## 12. `lib/src/features/reader/reader_screen.dart`

### Goal
Swap provider wiring without changing the reader UI contract.

### Changes

- replace references to TTS-only notifier with pronunciation-aware notifier
- optionally trigger manifest preload on reader start in a later slice

## 13. Tests

### Recommended new test files

- `test/features/reader/runtime/word_normalizer_test.dart`
- `test/features/reader/runtime/pronunciation_lookup_test.dart`
- `test/features/reader/runtime/pronunciation_playback_controller_test.dart`
- `test/audio/audio_engine_pronunciation_test.dart`

## Playback policy for phase 1

## Trigger mapping

- tap -> existing whole-word help behavior
- long-press -> pronunciation breakdown flow

## Playback resolution order for long-press

1. normalize visible token
2. lookup manifest entry
3. if `audio.breakdown` exists:
   - play breakdown clip
   - optional short pause
   - play `audio.fullWord` if present
4. else if `audio.fullWord` exists:
   - play full-word clip
5. else:
   - fallback to current TTS `soundOut(word)`

## Concurrency policy

Phase-1 default: cancel-and-replace.

If the user long-presses another word while one pronunciation interaction is active:

- previous pronunciation request is cancelled
- latest request becomes the only surviving request
- stale completion must not clear current highlight or incorrectly resume narration

## Narration coexistence policy

If narration is playing when pronunciation begins:

- pause narration
- play pronunciation
- resume narration only if:
  - narration was active at interaction start, and
  - the user did not manually override intent during playback, and
  - the request still survives as the latest pronunciation request

If narration was already paused:

- do not auto-start narration afterward

## Practice-mode policy

Phase 1 recommendation:

- preserve current standard mobile semantics in practice mode unless product says otherwise
- avoid introducing a distinct pronunciation gesture map for practice mode in the first implementation slice
- if listening/mic flow is active, pronunciation interactions should still restore the prior listening state safely

## Caching strategy

## Manifest caching

Phase 1:

- in-memory cache keyed by `book.id`
- fetch lazily on first long-press, or preload on reader start if payload says pronunciations exist

## Audio caching

Phase 1:

- rely on stable URLs and normal network cache behavior
- do not block rollout on aggressive prefetch

## Offline behavior

If manifest or audio is unavailable offline:

- do not break the reader
- use TTS fallback path where possible
- keep interaction responsive

## Suggested delivery slices

## Slice 1 — manifest-backed long-press

Deliver:

- pronunciation models
- pronunciation repository
- shared word normalizer
- long-press manifest-first lookup with TTS fallback

Do not require yet:

- full audio-engine refactor
- explicit offline media prefetch

## Slice 2 — safe audio orchestration

Deliver:

- pronunciation channel in `AudioEngine`
- deterministic cancel-and-replace behavior
- stronger narration resume rules
- page-navigation cancellation behavior

## Slice 3 — cache and preload

Deliver:

- per-book manifest preload
- in-memory cache hardening
- optional asset prefetch for repeat interactions

## Slice 4 — test and rollout readiness

Deliver:

- normalization tests
- playback transition tests
- fallback tests
- device/manual QA checklist execution

## Open decisions

These items should be resolved before implementation begins or early in Slice 1.

1. Where does mobile get manifest metadata?
   - from the book payload, or
   - from a dedicated endpoint by `bookId`

2. Should mobile preload the manifest on reader open when supported?
   - recommended: yes, if `hasPronunciations == true`

3. What exact fallback should mobile use for partial entries?
   - recommended:
     - breakdown -> full word
     - else full-word clip
     - else TTS fallback

4. Should practice mode diverge in phase 1?
   - recommended: no

## Recommended first implementation order

1. add shared mobile word normalizer
2. add pronunciation manifest models
3. add pronunciation repository and providers
4. wire long-press to manifest-first lookup with TTS fallback
5. add pronunciation player/channel in `AudioEngine`
6. add tests
7. add preload/cache polish
