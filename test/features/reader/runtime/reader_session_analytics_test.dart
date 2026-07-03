import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

import 'package:loratone/src/audio/page_audio.dart';
import 'package:loratone/src/data/analytics_repository.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:loratone/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:loratone/src/features/reader/runtime/reader_analytics_tracker.dart';
import 'package:loratone/src/features/reader/runtime/reader_session.dart';
import 'package:loratone/src/features/reader/runtime/reader_session_impl.dart';

void main() {
  group('ReaderSessionImpl analytics instrumentation', () {
    late _FakeAnalyticsTransport transport;
    late ReaderAnalyticsTracker tracker;
    late _FakePageAudio audio;
    late _FakeSpeechPracticePort speech;
    late ReaderSessionImpl session;

    setUp(() {
      transport = _FakeAnalyticsTransport();
      tracker = ReaderAnalyticsTracker(
        analyticsRepository: AnalyticsRepository(
          transport: transport,
          currentChildProfileId: () => 'child-1',
        ),
        sessionIdFactory: () => 'reader-session-1',
        clock: () => DateTime.utc(2026, 1, 1),
      );
      audio = _FakePageAudio();
      speech = _FakeSpeechPracticePort();
      session = ReaderSessionImpl(
        pageAudio: audio,
        speechPort: speech,
        scheduler: _FakeSchedulerPort(),
        analyticsTracker: tracker,
      );
    });

    tearDown(() async {
      await session.dispose();
    });

    test('tracks reader lifecycle, page, audio, and speech events', () async {
      await session.dispatch(ReaderStart(book: _book));
      await pumpEventQueue();

      expect(transport.events.map(_eventName), [
        'reading_session_started',
        'book_started',
        'page_viewed',
      ]);
      expect(transport.events.first['sessionId'], 'reader-session-1');
      expect(transport.events.first['childProfileId'], 'child-1');

      transport.events.clear();
      await session.dispatch(const ReaderGoToPage(1));
      await pumpEventQueue();

      expect(transport.events.map(_eventName), [
        'page_interacted',
        'page_viewed',
        'book_completed',
      ]);
      expect(
        _properties(transport.events[0])['interactionType'],
        'page_navigation',
      );
      expect(_properties(transport.events[1])['pageId'], 'page-2');

      transport.events.clear();
      await session.dispatch(const ReaderToggleNarration());
      await session.dispatch(const ReaderToggleSoundscape());
      await pumpEventQueue();

      expect(transport.events.map(_eventName), [
        'page_interacted',
        'narration_played',
        'page_interacted',
        'soundscape_played',
      ]);

      transport.events.clear();
      await session.dispatch(const ReaderPracticePrimaryAction());
      await pumpEventQueue();
      speech.emitResult('goodbye', isFinal: true);
      await pumpEventQueue();

      expect(transport.events.map(_eventName), [
        'speech_attempt_started',
        'speech_attempt_completed',
      ]);
      final completedProperties = _properties(transport.events.last);
      expect(completedProperties['matchedWordCount'], 1);
      expect(completedProperties['hadSpeech'], true);
      expect(completedProperties.containsKey('recognizedWords'), false);
      expect(completedProperties.containsKey('transcript'), false);

      transport.events.clear();
      await session.dispatch(const ReaderEnd(reason: 'test_end'));
      await pumpEventQueue();

      expect(transport.events.map(_eventName), ['reading_session_ended']);
      expect(_properties(transport.events.single)['completed'], true);
    });

    test('tracks runtime end as drop-off before book completion', () async {
      await session.dispatch(ReaderStart(book: _book));
      await pumpEventQueue();

      transport.events.clear();
      await session.dispatch(const ReaderEnd(reason: 'closed_early'));
      await pumpEventQueue();

      expect(transport.events.map(_eventName), ['reading_session_drop_off']);
      expect(_properties(transport.events.single)['reason'], 'closed_early');
      expect(_properties(transport.events.single)['completed'], false);
    });

    test(
      'tracks word and phoneme playback without raw word metadata',
      () async {
        tracker.startBook(_book);
        await pumpEventQueue();

        transport.events.clear();
        tracker.recordWordAudioPlayed(wordIndex: 3, outcome: 'fallback');
        tracker.recordPhonemeAudioPlayed(wordIndex: 4, outcome: 'played');
        await pumpEventQueue();

        expect(transport.events.map(_eventName), [
          'page_interacted',
          'word_audio_played',
          'page_interacted',
          'phoneme_audio_played',
        ]);
        for (final event in transport.events) {
          final properties = _properties(event);
          expect(properties.containsKey('word'), false);
          expect(properties.containsKey('spokenWords'), false);
          expect(properties.containsKey('transcript'), false);
        }
      },
    );

    test(
      'does not duplicate played events for rapid play-stop toggles',
      () async {
        await session.dispatch(ReaderStart(book: _book));
        await pumpEventQueue();

        transport.events.clear();
        await session.dispatch(const ReaderToggleNarration());
        await session.dispatch(const ReaderToggleNarration());
        await pumpEventQueue();

        expect(transport.events.map(_eventName), [
          'page_interacted',
          'narration_played',
        ]);

        transport.events.clear();
        await session.dispatch(const ReaderToggleSoundscape());
        await session.dispatch(const ReaderToggleSoundscape());
        await pumpEventQueue();

        expect(transport.events.map(_eventName), [
          'page_interacted',
          'soundscape_played',
        ]);
      },
    );

    test('analytics transport failures do not break reader flow', () async {
      await _withSuppressedDebugPrint(() async {
        transport.error = StateError('network');

        await expectLater(session.dispatch(ReaderStart(book: _book)), completes);
        await pumpEventQueue();
        var state = await session.states.first;
        expect(state.isReady, true);
        expect(state.activePageIndex, 0);

        await expectLater(session.dispatch(const ReaderGoToPage(1)), completes);
        await pumpEventQueue();
        state = await session.states.first;
        expect(state.activePageIndex, 1);
        expect(transport.events, isEmpty);
        transport.error = null;
      });
    });
  });
}

