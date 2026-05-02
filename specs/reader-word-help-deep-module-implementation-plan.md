# Reader Word-Help Deep Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace reader word-help pronunciation orchestration with a deep `ReaderWordHelpEngine` plus a minimal Riverpod facade, while preserving current tap/long-press behavior.

**Architecture:** Build a pure Dart engine behind explicit ports, then adapt existing production services (`PronunciationRepository`, `AudioEngine`, `WordTtsService`, `ReaderSession`, `ReaderAnalyticsTracker`) to those ports. Migrate UI call sites only after engine boundary tests cover manifest playback, fallback TTS, cancellation, page changes, audio guard restore, highlighting, and analytics.

**Tech Stack:** Flutter, Dart, Riverpod 2.x, `flutter_test`, existing reader runtime services, existing audio/TTS/Supabase adapters.

---

## File Structure

### Create

- `lib/src/features/reader/runtime/word_help/reader_word_help.dart`
  - Public engine interface, request/result/snapshot/value types, and port interfaces.
- `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`
  - Pure Dart orchestration engine.
- `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart`
  - Production adapters around existing app services.
- `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart`
  - Riverpod facade that owns the engine lifecycle.
- `test/features/reader/runtime/reader_word_help_engine_test.dart`
  - Boundary tests using fake ports.

### Modify

- `lib/src/features/reader/page_renderer.dart`
  - Replace `wordTtsProvider` state/callback usage with injected word-help state and callbacks.
- `lib/src/features/reader/reader_screen.dart`
  - Watch `readerWordHelpProvider(book.id)`, dispatch `WordHelpRequest`, remove `wordTtsProvider` attach/book-id calls.
- `lib/src/features/reader/runtime/providers/word_tts_provider.dart`
  - After migration, keep only `wordTtsServiceProvider` if needed by adapters, or move that provider to `reader_word_help_provider.dart`.
- `test/features/reader/runtime/word_tts_provider_test.dart`
  - Delete after equivalent engine tests pass.
- `test/features/reader/runtime/pronunciation_playback_service_test.dart`
  - Keep model parsing groups; remove playback orchestration tests that become engine boundary tests.

---

## Task 1: Public Word-Help Contract and First Boundary Test

**Files:**
- Create: `lib/src/features/reader/runtime/word_help/reader_word_help.dart`
- Create: `test/features/reader/runtime/reader_word_help_engine_test.dart`
- Create: `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`

- [ ] **Step 1: Create the public contract file**

Create `lib/src/features/reader/runtime/word_help/reader_word_help.dart` with:

```dart
import '../../../../data/pronunciation_models.dart';
import '../../pronunciation_highlight.dart';

abstract interface class ReaderWordHelp {
  WordHelpSnapshot get snapshot;
  Stream<WordHelpSnapshot> get snapshots;

  Future<WordHelpResult> play(WordHelpRequest request);

  Future<void> cancel({required WordHelpCancelReason reason});

  Future<void> dispose();
}

enum WordHelpMode {
  word,
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

  const WordHelpSnapshot.idle()
    : phase = WordHelpPhase.idle,
      activeWordIndex = null,
      highlightParts = const [],
      activeHighlightPartIndex = null;

  final WordHelpPhase phase;
  final int? activeWordIndex;
  final List<PronunciationHighlightPart> highlightParts;
  final int? activeHighlightPartIndex;

  WordHelpSnapshot copyWith({
    WordHelpPhase? phase,
    Object? activeWordIndex = _sentinel,
    List<PronunciationHighlightPart>? highlightParts,
    Object? activeHighlightPartIndex = _sentinel,
  }) {
    return WordHelpSnapshot(
      phase: phase ?? this.phase,
      activeWordIndex: activeWordIndex == _sentinel
          ? this.activeWordIndex
          : activeWordIndex as int?,
      highlightParts: highlightParts ?? this.highlightParts,
      activeHighlightPartIndex: activeHighlightPartIndex == _sentinel
          ? this.activeHighlightPartIndex
          : activeHighlightPartIndex as int?,
    );
  }
}

const Object _sentinel = Object();

enum WordHelpOutcome {
  pronunciationPlayed,
  fallbackPlayed,
  cancelled,
  failed,
}

class WordHelpResult {
  const WordHelpResult({required this.outcome, this.error});

  final WordHelpOutcome outcome;
  final Object? error;
}

enum WordHelpCancelReason {
  user,
  pageChanged,
  superseded,
  disposed,
}

class ReaderAudioSnapshot {
  const ReaderAudioSnapshot({
    required this.wasNarrationPlaying,
    required this.wasListening,
  });

  final bool wasNarrationPlaying;
  final bool wasListening;
}

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

abstract interface class WordHelpSchedulerPort {
  void scheduleMicrotask(void Function() callback);
}
```

- [ ] **Step 2: Write the first failing engine test**

Create `test/features/reader/runtime/reader_word_help_engine_test.dart` with this initial test harness and first test:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/data/pronunciation_models.dart';
import 'package:storia_kids/src/features/reader/runtime/word_help/reader_word_help.dart';
import 'package:storia_kids/src/features/reader/runtime/word_help/reader_word_help_engine.dart';

