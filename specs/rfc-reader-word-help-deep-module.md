# RFC: Deepen Reader Word-Help / Pronunciation Playback

## Problem

Reader word-help behavior is one user-facing concept spread across several shallow modules:

- `lib/src/features/reader/runtime/providers/word_tts_provider.dart`
- `lib/src/features/reader/runtime/services/pronunciation_playback_service.dart`
- `lib/src/features/reader/runtime/services/word_tts_service.dart`
- `lib/src/features/reader/runtime/reader_session.dart`
- `lib/src/features/reader/runtime/reader_view_state.dart`
- `lib/src/features/reader/runtime/reader_intent.dart`
- `lib/src/features/reader/runtime/reader_analytics_tracker.dart`
- `lib/src/data/pronunciation_repository.dart`
- `lib/src/data/pronunciation_models.dart`
- `lib/src/audio/audio_engine.dart`
- `lib/src/features/reader/page_renderer.dart`
- `lib/src/features/reader/overlay/*`

A single tap or long-press on an overlay word currently crosses many concerns:

- overlay token interaction
- transient tapped-word highlight state
- pronunciation manifest lookup and caching
- word normalization
- breakdown/full-word audio sequencing
- native TTS fallback
- narration/listening pause and restore
- user override detection while playback is in flight
- page-change cancellation
- pronunciation position tracking for syllable highlights
- analytics recording without raw child speech/audio

This creates integration risk at the seams. Tests currently cover pieces of the behavior, but the most important bugs would appear in how those pieces interact: superseded requests, page changes during playback, plugin failures, fallback behavior, and restore semantics.

The desired refactor is a **deep module** with a small caller-facing interface that hides the orchestration complexity and supports boundary tests.

## Recommended Interface

Adopt a hybrid of:

1. **Ports & adapters engine** for durable testability.
2. **Minimal Riverpod facade** for a small app-facing API.

Do **not** start with a broad generalized `ReaderHelpSession` abstraction or a fully word-help-aware overlay widget. Those can be added later if the product grows beyond pronunciation help or if the UI call sites remain noisy after the core boundary stabilizes.

### Core pure-Dart boundary

```dart
abstract interface class ReaderWordHelp {
  WordHelpSnapshot get snapshot;
  Stream<WordHelpSnapshot> get snapshots;

  Future<WordHelpResult> play(WordHelpRequest request);

  Future<void> cancel({
    required WordHelpCancelReason reason,
  });

  Future<void> dispose();
}
```

```dart
enum WordHelpMode {
  /// Tap: play/speak the whole word help.
  word,

  /// Long-press: play/speak syllable or phoneme-style breakdown help.
  breakdown,
}

class WordHelpRequest {
  const WordHelpRequest({
    required this.bookId,
    required this.pageIndex,
    required this.wordIndex,
    required this.rawWord,
    required this.mode,
  });

  final String bookId;
  final int pageIndex;
  final int wordIndex;
  final String rawWord;
  final WordHelpMode mode;
}
```

```dart
enum WordHelpPhase {
  idle,
  resolvingManifest,
  pausingReaderAudio,
  playingPronunciation,
  playingFallbackTts,
  restoringReaderAudio,
  cancelled,
  failed,
}

class WordHelpSnapshot {
  const WordHelpSnapshot({
    required this.phase,
    this.activeWordIndex,
    this.highlightParts = const [],
    this.activeHighlightPartIndex,
  });

  final WordHelpPhase phase;
  final int? activeWordIndex;
  final List<PronunciationHighlightPart> highlightParts;
  final int? activeHighlightPartIndex;
}
```

```dart
enum WordHelpOutcome {
  pronunciationPlayed,
  fallbackPlayed,
  cancelled,
  failed,
}

class WordHelpResult {
  const WordHelpResult({
    required this.outcome,
    this.error,
  });

  final WordHelpOutcome outcome;
  final Object? error;
}
```

### Engine

```dart
class ReaderWordHelpEngine implements ReaderWordHelp {
  ReaderWordHelpEngine({
    required PronunciationManifestPort manifestPort,
    required PronunciationAudioPort pronunciationAudio,
    required FallbackSpeechPort fallbackSpeech,
    required ReaderAudioGuardPort readerAudioGuard,
    required WordHelpAnalyticsPort analytics,
    required WordNormalizerPort normalizer,
    required SchedulerPort scheduler,
  });

  @override
  WordHelpSnapshot get snapshot;

  @override
  Stream<WordHelpSnapshot> get snapshots;

  @override
  Future<WordHelpResult> play(WordHelpRequest request);

  @override
  Future<void> cancel({required WordHelpCancelReason reason});

  @override
  Future<void> dispose();
}
```

