# Mobile Word Pronunciation — Team Implementation Plan

Status: Ready for implementation
Date: 2026-04-25
Scope: `storia-mobile`
GH Epic: #10
Source docs:
- `specs/mobile-word-pronunciation-implementation-plan.md`
- `specs/mobile-word-pronunciation-task-checklist.md`
- `../storia/specs/word-pronunciation-cross-platform-spec.md`
- Prisma schema: `../storia/prisma/schema.prisma` (table: `book_pronunciations`)

---

## 1. Objective

Replace mobile's heuristic TTS-based long-press pronunciation with the same manifest-backed pronunciation contract already shipping on web. Tap behavior unchanged. Long-press becomes manifest-first → TTS fallback.

---

## 2. Backend contract (already in DB)

Source of truth for manifest entries: `book_pronunciations` table.

| Column | Maps to Flutter field |
|---|---|
| `book_id` | manifest scope key |
| `normalized_word` | entry map key |
| `display_word` | `WordPronunciation.displayWord` |
| `phonetic_display` | `WordPronunciation.phoneticDisplay` |
| `syllables` (Json) | `WordPronunciation.syllables` |
| `breakdown_segments` (Json) | `WordPronunciation.breakdownSegments` |
| `full_word_url` | `audio.fullWord.url` |
| `breakdown_url` | `audio.breakdown.url` |
| `source` | `WordPronunciation.source` |
| `status` | filter: only `generated`/`reviewed` consumed |
| `confidence` | optional |
| `human_reviewed` | optional |

No new backend table required. Mobile fetch path: Supabase `.from('book_pronunciations').select(...).eq('book_id', bookId)`.

---

## 3. Slice plan (delivery order)

### Slice 1 — Data + normalizer (Tickets #11, #12)
**Goal:** manifest fetchable, words resolvable. No UI behavior change yet.

### Slice 2 — Long-press swap (Ticket #13)
**Goal:** long-press uses manifest-first lookup, TTS fallback preserved.

### Slice 3 — Audio channel + concurrency (Tickets #14, #15)
**Goal:** dedicated `AudioPlayer`, deterministic cancel-and-replace, narration coexistence rules.

### Slice 4 — Cache + offline polish (Ticket #16)
**Goal:** session cache, page-change cancellation, offline graceful fallback.

### Slice 5 — Tests + QA (Tickets #17, #18)
**Goal:** unit + widget tests, manual QA matrix.

---

## 4. Ticket → file map

### Ticket #11 — manifest models + repository wiring

**New files:**
- `lib/src/data/pronunciation_models.dart`
- `lib/src/data/pronunciation_repository.dart`

**Edited files:**
- `lib/src/data/providers.dart` — add `pronunciationRepositoryProvider`, `bookManifestProvider(bookId)` family

**Models (Dart):**
```dart
class PronunciationAudioAsset {
  final String url;
  final int? durationMs;
}

class WordPronunciation {
  final String normalizedWord;
  final String? displayWord;
  final String? phoneticDisplay;
  final List<String> syllables;
  final List<String>? breakdownSegments;
  final String source; // 'tts' | 'editor_override' | 'dictionary' | ...
  final double? confidence;
  final bool humanReviewed;
  final PronunciationAudioAsset? breakdown;
  final PronunciationAudioAsset? fullWord;
}

class BookPronunciationManifest {
  final String bookId;
  final Map<String, WordPronunciation> entries; // key = normalizedWord
}
```

**Repository contract:**
```dart
class PronunciationRepository {
  Future<BookPronunciationManifest?> getManifestForBook(String bookId);
  void invalidate(String bookId);
}
```

Implementation:
- Supabase select on `book_pronunciations` filtered by `book_id` and `status in ('generated', 'reviewed')`
- In-memory `Map<String, BookPronunciationManifest>` cache keyed by `bookId`
- Failure returns `null` (do not throw)

**Acceptance:**
- Empty/missing rows → returns manifest with empty entries map (or `null`)
- Repeated fetch within session uses cache
- Fetch failure does not throw to UI

### Ticket #12 — shared word normalizer

**New file:** `lib/src/features/reader/runtime/internal/word_normalizer.dart`

**Function signature:**
```dart
String? normalizeWordToken(String raw);
```

Rules (mirror web/backend):
- Trim whitespace
- Lowercase (locale-insensitive `toLowerCase()` is fine for English; verify with web rules doc before merge)
- Strip leading/trailing punctuation but preserve internal `'` and `-`
- Smart quote → straight apostrophe (`’` → `'`, `‘` → `'`)
- Unicode NFC normalization
- Return `null` for tokens that contain no letters after stripping