void main() {
  group('ReaderWordHelpEngine', () {
    late _FakeManifestPort manifest;
    late _FakePronunciationAudioPort pronunciationAudio;
    late _FakeFallbackSpeechPort fallbackSpeech;
    late _FakeReaderAudioGuardPort audioGuard;
    late _FakeAnalyticsPort analytics;
    late _FakeNormalizerPort normalizer;
    late ReaderWordHelpEngine engine;

    setUp(() {
      manifest = _FakeManifestPort();
      pronunciationAudio = _FakePronunciationAudioPort();
      fallbackSpeech = _FakeFallbackSpeechPort();
      audioGuard = _FakeReaderAudioGuardPort();
      analytics = _FakeAnalyticsPort();
      normalizer = _FakeNormalizerPort();
      engine = ReaderWordHelpEngine(
        manifestPort: manifest,
        pronunciationAudio: pronunciationAudio,
        fallbackSpeech: fallbackSpeech,
        readerAudioGuard: audioGuard,
        analytics: analytics,
        normalizer: normalizer,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await audioGuard.dispose();
      await pronunciationAudio.dispose();
    });

    test('plays manifest full-word audio for tap requests', () async {
      manifest.manifest = BookPronunciationManifest(
        bookId: 'book-1',
        entries: {
          'hello': const WordPronunciation(
            normalizedWord: 'hello',
            source: 'generated',
            fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
          ),
        },
      );

      final result = await engine.play(
        const WordHelpRequest(
          bookId: 'book-1',
          pageIndex: 0,
          wordIndex: 3,
          rawWord: 'Hello!',
          mode: WordHelpMode.word,
        ),
      );

      expect(result.outcome, WordHelpOutcome.pronunciationPlayed);
      expect(manifest.requestedBookIds, ['book-1']);
      expect(normalizer.normalizedInputs, ['Hello!']);
      expect(pronunciationAudio.playedSequences, [
        ['https://cdn/hello.mp3'],
      ]);
      expect(fallbackSpeech.spokenWords, isEmpty);
      expect(audioGuard.captureCount, 1);
      expect(audioGuard.restoredSnapshots, hasLength(1));
      expect(analytics.events.single.outcome, WordHelpOutcome.pronunciationPlayed);
      expect(engine.snapshot.phase, WordHelpPhase.idle);
      expect(engine.snapshot.activeWordIndex, isNull);
    });
  });
}

class _FakeManifestPort implements PronunciationManifestPort {
  BookPronunciationManifest? manifest;
  final requestedBookIds = <String>[];

  @override
  Future<BookPronunciationManifest?> getManifest(String bookId) async {
    requestedBookIds.add(bookId);
    return manifest;
  }
}

class _FakePronunciationAudioPort implements PronunciationAudioPort {
  final _positionController = StreamController<Duration>.broadcast();
  final playedSequences = <List<String>>[];
  var stopCount = 0;
  Object? playError;

  @override
  Stream<Duration> get position => _positionController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> playSequence(List<String> urls) async {
    final error = playError;
    if (error != null) {
      throw error;
    }
    playedSequences.add(List<String>.of(urls));
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  Future<void> dispose() => _positionController.close();
}

class _FakeFallbackSpeechPort implements FallbackSpeechPort {
  final spokenWords = <String>[];
  final breakdownWords = <String>[];
  var stopCount = 0;

  @override
  Future<void> speakWord(String word) async {
    spokenWords.add(word);
  }

  @override
  Future<void> speakBreakdown(String word) async {
    breakdownWords.add(word);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeReaderAudioGuardPort implements ReaderAudioGuardPort {
  final _pageChanges = StreamController<int>.broadcast();
  final restoredSnapshots = <ReaderAudioSnapshot>[];
  var captureCount = 0;
  ReaderAudioSnapshot snapshot = const ReaderAudioSnapshot(
    wasNarrationPlaying: false,
    wasListening: false,
  );

  @override
  Stream<int> get pageChanges => _pageChanges.stream;

  void emitPageChange(int pageIndex) => _pageChanges.add(pageIndex);

  @override
  Future<ReaderAudioSnapshot> captureAndPause() async {
    captureCount++;
    return snapshot;
  }

  @override
  Future<void> restore(ReaderAudioSnapshot snapshot) async {
    restoredSnapshots.add(snapshot);
  }

  Future<void> dispose() => _pageChanges.close();
}

class _FakeAnalyticsPort implements WordHelpAnalyticsPort {
  final events = <_AnalyticsEvent>[];

  @override
  void recordWordHelp({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  }) {
    events.add(_AnalyticsEvent(wordIndex: wordIndex, mode: mode, outcome: outcome));
  }
}

class _AnalyticsEvent {
  const _AnalyticsEvent({
    required this.wordIndex,
    required this.mode,
    required this.outcome,
  });

  final int wordIndex;
  final WordHelpMode mode;
  final WordHelpOutcome outcome;
}

class _FakeNormalizerPort implements WordNormalizerPort {
  final normalizedInputs = <String>[];

  @override
  String? normalize(String rawWord) {
    normalizedInputs.add(rawWord);
    final normalized = rawWord.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return normalized.isEmpty ? null : normalized;
  }
}
```

- [ ] **Step 3: Run the new test and verify it fails because the engine file is missing**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: FAIL with an import or undefined class error for `reader_word_help_engine.dart` / `ReaderWordHelpEngine`.

- [ ] **Step 4: Add the minimal engine implementation for full-word manifest playback**

Create `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart` with:

```dart
import 'dart:async';

import '../../../../data/pronunciation_models.dart';
import '../internal/word_normalizer.dart';
import 'reader_word_help.dart';

class ReaderWordHelpEngine implements ReaderWordHelp {
  ReaderWordHelpEngine({
    required PronunciationManifestPort manifestPort,
    required PronunciationAudioPort pronunciationAudio,
    required FallbackSpeechPort fallbackSpeech,
    required ReaderAudioGuardPort readerAudioGuard,
    required WordHelpAnalyticsPort analytics,
    WordNormalizerPort? normalizer,
  }) : _manifestPort = manifestPort,
       _pronunciationAudio = pronunciationAudio,
       _fallbackSpeech = fallbackSpeech,
       _readerAudioGuard = readerAudioGuard,
       _analytics = analytics,
       _normalizer = normalizer ?? const DefaultWordNormalizerPort() {
    _pageChangeSubscription = _readerAudioGuard.pageChanges.listen((_) {
      unawaited(cancel(reason: WordHelpCancelReason.pageChanged));
    });
  }

  final PronunciationManifestPort _manifestPort;
  final PronunciationAudioPort _pronunciationAudio;
  final FallbackSpeechPort _fallbackSpeech;
  final ReaderAudioGuardPort _readerAudioGuard;
  final WordHelpAnalyticsPort _analytics;
  final WordNormalizerPort _normalizer;

  final _snapshots = StreamController<WordHelpSnapshot>.broadcast();
  StreamSubscription<int>? _pageChangeSubscription;
  WordHelpSnapshot _snapshot = const WordHelpSnapshot.idle();
  int _requestId = 0;
  bool _disposed = false;

  @override
  WordHelpSnapshot get snapshot => _snapshot;

  @override
  Stream<WordHelpSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _snapshots.stream;
  }

  @override
  Future<WordHelpResult> play(WordHelpRequest request) async {
    final requestId = ++_requestId;
    ReaderAudioSnapshot? captured;
    _emit(
      WordHelpSnapshot(
        phase: WordHelpPhase.resolvingManifest,
        activeWordIndex: request.wordIndex,
      ),
    );

    try {
      final normalized = _normalizer.normalize(request.rawWord);
      if (!_isCurrent(requestId) || normalized == null) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      final manifest = await _manifestPort.getManifest(request.bookId);
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      final urls = _urlsFor(manifest?.lookup(normalized));
      _emit(_snapshot.copyWith(phase: WordHelpPhase.pausingReaderAudio));
      captured = await _readerAudioGuard.captureAndPause();
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      if (urls.isNotEmpty) {
        _emit(_snapshot.copyWith(phase: WordHelpPhase.playingPronunciation));
        await _pronunciationAudio.playSequence(urls);
        if (!_isCurrent(requestId)) {
          return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
        }
        _analytics.recordWordHelp(
          wordIndex: request.wordIndex,
          mode: request.mode,
          outcome: WordHelpOutcome.pronunciationPlayed,
        );
        return const WordHelpResult(outcome: WordHelpOutcome.pronunciationPlayed);
      }

      _emit(_snapshot.copyWith(phase: WordHelpPhase.playingFallbackTts));
      await _playFallback(request);
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }
      _analytics.recordWordHelp(
        wordIndex: request.wordIndex,
        mode: request.mode,
        outcome: WordHelpOutcome.fallbackPlayed,
      );
      return const WordHelpResult(outcome: WordHelpOutcome.fallbackPlayed);
    } catch (error) {
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }
      _emit(_snapshot.copyWith(phase: WordHelpPhase.failed));
      _analytics.recordWordHelp(
        wordIndex: request.wordIndex,
        mode: request.mode,
        outcome: WordHelpOutcome.failed,
      );
      return WordHelpResult(outcome: WordHelpOutcome.failed, error: error);
    } finally {
      if (_isCurrent(requestId)) {
        if (captured != null) {
          _emit(_snapshot.copyWith(phase: WordHelpPhase.restoringReaderAudio));
          await _readerAudioGuard.restore(captured);
        }
        _emit(const WordHelpSnapshot.idle());
      }
    }
  }

  List<String> _urlsFor(WordPronunciation? pronunciation) {
    if (pronunciation == null) {
      return const [];
    }
    final urls = <String>[];
    final breakdownUrl = pronunciation.breakdown?.url;
    final fullWordUrl = pronunciation.fullWord?.url;
    if (breakdownUrl != null && breakdownUrl.isNotEmpty) {
      urls.add(breakdownUrl);
    }
    if (fullWordUrl != null && fullWordUrl.isNotEmpty) {
      urls.add(fullWordUrl);
    }
    return urls;
  }

  Future<void> _playFallback(WordHelpRequest request) {
    return switch (request.mode) {
      WordHelpMode.word => _fallbackSpeech.speakWord(request.rawWord),
      WordHelpMode.breakdown => _fallbackSpeech.speakBreakdown(request.rawWord),
    };
  }

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  void _emit(WordHelpSnapshot next) {
    _snapshot = next;
    if (!_snapshots.isClosed) {
      _snapshots.add(next);
    }
  }

  @override
  Future<void> cancel({required WordHelpCancelReason reason}) async {
    _requestId++;
    await _pronunciationAudio.stop();
    await _fallbackSpeech.stop();
    _emit(
      reason == WordHelpCancelReason.disposed
          ? const WordHelpSnapshot.idle()
          : const WordHelpSnapshot(phase: WordHelpPhase.cancelled),
    );
    if (reason != WordHelpCancelReason.disposed) {
      _emit(const WordHelpSnapshot.idle());
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pageChangeSubscription?.cancel();
    await cancel(reason: WordHelpCancelReason.disposed);
    await _snapshots.close();
  }
}

class DefaultWordNormalizerPort implements WordNormalizerPort {
  const DefaultWordNormalizerPort();

  @override
  String? normalize(String rawWord) => normalizeWordToken(rawWord);
}
```

- [ ] **Step 5: Run the first test and verify it passes**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: PASS for `plays manifest full-word audio for tap requests`.

- [ ] **Step 6: Commit Task 1**

```bash
git add lib/src/features/reader/runtime/word_help/reader_word_help.dart \
  lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart \
  test/features/reader/runtime/reader_word_help_engine_test.dart
git commit -m "feat: add reader word help engine boundary"
```

---

## Task 2: Breakdown Highlighting and Position Tracking

**Files:**
- Modify: `test/features/reader/runtime/reader_word_help_engine_test.dart`
- Modify: `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`

- [ ] **Step 1: Add failing tests for breakdown highlight state**

Append inside the existing `group('ReaderWordHelpEngine', ...)`:

```dart
test('emits syllable highlight parts and advances active part from audio position', () async {
  final playbackCompleter = Completer<void>();
  pronunciationAudio.playCompleter = playbackCompleter;
  manifest.manifest = BookPronunciationManifest(
    bookId: 'book-1',
    entries: {
      'butterfly': const WordPronunciation(
        normalizedWord: 'butterfly',
        source: 'generated',
        syllables: ['but', 'ter', 'fly'],
        breakdownSegments: [
          PronunciationBreakdownSegment(index: 0, chunk: 'but', spoken: 'but', startMs: 0, endMs: 250),
          PronunciationBreakdownSegment(index: 1, chunk: 'ter', spoken: 'tur', startMs: 251, endMs: 520),
          PronunciationBreakdownSegment(index: 2, chunk: 'fly', spoken: 'fly', startMs: 521, endMs: 760),
        ],
        breakdown: PronunciationAudioAsset(url: 'https://cdn/butterfly-breakdown.mp3'),
        fullWord: PronunciationAudioAsset(url: 'https://cdn/butterfly-full.mp3'),
      ),
    },
  );

  final future = engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 12,
      rawWord: 'Butterfly!',
      mode: WordHelpMode.breakdown,
    ),
  );
  await pumpEventQueue();

  expect(engine.snapshot.phase, WordHelpPhase.playingPronunciation);
  expect(engine.snapshot.activeWordIndex, 12);
  expect(engine.snapshot.highlightParts.map((part) => part.text), ['but', 'ter', 'fly']);
  expect(engine.snapshot.activeHighlightPartIndex, 0);

  pronunciationAudio.emitPosition(const Duration(milliseconds: 300));
  await pumpEventQueue();
  expect(engine.snapshot.activeHighlightPartIndex, 1);

  pronunciationAudio.emitPosition(const Duration(milliseconds: 700));
  await pumpEventQueue();
  expect(engine.snapshot.activeHighlightPartIndex, 2);

  pronunciationAudio.emitPosition(const Duration(milliseconds: 10));
  await pumpEventQueue();
  expect(engine.snapshot.highlightParts, isEmpty);
  expect(engine.snapshot.activeHighlightPartIndex, isNull);
  expect(engine.snapshot.activeWordIndex, 12);

  playbackCompleter.complete();
  final result = await future;
  expect(result.outcome, WordHelpOutcome.pronunciationPlayed);
  expect(engine.snapshot.phase, WordHelpPhase.idle);
});
```

Update `_FakePronunciationAudioPort` in the test file by adding a completer field and awaiting it:

```dart
Completer<void>? playCompleter;