The engine owns the orchestration. Existing classes become adapters; they should no longer co-own the flow.

### Riverpod facade

```dart
final readerWordHelpProvider = AutoDisposeNotifierProviderFamily<
  ReaderWordHelpController,
  WordHelpSnapshot,
  String
>(ReaderWordHelpController.new);

class ReaderWordHelpController
    extends AutoDisposeFamilyNotifier<WordHelpSnapshot, String> {
  late final ReaderWordHelpEngine _engine;

  @override
  WordHelpSnapshot build(String bookId) {
    _engine = ReaderWordHelpEngine(
      manifestPort: PronunciationRepositoryManifestPort(
        ref.watch(pronunciationRepositoryProvider),
      ),
      pronunciationAudio: AudioEnginePronunciationPort(
        ref.watch(audioEngineProvider),
      ),
      fallbackSpeech: FlutterTtsFallbackSpeechPort(
        ref.watch(wordTtsServiceProvider),
      ),
      readerAudioGuard: ReaderSessionAudioGuardPort(
        ref.watch(readerSessionProvider),
      ),
      analytics: ReaderAnalyticsWordHelpPort(
        ref.watch(readerAnalyticsTrackerProvider),
      ),
      normalizer: DefaultWordNormalizerPort(),
      scheduler: FlutterSchedulerPort(),
    );

    final sub = _engine.snapshots.listen((next) => state = next);
    ref.onDispose(() async {
      await sub.cancel();
      await _engine.dispose();
    });

    return _engine.snapshot;
  }

  Future<WordHelpResult> play(WordHelpRequest request) =>
      _engine.play(request);

  Future<void> cancel({
    WordHelpCancelReason reason = WordHelpCancelReason.user,
  }) => _engine.cancel(reason: reason);
}
```

## Usage Example

`ReaderScreen` or `PageRenderer` should only provide the user intent and render the returned snapshot.

```dart
final wordHelpState = ref.watch(readerWordHelpProvider(book.id));
final wordHelp = ref.read(readerWordHelpProvider(book.id).notifier);

OverlayTextLayer(
  frame: _overlayEngine.build(
    overlay: page.overlay!,
    imageSize: imageRect.size,
    activeWordIndex: narrationActiveWordIndex,
    spokenWordIndices: spokenWordIndices,
    isActive: isActive,
    tappedWordIndex: wordHelpState.activeWordIndex,
    tappedWordHighlightParts: wordHelpState.highlightParts,
    activeTappedWordHighlightPartIndex:
        wordHelpState.activeHighlightPartIndex,
  ),
  onWordTap: (word, globalIndex) {
    wordHelp.play(
      WordHelpRequest(
        bookId: book.id,
        pageIndex: pageIndex,
        wordIndex: globalIndex,
        rawWord: word,
        mode: WordHelpMode.word,
      ),
    );
  },
  onWordLongPress: (word, globalIndex) {
    wordHelp.play(
      WordHelpRequest(
        bookId: book.id,
        pageIndex: pageIndex,
        wordIndex: globalIndex,
        rawWord: word,
        mode: WordHelpMode.breakdown,
      ),
    );
  },
);
```

A later ergonomic layer may wrap this into a binding provider or widget:

```dart
final readerWordHelpOverlayBindingProvider =
    Provider<ReaderWordHelpOverlayBinding>((ref) => ...);
```

That should be treated as UI convenience, not the core module boundary.

## Dependency Strategy

**Dependency category:** True external / Mock, implemented with ports and adapters.

### Ports

```dart
abstract interface class PronunciationManifestPort {
  Future<BookPronunciationManifest?> getManifest(String bookId);
}

abstract interface class PronunciationAudioPort {
  Stream<Duration> get position;
  Future<void> playSequence(List<String> urls);
  Future<void> stop();
}

abstract interface class FallbackSpeechPort {
  Future<void> speakWord(String word);
  Future<void> speakBreakdown(String word);
  Future<void> stop();
}

abstract interface class ReaderAudioGuardPort {
  Future<ReaderAudioSnapshot> captureAndPause();
  Future<void> restore(ReaderAudioSnapshot snapshot);
  Stream<int> get pageChanges;
}

abstract interface class WordHelpAnalyticsPort {
  void recordWordHelp({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  });
}

abstract interface class WordNormalizerPort {
  String? normalize(String rawWord);
}
```

### Production adapters