**Edited file:** `lib/src/features/reader/runtime/internal/page_words_indexer.dart`
- Replace `_cleanWord` with `normalizeWordToken`
- Skip null results (do not index punctuation-only tokens)

**Acceptance:**
- "Don't" → "don't"
- "Hello." → "hello"
- "high-tech" → "high-tech"
- "..." → null
- Existing page indexing tests still pass

**Risk:** changing normalization may shift narration timestamp lookup. Run reader smoke test after change.

### Ticket #13 — long-press manifest-first lookup + TTS fallback

**Renamed file:** `lib/src/features/reader/runtime/providers/word_tts_provider.dart` → `word_pronunciation_provider.dart`
(or keep filename, expand class)

**New service:** `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart`

Responsibilities:
- Resolve `normalizeWordToken(rawWord)` → manifest entry
- Resolve playback path:
  1. `breakdown` exists → play breakdown, then `fullWord` if present
  2. else `fullWord` → play it
  3. else fallback `WordTtsService.soundOut(word)`
- Preserve current `_wasNarrationPlaying` / `_wasListening` capture-and-restore logic from `WordTtsNotifier`

**Edited files:**
- `lib/src/features/reader/runtime/providers/word_tts_provider.dart` — `onWordLongPressed` calls `pronunciationPlaybackService.playBreakdownFor(word, globalIndex, bookId)`
- `lib/src/features/reader/reader_screen.dart` — pass `bookId` to provider, no UI change
- `lib/src/features/reader/page_renderer.dart` — unchanged callback shape

**Tap behavior unchanged.** Phase-1.

**Acceptance:**
- Long-press on word with `breakdown_url` plays breakdown then full word
- Long-press on word with only `full_word_url` plays full word
- Long-press on word with no manifest entry falls back to `soundOut` TTS
- Highlight clears only if request still latest
- Narration resumes only if active before AND not user-paused mid-flow

### Ticket #14 — pronunciation channel in `AudioEngine`

**Edited file:** `lib/src/audio/audio_engine.dart`

Add third `AudioPlayer _pronunciation` alongside narration + soundscape.

New methods:
```dart
Future<void> playPronunciationSequence(List<String> urls);
Future<void> stopPronunciation();
bool get isPronunciationPlaying;
Stream<bool> get pronunciationPlaying;
```

Internals:
- `_pronunciationRequestId` increments per call
- Cancel-and-replace: each new sequence stops prior + sets new request ID
- Stale completion (request ID mismatch) is no-op
- Pronunciation is independent of `_narrationActive` / `_soundscapeActive` flags

**Edited file:** `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart`
- Use `audioEngine.playPronunciationSequence([breakdownUrl, fullWordUrl])` instead of direct `just_audio` calls