@override
Future<void> playSequence(List<String> urls) async {
  final error = playError;
  if (error != null) {
    throw error;
  }
  playedSequences.add(List<String>.of(urls));
  final completer = playCompleter;
  if (completer != null) {
    await completer.future;
  }
}
```

- [ ] **Step 2: Run the test and verify it fails on missing highlight behavior**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: FAIL because `highlightParts` is empty or `activeHighlightPartIndex` does not advance.

- [ ] **Step 3: Add highlight construction and audio position subscription**

Modify `reader_word_help_engine.dart`:

1. Add imports and constants near the top:

```dart
import '../../pronunciation_highlight.dart';

const int _fallbackPartDurationMs = 650;
const int _timedHighlightGraceMs = 350;
const int _minPartDurationMs = 100;
```

2. Add fields:

```dart
StreamSubscription<Duration>? _positionSubscription;
int _lastPronunciationPositionMs = 0;
bool _breakdownFinished = false;
```

3. Before pronunciation playback, after URL resolution and before `playSequence`, call:

```dart
final pronunciation = manifest?.lookup(normalized);
final urls = _urlsFor(pronunciation);
...
if (urls.isNotEmpty) {
  _emit(_snapshot.copyWith(phase: WordHelpPhase.playingPronunciation));
  _startHighlightTracking(request.wordIndex, pronunciation);
  await _pronunciationAudio.playSequence(urls);
```

4. Add methods to the class:

```dart
void _startHighlightTracking(int wordIndex, WordPronunciation? pronunciation) {
  final parts = _buildHighlightParts(pronunciation);
  if (parts.isEmpty) {
    _emit(_snapshot.copyWith(activeWordIndex: wordIndex));
    return;
  }

  _lastPronunciationPositionMs = 0;
  _breakdownFinished = false;
  _emit(
    _snapshot.copyWith(
      activeWordIndex: wordIndex,
      highlightParts: parts,
      activeHighlightPartIndex: 0,
    ),
  );

  _positionSubscription?.cancel();
  _positionSubscription = _pronunciationAudio.position.listen((position) {
    if (_snapshot.activeWordIndex != wordIndex ||
        _snapshot.highlightParts.isEmpty ||
        _breakdownFinished) {
      return;
    }

    final positionMs = position.inMilliseconds;
    final resetToNextClip = positionMs + 100 < _lastPronunciationPositionMs;
    _lastPronunciationPositionMs = positionMs;

    if (resetToNextClip) {
      _breakdownFinished = true;
      _emit(
        _snapshot.copyWith(
          highlightParts: const [],
          activeHighlightPartIndex: null,
        ),
      );
      return;
    }

    final activeIndex = _activeHighlightPartIndexFor(
      positionMs,
      _snapshot.highlightParts,
    );
    if (_snapshot.activeHighlightPartIndex != activeIndex) {
      _emit(_snapshot.copyWith(activeHighlightPartIndex: activeIndex));
    }
  });
}

List<PronunciationHighlightPart> _buildHighlightParts(
  WordPronunciation? pronunciation,
) {
  if (pronunciation == null || pronunciation.breakdown == null) {
    return const [];
  }

  final labels = pronunciation.syllables
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  final fallbackLabels = pronunciation.breakdownSegments
      .map((segment) => segment.chunk.trim().isNotEmpty
          ? segment.chunk.trim()
          : segment.spoken.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  final effectiveLabels = labels.isNotEmpty ? labels : fallbackLabels;
  if (effectiveLabels.isEmpty) {
    return const [];
  }

  final timedSegments = pronunciation.breakdownSegments;
  final totalDurationMs = pronunciation.breakdown?.durationMs ??
      _inferTotalDurationFromSegments(timedSegments) ??
      effectiveLabels.length * _fallbackPartDurationMs;

  return [
    for (var i = 0; i < effectiveLabels.length; i++)
      PronunciationHighlightPart(
        text: effectiveLabels[i],
        startMs: _startMsForPart(i, effectiveLabels.length, timedSegments, totalDurationMs),
        endMs: _endMsForPart(i, effectiveLabels.length, timedSegments, totalDurationMs),
      ),
  ];
}

int? _inferTotalDurationFromSegments(List<PronunciationBreakdownSegment> segments) {
  final ends = segments.map((s) => s.endMs).whereType<int>().toList(growable: false);
  if (ends.isEmpty) {
    return null;
  }
  return ends.reduce((a, b) => a > b ? a : b);
}

int _startMsForPart(
  int index,
  int partCount,
  List<PronunciationBreakdownSegment> segments,
  int totalDurationMs,
) {
  if (segments.length == partCount && segments[index].startMs != null) {
    return segments[index].startMs!;
  }
  return ((totalDurationMs * index) / partCount).round();
}

int _endMsForPart(
  int index,
  int partCount,
  List<PronunciationBreakdownSegment> segments,
  int totalDurationMs,
) {
  if (segments.length == partCount && segments[index].endMs != null) {
    final start = _startMsForPart(index, partCount, segments, totalDurationMs);
    final end = segments[index].endMs!;
    return end > start ? end : start + _minPartDurationMs;
  }
  return ((totalDurationMs * (index + 1)) / partCount).round();
}

int? _activeHighlightPartIndexFor(
  int positionMs,
  List<PronunciationHighlightPart> parts,
) {
  final timedEnds = parts.map((part) => part.endMs).whereType<int>().toList(growable: false);
  if (timedEnds.isNotEmpty) {
    final lastEnd = timedEnds.reduce((a, b) => a > b ? a : b);
    if (positionMs > lastEnd + _timedHighlightGraceMs) {
      return null;
    }
  }

  var latestStarted = 0;
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    final start = part.startMs;
    final end = part.endMs;
    if (start == null || end == null) {
      continue;
    }
    if (positionMs >= start && positionMs <= end) {
      return i;
    }
    if (positionMs >= start) {
      latestStarted = i;
    }
    if (positionMs < start) {
      return latestStarted;
    }
  }
  return latestStarted;
}

void _stopHighlightTracking() {
  _positionSubscription?.cancel();
  _positionSubscription = null;
  _lastPronunciationPositionMs = 0;
  _breakdownFinished = false;
}
```

5. Call `_stopHighlightTracking()` in `cancel`, before idle emit in successful `finally`, and in `dispose` before closing `_snapshots`.

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: PASS for both engine tests.

- [ ] **Step 5: Commit Task 2**

```bash
git add lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart \
  test/features/reader/runtime/reader_word_help_engine_test.dart
git commit -m "feat: track reader word help highlights"
```

---

## Task 3: Fallback, Cancellation, Page Changes, and Analytics Resilience

**Files:**
- Modify: `test/features/reader/runtime/reader_word_help_engine_test.dart`
- Modify: `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`

- [ ] **Step 1: Add failing tests for fallback paths**

Append tests inside the existing group:

```dart
test('falls back to speakWord when manifest entry is missing for tap', () async {
  manifest.manifest = const BookPronunciationManifest(bookId: 'book-1', entries: {});

  final result = await engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 4,
      rawWord: 'Unknown',
      mode: WordHelpMode.word,
    ),
  );

  expect(result.outcome, WordHelpOutcome.fallbackPlayed);
  expect(pronunciationAudio.playedSequences, isEmpty);
  expect(fallbackSpeech.spokenWords, ['Unknown']);
  expect(fallbackSpeech.breakdownWords, isEmpty);
  expect(analytics.events.single.outcome, WordHelpOutcome.fallbackPlayed);
});