Future<T> _withSuppressedDebugPrint<T>(Future<T> Function() body) async {
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    return await body();
  } finally {
    debugPrint = previousDebugPrint;
  }
}

String _eventName(Map<String, dynamic> body) => body['event'] as String;

Map<String, dynamic> _properties(Map<String, dynamic> body) =>
    body['properties'] as Map<String, dynamic>;

final _book = Book(
  id: 'book-1',
  title: 'Test Book',
  pageCount: 2,
  pages: const [
    PageData(
      id: 'page-1',
      pageNumber: 1,
      textContent: 'hello world',
      narrationUrl: 'https://cdn/narration-1.mp3',
      soundscapeUrl: 'https://cdn/soundscape-1.mp3',
    ),
    PageData(
      id: 'page-2',
      pageNumber: 2,
      textContent: 'goodbye world',
      narrationUrl: 'https://cdn/narration-2.mp3',
      soundscapeUrl: 'https://cdn/soundscape-2.mp3',
    ),
  ],
);

class _FakeAnalyticsTransport implements AnalyticsTransport {
  final events = <Map<String, dynamic>>[];
  Object? error;

  @override
  Future<void> send(Map<String, dynamic> body, {String? accessToken}) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    events.add(Map<String, dynamic>.from(body));
  }
}

class _FakePageAudio implements PageAudio {
  final _statesController = StreamController<AudioSnapshot>.broadcast();
  bool _isNarrationPlaying = false;
  bool _isSoundscapePlaying = false;

  @override
  Stream<AudioSnapshot> get states => _statesController.stream;

  @override
  Future<void> loadPage(PageData page) async {}

  @override
  Future<void> toggleNarration() async {
    _isNarrationPlaying = !_isNarrationPlaying;
    _statesController.add(
      AudioSnapshot(isNarrationPlaying: _isNarrationPlaying),
    );
  }

  @override
  Future<void> toggleSoundscape() async {
    _isSoundscapePlaying = !_isSoundscapePlaying;
    _statesController.add(
      AudioSnapshot(isSoundscapePlaying: _isSoundscapePlaying),
    );
  }

  @override
  Future<void> setNarrationVolume(double volume) async {}

  @override
  Future<void> setSoundscapeVolume(double volume) async {}

  @override
  Future<void> duckForPractice() async {}

  @override
  Future<void> restoreFromPractice() async {}

  @override
  Future<void> stopAll() async {}
}

class _FakeSpeechPracticePort implements SpeechPracticePort {
  void Function(String recognizedWords, {required bool isFinal})? _onResult;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
    onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  }) async {
    _onResult = onResult;
  }

  void emitResult(String recognizedWords, {required bool isFinal}) {
    _onResult?.call(recognizedWords, isFinal: isFinal);
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {
    _onResult = null;
  }
}

class _FakeSchedulerPort implements SchedulerPort {
  @override
  CancelableTask schedule(Duration delay, void Function() action) {
    return _FakeCancelableTask();
  }
}

class _FakeCancelableTask implements CancelableTask {
  @override
  void cancel() {}
}