- `PronunciationRepositoryManifestPort` wraps `PronunciationRepository`.
- `AudioEnginePronunciationPort` wraps `AudioEngine.playPronunciationSequence`, `AudioEngine.stopPronunciation`, and `AudioEngine.pronunciationPosition`.
- `FlutterTtsFallbackSpeechPort` wraps `WordTtsService.speak`, `WordTtsService.soundOut`, and `WordTtsService.stop`.
- `ReaderSessionAudioGuardPort` wraps `ReaderSession` state/intent dispatch for capture, pause, restore, and page-change cancellation.
- `ReaderAnalyticsWordHelpPort` wraps `ReaderAnalyticsTracker.recordWordAudioPlayed` and `recordPhonemeAudioPlayed`.
- `DefaultWordNormalizerPort` wraps the current normalization rules.

### Test adapters

Tests should use in-memory/fake ports rather than subclassing production services or touching native plugins.

## What the Module Should Hide

The module should internally own:

- monotonically increasing request IDs / cancellation tokens
- cancel-and-replace semantics for rapid taps
- page-change cancellation
- manifest lookup and fallback decision
- URL sequencing rules for breakdown and full-word clips
- highlight part construction from pronunciation metadata
- active highlight index tracking from pronunciation position stream
- fallback TTS behavior
- narration/listening capture and restore
- user override suppression of restore
- analytics outcome recording
- cleanup on dispose

Callers should not know whether playback came from manifest audio or native TTS except through `WordHelpResult` or coarse debug UI if needed.

## Testing Strategy

Replace shallow tests with boundary tests around `ReaderWordHelp` / `ReaderWordHelpEngine`.

### New boundary tests to write

1. **Manifest whole-word playback**
   - Given a manifest entry with full-word audio.
   - When `play(... mode: WordHelpMode.word)` is called.
   - Then pronunciation audio receives the expected URL sequence and state returns to idle.

2. **Breakdown highlighting**
   - Given syllables and breakdown timing metadata.
   - When playback position advances.
   - Then `snapshot.highlightParts` and `snapshot.activeHighlightPartIndex` update correctly.

3. **Fallback TTS**
   - Given no manifest entry, no usable URLs, or pronunciation playback failure.
   - Then fallback speech is invoked with `speakWord` or `speakBreakdown` depending on mode.

4. **Reader audio guard**
   - Given narration or listening is active.
   - Then the module captures and pauses before playback and restores after playback.

5. **User override**
   - Given the user toggles narration/listening during word-help playback.
   - Then automatic restore is suppressed where appropriate.

6. **Page-change cancellation**
   - Given playback is active.
   - When `pageChanges` emits.
   - Then pronunciation/TTS stops, state clears, and restore behavior is deterministic.

7. **Cancel and replace**
   - Given word A is playing.
   - When word B is requested.
   - Then word A is cancelled, stale completions are ignored, and only word B updates state.

8. **Analytics privacy and resilience**
   - Verify analytics records word index/mode/outcome only.
   - Verify analytics failures do not fail playback.

### Old tests to delete or fold into boundary tests

After equivalent boundary coverage exists, delete or reduce shallow tests that assert implementation details in:

- `test/features/reader/runtime/word_tts_provider_test.dart`
- parts of `test/features/reader/runtime/pronunciation_playback_service_test.dart`
- possibly `test/features/reader/runtime/word_normalizer_test.dart` if normalization becomes internal and fully covered through boundary cases

Keep narrowly scoped model parsing tests if they protect backend compatibility in `pronunciation_models.dart`.

## Migration Plan

1. Introduce `ReaderWordHelpEngine` and ports without removing current `wordTtsProvider`.
2. Add fake ports and boundary tests for the behaviors above.
3. Implement production adapters around existing services.
4. Add `readerWordHelpProvider(bookId)` facade.
5. Migrate `PageRenderer` / `ReaderScreen` from `wordTtsProvider` to `readerWordHelpProvider`.
6. Remove duplicated orchestration from `WordTtsNotifier`, `PronunciationPlaybackService`, and `WordTtsService` as their responsibilities move behind ports.
7. Delete replaced shallow tests once boundary tests cover the same behavior.
8. Optionally add `ReaderWordHelpOverlayBinding` or `ReaderWordHelpOverlayLayer` if UI wiring remains noisy.

## Non-goals

- Do not introduce dictionary, translation, or general tutoring modes yet.
- Do not make overlay widgets the primary architecture boundary.
- Do not expose plugin-specific state through the public interface.
- Do not keep both old and new orchestration paths long-term.

## Recommendation Summary

Choose the **ports & adapters engine + minimal Riverpod facade** hybrid.

This gives the codebase a genuinely deep module: a small public interface hiding large, failure-prone orchestration. It also keeps the app-facing API small enough for incremental migration and makes the risky behavior testable without native audio/TTS/Supabase dependencies.