test('falls back to speakBreakdown when pronunciation playback throws for long press', () async {
  manifest.manifest = BookPronunciationManifest(
    bookId: 'book-1',
    entries: {
      'hello': const WordPronunciation(
        normalizedWord: 'hello',
        source: 'generated',
        fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
      ),
    },
  );
  pronunciationAudio.playError = StateError('audio failed');

  final result = await engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 5,
      rawWord: 'Hello',
      mode: WordHelpMode.breakdown,
    ),
  );

  expect(result.outcome, WordHelpOutcome.fallbackPlayed);
  expect(fallbackSpeech.breakdownWords, ['Hello']);
  expect(analytics.events.single.outcome, WordHelpOutcome.fallbackPlayed);
});
```

- [ ] **Step 2: Add failing tests for cancellation and page changes**

Append:

```dart
test('cancel stops pronunciation and fallback speech and clears state', () async {
  final playbackCompleter = Completer<void>();
  pronunciationAudio.playCompleter = playbackCompleter;
  manifest.manifest = BookPronunciationManifest(
    bookId: 'book-1',
    entries: {
      'hello': const WordPronunciation(
        normalizedWord: 'hello',
        source: 'generated',
        fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
      ),
    },
  );

  final future = engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 6,
      rawWord: 'Hello',
      mode: WordHelpMode.word,
    ),
  );
  await pumpEventQueue();

  await engine.cancel(reason: WordHelpCancelReason.user);
  playbackCompleter.complete();
  final result = await future;

  expect(result.outcome, WordHelpOutcome.cancelled);
  expect(pronunciationAudio.stopCount, greaterThanOrEqualTo(1));
  expect(fallbackSpeech.stopCount, greaterThanOrEqualTo(1));
  expect(engine.snapshot.phase, WordHelpPhase.idle);
});

