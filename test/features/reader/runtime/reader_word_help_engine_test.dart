import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/pronunciation_player.dart';
import 'package:loratone/src/data/pronunciation_models.dart';
import 'package:loratone/src/features/reader/runtime/word_help/reader_word_help.dart';
import 'package:loratone/src/features/reader/runtime/word_help/reader_word_help_engine.dart';

void main() {
  group('ReaderWordHelpEngine', () {
    late _FakeManifestPort manifest;
    late _FakePronunciationPlayer pronunciationAudio;
    late _FakeFallbackSpeechPort fallbackSpeech;
    late _FakeReaderAudioGuardPort audioGuard;
    late _FakeAnalyticsPort analytics;
    late _FakeNormalizerPort normalizer;
    late ReaderWordHelpEngine engine;

    setUp(() {
      manifest = _FakeManifestPort();
      pronunciationAudio = _FakePronunciationPlayer();
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
      expect(
        analytics.events.single.outcome,
        WordHelpOutcome.pronunciationPlayed,
      );
      expect(engine.snapshot.phase, WordHelpPhase.idle);
      expect(engine.snapshot.activeWordIndex, isNull);
    });

    test(
      'emits syllable highlight parts and advances active part from audio position',
      () async {
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
                PronunciationBreakdownSegment(
                  index: 0,
                  chunk: 'but',
                  spoken: 'but',
                  startMs: 0,
                  endMs: 250,
                ),
                PronunciationBreakdownSegment(
                  index: 1,
                  chunk: 'ter',
                  spoken: 'tur',
                  startMs: 251,
                  endMs: 520,
                ),
                PronunciationBreakdownSegment(
                  index: 2,
                  chunk: 'fly',
                  spoken: 'fly',
                  startMs: 521,
                  endMs: 760,
                ),
              ],
              breakdown: PronunciationAudioAsset(
                url: 'https://cdn/butterfly-breakdown.mp3',
              ),
              fullWord: PronunciationAudioAsset(
                url: 'https://cdn/butterfly-full.mp3',
              ),
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
        expect(engine.snapshot.highlightParts.map((part) => part.text), [
          'but',
          'ter',
          'fly',
        ]);
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
      },
    );

    test(
      'falls back to speakWord when manifest entry is missing for tap',
      () async {
        manifest.manifest = const BookPronunciationManifest(
          bookId: 'book-1',
          entries: {},
        );

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
      },
    );

    test(
      'falls back to speakBreakdown when pronunciation playback throws for long press',
      () async {
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
      },
    );

    test(
      'cancel stops pronunciation and fallback speech and clears state',
      () async {
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
        if (!playbackCompleter.isCompleted) playbackCompleter.complete();
        final result = await future;

        expect(result.outcome, WordHelpOutcome.cancelled);
        expect(pronunciationAudio.stopCount, greaterThanOrEqualTo(1));
        expect(fallbackSpeech.stopCount, greaterThanOrEqualTo(1));
        expect(engine.snapshot.phase, WordHelpPhase.idle);
      },
    );

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
      if (!playbackCompleter.isCompleted) playbackCompleter.complete();
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

class _FakePronunciationPlayer implements PronunciationPlayer {
  final _positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final playedSequences = <List<String>>[];
  var stopCount = 0;
  Object? playError;
  Completer<void>? playCompleter;

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Stream<bool> get playing => _playingController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> play(List<String> urls) async {
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

  @override
  Future<void> stop() async {
    stopCount++;
    final completer = playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> dispose() async {
    await _positionController.close();
    await _playingController.close();
  }
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
    events.add(
      _AnalyticsEvent(wordIndex: wordIndex, mode: mode, outcome: outcome),
    );
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
    final normalized = rawWord.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    return normalized.isEmpty ? null : normalized;
  }
}
