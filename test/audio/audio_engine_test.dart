import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/audio_engine.dart';
import 'package:loratone/src/audio/page_audio.dart';
import 'package:loratone/src/audio/raw_player.dart';
import 'package:loratone/src/data/models.dart';

void main() {
  group('AudioEngine', () {
    late FakeRawPlayer narration;
    late FakeRawPlayer soundscape;
    late FakeRawPlayer pronunciation;
    late AudioEngine engine;

    setUp(() {
      narration = FakeRawPlayer();
      soundscape = FakeRawPlayer();
      pronunciation = FakeRawPlayer();
      engine = AudioEngine(
        playerFactory: () => throw UnimplementedError('use injected players'),
        narrationPlayer: narration,
        soundscapePlayer: soundscape,
        pronunciationPlayer: pronunciation,
      );
    });

    tearDown(() async {
      await engine.dispose();
    });

    group('loadPage', () {
      test('sets narration source and plays when active', () async {
        await engine.toggleNarration();
        await engine.loadPage(
          const PageData(
            id: 'p1',
            pageNumber: 1,
            textContent: 'hello',
            narrationUrl: 'https://cdn/narration.mp3',
          ),
        );

        expect(narration.setSourceCalls, ['https://cdn/narration.mp3']);
        expect(narration.playCount, greaterThanOrEqualTo(1));
      });

      test('stops narration before loading new page', () async {
        await engine.loadPage(
          const PageData(
            id: 'p1',
            pageNumber: 1,
            textContent: 'hello',
            narrationUrl: 'https://cdn/narration-1.mp3',
          ),
        );

        await engine.loadPage(
          const PageData(
            id: 'p2',
            pageNumber: 2,
            textContent: 'world',
            narrationUrl: 'https://cdn/narration-2.mp3',
          ),
        );

        expect(narration.stopCount, greaterThanOrEqualTo(1));
      });

      test('skips soundscape restart on same URL', () async {
        await engine.toggleSoundscape();
        await engine.loadPage(
          const PageData(
            id: 'p1',
            pageNumber: 1,
            textContent: 'hello',
            soundscapeUrl: 'https://cdn/soundscape.mp3',
          ),
        );
        final soundscapeStopCountAfterFirst = soundscape.stopCount;

        await engine.loadPage(
          const PageData(
            id: 'p2',
            pageNumber: 2,
            textContent: 'world',
            soundscapeUrl: 'https://cdn/soundscape.mp3',
          ),
        );

        expect(soundscape.stopCount, soundscapeStopCountAfterFirst);
      });

      test('stops soundscape on URL change', () async {
        await engine.loadPage(
          const PageData(
            id: 'p1',
            pageNumber: 1,
            textContent: 'hello',
            soundscapeUrl: 'https://cdn/soundscape-1.mp3',
          ),
        );

        await engine.loadPage(
          const PageData(
            id: 'p2',
            pageNumber: 2,
            textContent: 'world',
            soundscapeUrl: 'https://cdn/soundscape-2.mp3',
          ),
        );

        expect(soundscape.setSourceCalls, [
          'https://cdn/soundscape-1.mp3',
          'https://cdn/soundscape-2.mp3',
        ]);
      });
    });

    group('toggleNarration', () {
      test('plays when inactive', () async {
        await engine.toggleNarration();
        expect(narration.playCount, 1);
        expect(engine.isNarrationActive, true);
      });

      test('pauses when active', () async {
        await engine.toggleNarration();
        await engine.toggleNarration();
        expect(narration.pauseCount, 1);
        expect(engine.isNarrationActive, false);
      });
    });

    group('toggleSoundscape', () {
      test('plays when inactive', () async {
        await engine.toggleSoundscape();
        expect(soundscape.playCount, 1);
        expect(engine.isSoundscapeActive, true);
      });

      test('pauses when active', () async {
        await engine.toggleSoundscape();
        await engine.toggleSoundscape();
        expect(soundscape.pauseCount, 1);
        expect(engine.isSoundscapeActive, false);
      });
    });

    group('volume', () {
      test('setNarrationVolume', () async {
        await engine.setNarrationVolume(0.5);
        expect(narration.volumeCalls, [0.5]);
      });

      test('setSoundscapeVolume', () async {
        await engine.setSoundscapeVolume(0.8);
        expect(soundscape.volumeCalls, [0.8]);
      });
    });

    group('duckForPractice / restoreFromPractice', () {
      test('ducks soundscape and pauses narration', () async {
        await engine.toggleNarration();
        await engine.toggleSoundscape();
        await engine.duckForPractice();

        expect(narration.pauseCount, greaterThanOrEqualTo(1));
        expect(soundscape.volumeCalls.last, 0.3);
      });

      test('restores soundscape volume and narration', () async {
        await engine.toggleNarration();
        await engine.toggleSoundscape();
        await engine.duckForPractice();
        await engine.restoreFromPractice();

        expect(soundscape.volumeCalls.last, 0.6);
        expect(narration.playCount, greaterThanOrEqualTo(2));
      });
    });

    group('states stream', () {
      test('emits AudioSnapshot on narration position change', () async {
        final snapshots = <AudioSnapshot>[];
        engine.states.listen(snapshots.add);

        await engine.loadPage(
          const PageData(
            id: 'p1',
            pageNumber: 1,
            textContent: 'hello',
            narrationUrl: 'https://cdn/narration.mp3',
          ),
        );

        narration.positionController.add(const Duration(seconds: 5));
        await pumpEventQueue();

        expect(snapshots.any((s) => s.narrationPosition.inSeconds == 5), true);
      });

      test('states stream emits isNarrationPlaying false when narration stops',
          () async {
        await engine.toggleNarration();
        final snapshots = <AudioSnapshot>[];
        final sub = engine.states.listen(snapshots.add);

        await engine.toggleNarration();
        await Future<void>.delayed(Duration.zero);

        expect(snapshots.any((s) => !s.isNarrationPlaying), true);
        await sub.cancel();
      });
    });

    group('play (pronunciation)', () {
      test('plays sequential URLs', () async {
        await engine.play(['https://cdn/a.mp3', 'https://cdn/b.mp3']);

        expect(pronunciation.setSourceCalls, [
          'https://cdn/a.mp3',
          'https://cdn/b.mp3',
        ]);
      });

      test('empty list is no-op', () async {
        await engine.play([]);
        expect(pronunciation.setSourceCalls, isEmpty);
      });

      test('filters empty URLs', () async {
        await engine.play(['https://cdn/a.mp3', '', 'https://cdn/b.mp3']);

        expect(pronunciation.setSourceCalls, [
          'https://cdn/a.mp3',
          'https://cdn/b.mp3',
        ]);
      });
    });

    group('stop (pronunciation)', () {
      test('stops pronunciation player', () async {
        final future = engine.play(['https://cdn/a.mp3']);
        await pumpEventQueue();
        await engine.stop();
        await future;

        expect(pronunciation.stopCount, greaterThanOrEqualTo(1));
      });
    });

    group('cancel-and-replace pronunciation', () {
      test('second play cancels first', () async {
        pronunciation.autoComplete = false;
        final first = engine.play(['https://cdn/a.mp3']);
        await pumpEventQueue();

        final second = engine.play(['https://cdn/b.mp3']);
        await pumpEventQueue();

        pronunciation.completePlayback();
        await first;
        await second;

        expect(pronunciation.setSourceCalls.last, 'https://cdn/b.mp3');
      });
    });

    group('race conditions', () {
      test('rapid loadPage uses last call', () async {
        final futures = [
          engine.loadPage(
            const PageData(
              id: 'p1',
              pageNumber: 1,
              textContent: 'first',
              narrationUrl: 'https://cdn/narration-1.mp3',
            ),
          ),
          engine.loadPage(
            const PageData(
              id: 'p2',
              pageNumber: 2,
              textContent: 'second',
              narrationUrl: 'https://cdn/narration-2.mp3',
            ),
          ),
        ];
        await Future.wait(futures);

        expect(narration.setSourceCalls.last, 'https://cdn/narration-2.mp3');
      });

      test('rapid play uses last call', () async {
        pronunciation.autoComplete = false;
        final first = engine.play(['https://cdn/a.mp3']);
        final second = engine.play(['https://cdn/b.mp3']);
        await pumpEventQueue();

        pronunciation.completePlayback();
        await first;
        await second;

        expect(pronunciation.setSourceCalls.last, 'https://cdn/b.mp3');
      });
    });

    group('restart-if-completed', () {
      test('seeks to zero when narration completed', () async {
        narration.durationValue = const Duration(seconds: 10);
        narration.positionValue = const Duration(seconds: 10);
        narration.stateValue = RawPlayerState.completed;

        await engine.toggleNarration();

        expect(narration.seekCalls, [Duration.zero]);
      });
    });

    test('loadPage does not stop soundscape when URL is the same', () async {
      await engine.loadPage(
        const PageData(
          id: 'p1',
          pageNumber: 1,
          textContent: 'hello',
          soundscapeUrl: 'https://cdn/ambient.mp3',
        ),
      );
      final stopsAfterFirst = soundscape.stopCount;

      await engine.loadPage(
        const PageData(
          id: 'p2',
          pageNumber: 2,
          textContent: 'world',
          narrationUrl: 'https://cdn/narr.mp3',
          soundscapeUrl: 'https://cdn/ambient.mp3',
        ),
      );

      expect(soundscape.stopCount, stopsAfterFirst);
    });

    test('duckForPractice does not pause narration when not playing',
        () async {
      await engine.duckForPractice();

      expect(narration.pauseCount, 0);
      expect(soundscape.volumeCalls.last, 0.3);
    });

    test(
        'restoreFromPractice does not resume narration if not playing before',
        () async {
      await engine.duckForPractice();
      await engine.restoreFromPractice();

      expect(narration.playCount, 0);
    });
  });
}