test('page change cancels active playback', () async {
  final playbackCompleter = Completer<void>();
  pronunciationAudio.playCompleter = playbackCompleter;
  manifest.manifest = BookPronunciationManifest(
    bookId: 'book-1',
    entries: {
      'hello': const WordPronunciation(
        normalizedWord: 'hello',
        source: 'generated',
        fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
      ),
    },
  );

  final future = engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 7,
      rawWord: 'Hello',
      mode: WordHelpMode.word,
    ),
  );
  await pumpEventQueue();

  audioGuard.emitPageChange(1);
  await pumpEventQueue();
  playbackCompleter.complete();
  final result = await future;

  expect(result.outcome, WordHelpOutcome.cancelled);
  expect(pronunciationAudio.stopCount, greaterThanOrEqualTo(1));
  expect(engine.snapshot.phase, WordHelpPhase.idle);
});

test('analytics failures do not fail playback', () async {
  manifest.manifest = BookPronunciationManifest(
    bookId: 'book-1',
    entries: {
      'hello': const WordPronunciation(
        normalizedWord: 'hello',
        source: 'generated',
        fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
      ),
    },
  );
  analytics.error = StateError('analytics failed');

  final result = await engine.play(
    const WordHelpRequest(
      bookId: 'book-1',
      pageIndex: 0,
      wordIndex: 8,
      rawWord: 'Hello',
      mode: WordHelpMode.word,
    ),
  );

  expect(result.outcome, WordHelpOutcome.pronunciationPlayed);
  expect(pronunciationAudio.playedSequences, [
    ['https://cdn/hello.mp3'],
  ]);
});
```

Modify `_FakeAnalyticsPort`:

```dart
Object? error;

