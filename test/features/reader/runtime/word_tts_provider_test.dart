import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:storia_kids/src/data/pronunciation_models.dart';
import 'package:storia_kids/src/data/pronunciation_repository.dart';
import 'package:storia_kids/src/features/reader/runtime/providers/word_tts_provider.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_intent.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_view_state.dart';
import 'package:storia_kids/src/features/reader/runtime/services/pronunciation_playback_service.dart';
import 'package:storia_kids/src/features/reader/runtime/services/word_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('WordTtsNotifier pronunciation highlighting', () {
    late _FakeWordTtsService tts;
    late _FakePronunciationRepository repository;
    late _FakeReaderSession session;
    late StreamController<Duration> positionController;
    late Completer<void> playbackCompleter;
    late List<List<String>> playedSequences;
    late WordTtsNotifier notifier;

    setUp(() {
      tts = _FakeWordTtsService();
      repository = _FakePronunciationRepository();
      session = _FakeReaderSession();
      positionController = StreamController<Duration>.broadcast();
      playbackCompleter = Completer<void>();
      playedSequences = [];
      notifier = WordTtsNotifier(
        service: tts,
        pronunciation: PronunciationPlaybackService.withPlaybackCallbacks(
          playPronunciationSequence: (urls) {
            playedSequences.add(List<String>.of(urls));
            return playbackCompleter.future;
          },
          stopPronunciation: () async {},
          repository: repository,
          pronunciationPosition: positionController.stream,
        ),
        session: session,
      )..setBookId('book-1');
    });

    tearDown(() async {
      notifier.dispose();
      await positionController.close();
      await session.dispose();
    });

    test(
      'builds syllable parts from metadata and advances active index',
      () async {
        repository.manifest = BookPronunciationManifest(
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

        final tapFuture = notifier.onWordTapped('Butterfly!', 12);
        await pumpEventQueue();

        expect(playedSequences, [
          [
            'https://cdn/butterfly-breakdown.mp3',
            'https://cdn/butterfly-full.mp3',
          ],
        ]);
        expect(notifier.state.tappedWordIndex, 12);
        expect(notifier.state.highlightParts.map((part) => part.text), [
          'but',
          'ter',
          'fly',
        ]);
        expect(notifier.state.highlightParts.map((part) => part.startMs), [
          0,
          251,
          521,
        ]);
        expect(notifier.state.activeHighlightPartIndex, 0);

        positionController.add(const Duration(milliseconds: 300));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, 1);

        positionController.add(const Duration(milliseconds: 700));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, 2);

        // Simulates AudioEngine moving from the breakdown clip to the full-word
        // clip, whose position stream restarts from zero.
        positionController.add(const Duration(milliseconds: 10));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, isNull);
        expect(notifier.state.highlightParts, isEmpty);
        expect(notifier.state.tappedWordIndex, 12);

        playbackCompleter.complete();
        await tapFuture;
        expect(notifier.state.tappedWordIndex, isNull);
        expect(notifier.state.highlightParts, isEmpty);
        expect(tts.spokenWords, isEmpty);
      },
    );

    test(
      'prefers saved syllables when breakdown segment count differs',
      () async {
        repository.manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {
            'inside': const WordPronunciation(
              normalizedWord: 'inside',
              source: 'generated',
              syllables: ['in', 'side'],
              breakdownSegments: [
                PronunciationBreakdownSegment(
                  index: 0,
                  chunk: 'inside',
                  spoken: 'inside',
                  startMs: 100,
                  endMs: 900,
                ),
              ],
              breakdown: PronunciationAudioAsset(
                url: 'https://cdn/inside-breakdown.mp3',
              ),
            ),
          },
        );

        final tapFuture = notifier.onWordTapped('inside', 7);
        await pumpEventQueue();

        expect(notifier.state.highlightParts.map((part) => part.text), [
          'in',
          'side',
        ]);
        expect(notifier.state.highlightParts.map((part) => part.startMs), [
          100,
          500,
        ]);
        expect(notifier.state.highlightParts.map((part) => part.endMs), [
          500,
          900,
        ]);
        expect(notifier.state.activeHighlightPartIndex, 0);

        positionController.add(const Duration(milliseconds: 550));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, 1);

        playbackCompleter.complete();
        await tapFuture;
      },
    );

    test(
      'uses fallback syllable timing when breakdown metadata has no times',
      () async {
        repository.manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {
            'banana': const WordPronunciation(
              normalizedWord: 'banana',
              source: 'generated',
              syllables: ['ba', 'na', 'na'],
              breakdownSegments: [
                PronunciationBreakdownSegment(
                  index: 0,
                  chunk: 'ba',
                  spoken: 'ba',
                ),
                PronunciationBreakdownSegment(
                  index: 1,
                  chunk: 'na',
                  spoken: 'nah',
                ),
                PronunciationBreakdownSegment(
                  index: 2,
                  chunk: 'na',
                  spoken: 'nuh',
                ),
              ],
              breakdown: PronunciationAudioAsset(
                url: 'https://cdn/banana-breakdown.mp3',
              ),
            ),
          },
        );

        final longPressFuture = notifier.onWordLongPressed('banana', 5);
        await pumpEventQueue();

        expect(notifier.state.highlightParts.map((part) => part.text), [
          'ba',
          'na',
          'na',
        ]);
        expect(notifier.state.highlightParts.map((part) => part.startMs), [
          0,
          650,
          1300,
        ]);
        expect(notifier.state.highlightParts.map((part) => part.endMs), [
          650,
          1300,
          1950,
        ]);
        expect(notifier.state.activeHighlightPartIndex, 0);

        positionController.add(const Duration(milliseconds: 675));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, 1);

        positionController.add(const Duration(milliseconds: 1400));
        await pumpEventQueue();
        expect(notifier.state.activeHighlightPartIndex, 2);

        playbackCompleter.complete();
        await longPressFuture;
        expect(tts.soundedOutWords, isEmpty);
      },
    );
  });
}

class _FakeWordTtsService extends WordTtsService {
  final spokenWords = <String>[];
  final soundedOutWords = <String>[];
  var stopCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> speak(String word) async {
    spokenWords.add(word);
  }

  @override
  Future<void> soundOut(String word) async {
    soundedOutWords.add(word);
  }

  @override
  void dispose() {}
}

class _FakePronunciationRepository extends PronunciationRepository {
  _FakePronunciationRepository()
    : super(SupabaseClient('https://example.supabase.co', 'anon-key'));

  BookPronunciationManifest? manifest;

  @override
  Future<BookPronunciationManifest?> getManifestForBook(String bookId) async {
    return manifest;
  }
}

class _FakeReaderSession implements ReaderSession {
  final _states = StreamController<ReaderViewState>.broadcast();
  final _pageChanges = StreamController<int>.broadcast();
  final dispatchedIntents = <ReaderIntent>[];

  @override
  Stream<ReaderViewState> get states => _states.stream;

  @override
  Stream<int> get pageChanges => _pageChanges.stream;

  @override
  Future<void> dispatch(ReaderIntent intent) async {
    dispatchedIntents.add(intent);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _pageChanges.close();
  }
}