**Acceptance:**
- Two long-presses in quick succession: only second sequence audible
- Page change → `stopPronunciation()` called (wired in #15)
- Narration/soundscape playback not disturbed beyond intended pause

### Ticket #15 — pronunciation state machine (narration/practice/page)

**Edited files:**
- `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart`
- `lib/src/features/reader/runtime/reader_session_impl.dart` — emit page-change signal that pronunciation listens for
- `lib/src/features/reader/runtime/providers/reader_session_provider.dart`

State machine states: `idle → capturing → playing → restoring → idle`.

Transitions:
- `capturing`: snapshot `wasNarrationPlaying`, `wasListening` from `_lastState`
- `playing`: pause narration (if active), pause practice mic (if active), call `audioEngine.playPronunciationSequence`
- User intent override mid-flow:
  - if user toggles narration during playback → mark `userOverride=true`, skip restore
  - if user navigates page → cancel sequence, skip restore, do not auto-resume
- `restoring`: only if request still latest AND no userOverride AND state captured

Page change handling:
- Subscribe to reader page-change events
- On page change: call `audioEngine.stopPronunciation()` + reset state machine to `idle`

**Acceptance:**
- Narration active → long-press → narration pauses → pronunciation plays → narration resumes
- Narration paused → long-press → narration stays paused after
- User pauses narration during pronunciation → no auto-resume
- Page navigation cancels mid-flight pronunciation

### Ticket #16 — manifest preload + cache + offline fallback

**Edited files:**
- `lib/src/data/pronunciation_repository.dart` — add success cache + brief failure cooldown (e.g. 10s) to avoid retry storms
- `lib/src/features/reader/reader_screen.dart` — preload manifest on reader open: `ref.read(bookManifestProvider(bookId).future)` once
- `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart` — handle audio fetch failure → exit transient state, fallback to TTS

**Behavior:**
- Preload fires once per reader-session per book
- Reader remains usable if preload fails
- Audio URL 404/network error → exit highlight state, attempt TTS fallback
- Cache cleared when book changes (new `bookId` family invalidates prior)

**Acceptance:**
- Reader open with supported book → manifest preloaded silently
- Repeated long-press in same session → no refetch
- Offline → manifest fetch fails → long-press falls back to TTS without error

### Ticket #17 — automated tests

**New test files:**
- `test/features/reader/runtime/word_normalizer_test.dart`
  - Capitalization, punctuation, apostrophes, hyphens, unicode, invalid tokens
- `test/features/reader/runtime/pronunciation_lookup_test.dart`
  - Entry found, missing, breakdown+fullWord, fullWord-only, malformed
- `test/features/reader/runtime/pronunciation_playback_service_test.dart`
  - Narration pause/resume, paused-stays-paused, cancel-and-replace, page-change cancel, fallback chain
- `test/audio/audio_engine_pronunciation_test.dart`
  - Sequence play, request ID invalidation, stop independence from narration

Use Riverpod overrides + fake `AudioEngine` / fake repository.

**Acceptance:**
- All new tests pass on CI
- No regressions in existing reader tests

### Ticket #18 — manual QA checklist

**New file:** `specs/mobile-word-pronunciation-qa-checklist.md`

Sections (mirror web spec §1.14.12 adapted to mobile):
- Core interaction (tap unchanged, long-press manifest-backed, fallback)
- Manifest network handling (present, missing, fetch fail, slow)
- Narration coexistence (4 transitions)
- Repeated rapid interactions
- Page navigation during pronunciation
- iOS device path
- Android device path
- Offline mode
- Practice mode interactions

**Acceptance:** tester can run without code-level knowledge; pass/fail tracked.

---

## 5. Cross-cutting decisions

| Decision | Choice | Rationale |
|---|---|---|
| Manifest source | Supabase select on `book_pronunciations` table | Already in DB; no new endpoint needed |
| Manifest fetch trigger | Preload on reader open if any rows exist | Reduce first-interaction latency |
| Concurrency policy | Cancel-and-replace | Matches web phase-1 default |
| Tap behavior | Unchanged (whole-word TTS) | Phase-1 scope |
| Long-press behavior | Manifest-first, TTS fallback | Phase-1 scope |
| Audio channel | Third `AudioPlayer` in `AudioEngine` | Centralizes interrupt logic |
| Cache scope | In-memory, per-session | Phase-1 simplicity; durable cache later |
| Offline behavior | TTS fallback when manifest/audio missing | Reader never breaks |

---

## 6. Risks

1. **Normalization parity** — mobile keys must match what backend writes to `normalized_word`. Confirm rules with web/backend impl before #12 lands.
2. **`AudioPlayer` resource cost** — third player on iOS may stress audio session. Verify on device early.
3. **Page-change race** — pronunciation request started just before page transition may complete on new page. State machine in #15 must guard via request ID.
4. **TTS fallback locale** — current `WordTtsService` resolves locale per-platform. Ensure manifest-backed audio doesn't conflict with existing locale logic.
5. **`book_pronunciations.status`** — confirm which `status` values mobile should consume. Current assumption: `generated` + `reviewed`.

---

## 7. Open questions

1. Should mobile preload manifest on book-list tap or only on reader open?
   - **Recommended:** reader open only.
2. Should we add `hasPronunciations` boolean to `Book` model?
   - **Recommended:** yes — single Supabase `count` query at book load avoids unnecessary preload work.
3. Should breakdown audio be cached to disk for offline replay?
   - **Recommended:** phase-2; rely on platform/HTTP cache for phase-1.

---

## 8. Implementation order (final)

1. #12 normalizer (no behavior change, lowest risk)
2. #11 manifest models + repository
3. #14 AudioEngine pronunciation channel (foundation for #13)
4. #13 long-press manifest-first lookup
5. #15 state machine refinement
6. #16 preload + cache + offline
7. #17 tests
8. #18 manual QA

This order swaps the original suggestion to land #14 before #13 — rationale: cleaner to wire the dedicated audio channel first so #13 can use it directly instead of refactoring twice.