@override
void recordWordHelp({
  required int wordIndex,
  required WordHelpMode mode,
  required WordHelpOutcome outcome,
}) {
  final error = this.error;
  if (error != null) {
    throw error;
  }
  events.add(_AnalyticsEvent(wordIndex: wordIndex, mode: mode, outcome: outcome));
}
```

- [ ] **Step 3: Run tests and verify the new cases fail**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: FAIL on playback-error fallback, cancellation result/state, page-change cancellation, or analytics exception behavior.

- [ ] **Step 4: Implement fallback-on-audio-error and safe analytics recording**

Modify `ReaderWordHelpEngine.play` so the pronunciation branch catches audio errors and falls back:

```dart
if (urls.isNotEmpty) {
  _emit(_snapshot.copyWith(phase: WordHelpPhase.playingPronunciation));
  _startHighlightTracking(request.wordIndex, pronunciation);
  try {
    await _pronunciationAudio.playSequence(urls);
    if (!_isCurrent(requestId)) {
      return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
    }
    _recordAnalytics(
      wordIndex: request.wordIndex,
      mode: request.mode,
      outcome: WordHelpOutcome.pronunciationPlayed,
    );
    return const WordHelpResult(outcome: WordHelpOutcome.pronunciationPlayed);
  } catch (_) {
    if (!_isCurrent(requestId)) {
      return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
    }
    await _pronunciationAudio.stop();
    _stopHighlightTracking();
  }
}

_emit(_snapshot.copyWith(phase: WordHelpPhase.playingFallbackTts));
await _playFallback(request);
if (!_isCurrent(requestId)) {
  return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
}
_recordAnalytics(
  wordIndex: request.wordIndex,
  mode: request.mode,
  outcome: WordHelpOutcome.fallbackPlayed,
);
return const WordHelpResult(outcome: WordHelpOutcome.fallbackPlayed);
```

Add helper:

```dart
void _recordAnalytics({
  required int wordIndex,
  required WordHelpMode mode,
  required WordHelpOutcome outcome,
}) {
  try {
    _analytics.recordWordHelp(
      wordIndex: wordIndex,
      mode: mode,
      outcome: outcome,
    );
  } catch (_) {}
}
```

Replace direct `_analytics.recordWordHelp(...)` calls with `_recordAnalytics(...)`.

- [ ] **Step 5: Make cancellation deterministic**

Modify `cancel`:

```dart
@override
Future<void> cancel({required WordHelpCancelReason reason}) async {
  _requestId++;
  _stopHighlightTracking();
  await _pronunciationAudio.stop();
  await _fallbackSpeech.stop();
  if (reason == WordHelpCancelReason.disposed) {
    _emit(const WordHelpSnapshot.idle());
    return;
  }
  _emit(const WordHelpSnapshot(phase: WordHelpPhase.cancelled));
  _emit(const WordHelpSnapshot.idle());
}
```

- [ ] **Step 6: Run tests and verify they pass**

Run:

```bash
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
```

Expected: PASS for all engine tests.

- [ ] **Step 7: Commit Task 3**

```bash
git add lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart \
  test/features/reader/runtime/reader_word_help_engine_test.dart
git commit -m "test: cover reader word help fallback and cancellation"
```

---

## Task 4: Production Adapters and Riverpod Facade

**Files:**
- Create: `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart`
- Create: `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart`
- Modify: `lib/src/features/reader/runtime/providers/word_tts_provider.dart`

- [ ] **Step 1: Create production adapters**

Create `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart`:

```dart
import 'dart:async';

import '../../../../audio/audio_engine.dart';
import '../../../../data/pronunciation_models.dart';
import '../../../../data/pronunciation_repository.dart';
import '../reader_analytics_tracker.dart';
import '../reader_intent.dart';
import '../reader_session.dart';
import '../reader_view_state.dart';
import '../services/word_tts_service.dart';
import 'reader_word_help.dart';

class PronunciationRepositoryManifestPort implements PronunciationManifestPort {
  const PronunciationRepositoryManifestPort(this._repository);

  final PronunciationRepository _repository;

  @override
  Future<BookPronunciationManifest?> getManifest(String bookId) =>
      _repository.getManifestForBook(bookId);
}

class AudioEnginePronunciationPort implements PronunciationAudioPort {
  const AudioEnginePronunciationPort(this._engine);

  final AudioEngine _engine;

  @override
  Stream<Duration> get position => _engine.pronunciationPosition;

  @override
  Future<void> playSequence(List<String> urls) =>
      _engine.playPronunciationSequence(urls);

  @override
  Future<void> stop() => _engine.stopPronunciation();
}

class FlutterTtsFallbackSpeechPort implements FallbackSpeechPort {
  const FlutterTtsFallbackSpeechPort(this._service);

  final WordTtsService _service;

  @override
  Future<void> speakWord(String word) => _service.speak(word);

  @override
  Future<void> speakBreakdown(String word) => _service.soundOut(word);

  @override
  Future<void> stop() => _service.stop();
}

class ReaderSessionAudioGuardPort implements ReaderAudioGuardPort {
  ReaderSessionAudioGuardPort(this._session) {
    _stateSubscription = _session.states.listen((state) {
      _lastState = state;
    });
  }

  final ReaderSession _session;
  ReaderViewState _lastState = const ReaderViewState.initial();
  StreamSubscription<ReaderViewState>? _stateSubscription;

  @override
  Stream<int> get pageChanges => _session.pageChanges;

  @override
  Future<ReaderAudioSnapshot> captureAndPause() async {
    final snapshot = ReaderAudioSnapshot(
      wasNarrationPlaying: _lastState.isNarrationPlaying,
      wasListening: _lastState.isListening,
    );
    if (snapshot.wasNarrationPlaying) {
      await _session.dispatch(
        const ReaderToggleNarration(source: ReaderIntentSource.runtime),
      );
    }
    if (snapshot.wasListening) {
      await _session.dispatch(const ReaderPauseListening());
    }
    return snapshot;
  }

  @override
  Future<void> restore(ReaderAudioSnapshot snapshot) async {
    if (snapshot.wasNarrationPlaying && !_lastState.isNarrationPlaying) {
      await _session.dispatch(
        const ReaderToggleNarration(source: ReaderIntentSource.runtime),
      );
    }
    if (snapshot.wasListening && !_lastState.isListening) {
      await _session.dispatch(const ReaderResumeListening());
    }
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
  }
}

class ReaderAnalyticsWordHelpPort implements WordHelpAnalyticsPort {
  const ReaderAnalyticsWordHelpPort(this._tracker);

  final ReaderAnalyticsTracker _tracker;