class FakeRawPlayer implements RawPlayer {
  bool autoComplete = true;
  Completer<void>? _playCompleter;
  Timer? _autoCompleteTimer;

  final setSourceCalls = <String>[];
  final volumeCalls = <double>[];
  final seekCalls = <Duration>[];
  var playCount = 0;
  var pauseCount = 0;
  var stopCount = 0;
  var disposeCount = 0;

  Duration positionValue = Duration.zero;
  Duration? durationValue;
  RawPlayerState stateValue = RawPlayerState.idle;
  bool isPlayingValue = false;

  final positionController = StreamController<Duration>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  final stateController = StreamController<RawPlayerState>.broadcast();

  @override
  Future<void> setSource(String url) async {
    setSourceCalls.add(url);
  }

  @override
  Future<void> play() async {
    playCount++;
    isPlayingValue = true;
    playingController.add(true);

    _playCompleter = Completer<void>();
    if (autoComplete) {
      _autoCompleteTimer = Timer(const Duration(milliseconds: 10), () {
        if (_playCompleter != null && !_playCompleter!.isCompleted) {
          stateValue = RawPlayerState.completed;
          stateController.add(RawPlayerState.completed);
          _playCompleter!.complete();
        }
      });
    }
    await _playCompleter!.future;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    isPlayingValue = false;
    playingController.add(false);
    _autoCompleteTimer?.cancel();
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    isPlayingValue = false;
    playingController.add(false);
    stateValue = RawPlayerState.idle;
    stateController.add(RawPlayerState.idle);
    _autoCompleteTimer?.cancel();
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    positionValue = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
  }

  @override
  Future<void> setLoopMode(RawLoopMode mode) async {}

  @override
  bool get isPlaying => isPlayingValue;

  @override
  Duration get position => positionValue;

  @override
  Duration? get duration => durationValue;

  @override
  RawPlayerState get state => stateValue;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Stream<RawPlayerState> get stateStream => stateController.stream;

  @override
  Future<void> dispose() async {
    disposeCount++;
    _autoCompleteTimer?.cancel();
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      _playCompleter!.complete();
    }
    await positionController.close();
    await playingController.close();
    await stateController.close();
  }

  void completePlayback() {
    _autoCompleteTimer?.cancel();
    if (_playCompleter != null && !_playCompleter!.isCompleted) {
      stateValue = RawPlayerState.completed;
      stateController.add(RawPlayerState.completed);
      _playCompleter!.complete();
    }
  }
}