  @override
  void recordWordHelp({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  }) {
    final outcomeName = switch (outcome) {
      WordHelpOutcome.pronunciationPlayed => 'played',
      WordHelpOutcome.fallbackPlayed => 'fallback',
      WordHelpOutcome.cancelled => 'cancelled',
      WordHelpOutcome.failed => 'error',
    };
    switch (mode) {
      WordHelpMode.word => _tracker.recordWordAudioPlayed(
          wordIndex: wordIndex,
          outcome: outcomeName,
        ),
      WordHelpMode.breakdown => _tracker.recordPhonemeAudioPlayed(
          wordIndex: wordIndex,
          outcome: outcomeName,
        ),
    };
  }
}
```

- [ ] **Step 2: Add the Riverpod facade**

Create `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/providers.dart';
import '../services/word_tts_service.dart';
import '../word_help/reader_word_help.dart';
import '../word_help/reader_word_help_adapters.dart';
import '../word_help/reader_word_help_engine.dart';
import 'reader_session_provider.dart';

final wordTtsServiceProvider = Provider<WordTtsService>((ref) {
  final service = WordTtsService();
  ref.onDispose(service.dispose);
  return service;
});

final readerWordHelpProvider = AutoDisposeNotifierProviderFamily<
  ReaderWordHelpController,
  WordHelpSnapshot,
  String
>(ReaderWordHelpController.new);

class ReaderWordHelpController
    extends AutoDisposeFamilyNotifier<WordHelpSnapshot, String> {
  late final ReaderWordHelpEngine _engine;
  StreamSubscription<WordHelpSnapshot>? _snapshotSubscription;
  ReaderSessionAudioGuardPort? _audioGuardPort;

  @override
  WordHelpSnapshot build(String bookId) {
    final audioEngine = ref.watch(audioEngineProvider);
    final session = ref.watch(readerSessionProvider);
    final audioGuard = ReaderSessionAudioGuardPort(session);
    _audioGuardPort = audioGuard;

    _engine = ReaderWordHelpEngine(
      manifestPort: PronunciationRepositoryManifestPort(
        ref.watch(pronunciationRepositoryProvider),
      ),
      pronunciationAudio: AudioEnginePronunciationPort(audioEngine),
      fallbackSpeech: FlutterTtsFallbackSpeechPort(
        ref.watch(wordTtsServiceProvider),
      ),
      readerAudioGuard: audioGuard,
      analytics: ReaderAnalyticsWordHelpPort(
        ref.watch(readerAnalyticsTrackerProvider),
      ),
    );

    _snapshotSubscription = _engine.snapshots.listen((snapshot) {
      state = snapshot;
    });

    ref.onDispose(() async {
      await _snapshotSubscription?.cancel();
      await _engine.dispose();
      await _audioGuardPort?.dispose();
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

- [ ] **Step 3: Remove duplicate `wordTtsServiceProvider` from old provider file**

Modify `lib/src/features/reader/runtime/providers/word_tts_provider.dart`:

1. Remove the local provider declaration:

```dart
final wordTtsServiceProvider = Provider<WordTtsService>((ref) {
  final service = WordTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});
```

2. Add import:

```dart
import 'reader_word_help_provider.dart';
```

This keeps old `wordTtsProvider` compiling until UI migration is complete while the service provider moves to the new facade file.

- [ ] **Step 4: Run analyzer and targeted tests**

Run:

```bash
flutter analyze
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
flutter test test/features/reader/runtime/word_tts_provider_test.dart
```

Expected: analyzer exits 0; both test files pass.

- [ ] **Step 5: Commit Task 4**

```bash
git add lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart \
  lib/src/features/reader/runtime/providers/reader_word_help_provider.dart \
  lib/src/features/reader/runtime/providers/word_tts_provider.dart
git commit -m "feat: wire reader word help provider"
```

---

## Task 5: Migrate Reader UI to the New Facade

**Files:**
- Modify: `lib/src/features/reader/page_renderer.dart`
- Modify: `lib/src/features/reader/reader_screen.dart`
- Modify: `lib/src/features/reader/runtime/providers/word_tts_provider.dart`

- [ ] **Step 1: Modify `PageRenderer` to receive word-help state and callbacks**

In `lib/src/features/reader/page_renderer.dart`:

1. Remove imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'runtime/providers/word_tts_provider.dart';
```

2. Add imports:

```dart
import 'pronunciation_highlight.dart';
```

3. Change class declaration:

```dart
class PageRenderer extends StatefulWidget {
```

4. Change state declaration:

```dart
class _PageRendererState extends State<PageRenderer> {
```

5. Add constructor fields:

```dart
final int? tappedWordIndex;
final List<PronunciationHighlightPart> tappedWordHighlightParts;
final int? activeTappedWordHighlightPartIndex;
```

6. Add constructor parameters with defaults:

```dart
this.tappedWordIndex,
this.tappedWordHighlightParts = const [],
this.activeTappedWordHighlightPartIndex,
```

7. Remove this line from `_buildStandardPage`:

```dart
final wordTtsState = ref.watch(wordTtsProvider);
```

8. Replace `tappedWordIndex`, `highlightParts`, and `activeHighlightPartIndex` usage in `_overlayEngine.build`:

```dart
tappedWordIndex: widget.tappedWordIndex,
tappedWordHighlightParts: widget.tappedWordHighlightParts,
activeTappedWordHighlightPartIndex:
    widget.activeTappedWordHighlightPartIndex,
```

- [ ] **Step 2: Run analyzer and verify expected failures are only from reader call sites**

Run:

```bash
flutter analyze
```

Expected: FAIL because `ReaderScreen` has not yet supplied the new constructor arguments or imports may still reference removed provider usage.

- [ ] **Step 3: Modify `ReaderScreen` imports and initialization**

In `lib/src/features/reader/reader_screen.dart`:

1. Replace import:

```dart
import 'runtime/providers/word_tts_provider.dart';
```

with:

```dart
import 'runtime/providers/reader_word_help_provider.dart';
import 'runtime/word_help/reader_word_help.dart';
```

2. Remove this post-frame callback from `initState`:

```dart
// Attach state stream to word TTS notifier for narration/mic coordination
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(wordTtsProvider.notifier).attachStateStream(_session.states);
});
```

3. Remove this line inside book initialization:

```dart
ref.read(wordTtsProvider.notifier).setBookId(book.id);
```

- [ ] **Step 4: Pass word-help state and callbacks into `PageRenderer`**

Inside `ReaderScreen.build`, after `final activePage = book.pages[activeIndex];`, add:

```dart
final wordHelpState = ref.watch(readerWordHelpProvider(book.id));
final wordHelp = ref.read(readerWordHelpProvider(book.id).notifier);
```

Replace the `PageRenderer` construction with:

```dart
return PageRenderer(
  page: page,
  pageIndex: index,
  scrollOffsetListenable: _scrollOffsetNotifier,
  narrationPosition: narrationPosition,
  isActive: index == activeIndex,
  spokenWordIndices: _runtimeState.spokenWordIndices,
  tappedWordIndex: wordHelpState.activeWordIndex,
  tappedWordHighlightParts: wordHelpState.highlightParts,
  activeTappedWordHighlightPartIndex:
      wordHelpState.activeHighlightPartIndex,
  onWordTap: (word, globalIndex) {
    unawaited(
      wordHelp.play(
        WordHelpRequest(
          bookId: book.id,
          pageIndex: index,
          wordIndex: globalIndex,
          rawWord: word,
          mode: WordHelpMode.word,
        ),
      ),
    );
  },
  onWordLongPress: (word, globalIndex) {
    unawaited(
      wordHelp.play(
        WordHelpRequest(
          bookId: book.id,
          pageIndex: index,
          wordIndex: globalIndex,
          rawWord: word,
          mode: WordHelpMode.breakdown,
        ),
      ),
    );
  },
);
```

- [ ] **Step 5: Run analyzer and reader tests**

Run:

```bash
flutter analyze
flutter test test/features/reader/runtime/reader_word_help_engine_test.dart
flutter test test/features/reader/runtime/word_tts_provider_test.dart
flutter test test/features/reader/overlay/overlay_pronunciation_highlight_test.dart
```

Expected: analyzer exits 0; tests pass.

- [ ] **Step 6: Remove old `WordTtsNotifier` provider if no longer referenced**

Run:

```bash
rg "wordTtsProvider|WordTtsNotifier|WordTtsState|pronunciationPlaybackServiceProvider" lib test
```

Expected before removal: references in `word_tts_provider.dart` and its old test only.

If the search confirms no production references except the service provider import, replace `lib/src/features/reader/runtime/providers/word_tts_provider.dart` with:

```dart
export 'reader_word_help_provider.dart' show wordTtsServiceProvider;
```

Then delete `test/features/reader/runtime/word_tts_provider_test.dart`:

```bash
rm test/features/reader/runtime/word_tts_provider_test.dart
```

- [ ] **Step 7: Run analyzer and all reader runtime tests**

Run:

```bash
flutter analyze
flutter test test/features/reader/runtime
flutter test test/features/reader/overlay
```

Expected: analyzer exits 0; reader runtime and overlay tests pass.

- [ ] **Step 8: Commit Task 5**

```bash
git add lib/src/features/reader/page_renderer.dart \
  lib/src/features/reader/reader_screen.dart \
  lib/src/features/reader/runtime/providers/word_tts_provider.dart \
  lib/src/features/reader/runtime/providers/reader_word_help_provider.dart \
  test/features/reader/runtime/word_tts_provider_test.dart
git commit -m "refactor: migrate reader word help to deep module"
```

---

## Task 6: Consolidate Pronunciation Playback Tests and Final Verification

**Files:**
- Modify: `test/features/reader/runtime/pronunciation_playback_service_test.dart`
- Modify: `specs/rfc-reader-word-help-deep-module.md` if implementation decisions changed materially

- [ ] **Step 1: Trim replaced orchestration tests from pronunciation playback service tests**

In `test/features/reader/runtime/pronunciation_playback_service_test.dart`, keep the groups:

- `WordPronunciation.fromRow`
- `BookPronunciationManifest.lookup`

Remove the `PronunciationPlaybackService` group if the service is no longer used by production code after migration.

If `PronunciationPlaybackService` remains in production, keep only tests that verify its direct contract and do not duplicate engine boundary coverage.

- [ ] **Step 2: Search for removed orchestration types**

Run:

```bash
rg "PronunciationPlaybackService|WordTtsNotifier|WordTtsState|attachStateStream|setBookId" lib test
```

Expected: no production references to removed orchestration types. `WordTtsService` may remain because it is the fallback speech adapter dependency.

- [ ] **Step 3: Run targeted verification**

Run:

```bash
flutter analyze
flutter test test/features/reader/runtime
flutter test test/features/reader/overlay
flutter test test/data/analytics_repository_test.dart
```

Expected: analyzer exits 0; all listed test suites pass.

- [ ] **Step 4: Run full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit Task 6**

```bash
git add test/features/reader/runtime/pronunciation_playback_service_test.dart \
  specs/rfc-reader-word-help-deep-module.md
git commit -m "test: consolidate word help boundary coverage"
```

---

## Self-Review Checklist

### Spec coverage

- Deep module boundary: Tasks 1 and 4.
- Ports/adapters dependency strategy: Task 4.
- Manifest-first playback: Task 1.
- Breakdown highlighting: Task 2.
- Fallback TTS: Task 3.
- Cancellation/page change: Task 3.
- Analytics resilience/privacy outcome: Task 3 and existing analytics tests in Task 6.
- UI migration: Task 5.
- Old shallow test deletion/consolidation: Tasks 5 and 6.

### Placeholder scan

This plan avoids open-ended implementation placeholders. Each task names concrete files, test commands, expected outcomes, and the code shape to add or modify.

### Type consistency

The public names used throughout are:

- `ReaderWordHelp`
- `ReaderWordHelpEngine`
- `WordHelpRequest`
- `WordHelpMode`
- `WordHelpSnapshot`
- `WordHelpPhase`
- `WordHelpOutcome`
- `WordHelpResult`
- `ReaderWordHelpController`
- `readerWordHelpProvider`

These names match across tasks.

---

## Execution Handoff

This plan is ready for a squad implementation with parallelism after Task 1 establishes the shared contract. Recommended squad shape:

1. **Engine/test agent**: Tasks 1–3.
2. **Adapter/provider agent**: Task 4 after Task 1.
3. **UI migration agent**: Task 5 after Tasks 3–4.
4. **QA consolidation agent**: Task 6 after Task 5.
