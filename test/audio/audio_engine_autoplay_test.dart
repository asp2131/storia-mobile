import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/audio_engine.dart';
import 'package:loratone/src/audio/raw_player.dart';
import 'package:loratone/src/data/models.dart';

/// RawPlayer fake that records setSource/play calls per named channel.
class _RecordingPlayer implements RawPlayer {
  _RecordingPlayer([this.label = 'unused-factory']);

  final String label;
  final List<String> events = <String>[];
  bool playing = false;
  double volume = 1.0;

  @override
  Future<void> setSource(String url) async => events.add('source:$url');
  @override
  Future<void> play() async {
    playing = true;
    events.add('play');
  }

  @override
  Future<void> pause() async {
    playing = false;
    events.add('pause');
  }

  @override
  Future<void> stop() async {
    playing = false;
    events.add('stop');
  }

  @override
  Future<void> seek(Duration position) async => events.add('seek');

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    events.add('volume:$value');
  }

  @override
  Future<void> setLoopMode(RawLoopMode mode) async {}

  @override
  bool get isPlaying => playing;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  RawPlayerState get state => RawPlayerState.ready;

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Stream<RawPlayerState> get stateStream => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

PageData pageWithNarration(String narrationUrl, {String? soundscapeUrl}) =>
    PageData(
      id: 'p1',
      pageNumber: 1,
      textContent: 'Thunder rolled.',
      narrationUrl: narrationUrl,
      soundscapeUrl: soundscapeUrl,
    );

void main() {
  late AudioEngine engine;
  late _RecordingPlayer narration;
  late _RecordingPlayer soundscape;

  void createEngine({bool autoplayPages = true}) {
    narration = _RecordingPlayer('narration');
    soundscape = _RecordingPlayer('soundscape');
    engine = AudioEngine(
      playerFactory: _RecordingPlayer.new,
      narrationPlayer: narration,
      soundscapePlayer: soundscape,
      pronunciationPlayer: _RecordingPlayer('pron'),
      autoplayPages: autoplayPages,
    );
  }

  setUp(createEngine);

  Future<void> useManualPlayback() async {
    await engine.dispose();
    createEngine(autoplayPages: false);
  }

  tearDown(() async {
    await engine.dispose();
  });

  test(
    'loadPage autoplays both channels by default (catalog behavior)',
    () async {
      await engine.loadPage(
        pageWithNarration(
          'https://cdn.test/n.mp3',
          soundscapeUrl: 'https://cdn.test/s.mp3',
        ),
      );

      expect(
        narration.events,
        containsAllInOrder(['source:https://cdn.test/n.mp3', 'play']),
      );
      expect(
        soundscape.events,
        containsAllInOrder(['source:https://cdn.test/s.mp3', 'play']),
      );
    },
  );

  test(
    'manual playback loads sources without playing before consent',
    () async {
      await useManualPlayback();
      await engine.loadPage(
        pageWithNarration(
          'https://cdn.test/n.mp3',
          soundscapeUrl: 'https://cdn.test/s.mp3',
        ),
      );

      expect(narration.events, contains('source:https://cdn.test/n.mp3'));
      expect(soundscape.events, contains('source:https://cdn.test/s.mp3'));
      expect(narration.events, isNot(contains('play')));
      expect(soundscape.events, isNot(contains('play')));
      expect(narration.playing, isFalse);
      expect(soundscape.playing, isFalse);
    },
  );

  test('a same-soundscape reload stays silent before consent', () async {
    await useManualPlayback();
    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n1.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );
    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n2.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );

    expect(narration.events.where((e) => e == 'play'), isEmpty);
    expect(soundscape.events.where((e) => e == 'play'), isEmpty);
    expect(soundscape.events.where((e) => e.startsWith('source:')), [
      'source:https://cdn.test/s.mp3',
    ]);
    expect(narration.playing, isFalse);
    expect(soundscape.playing, isFalse);
  });

  test('toggleNarration resumes a loaded silent channel', () async {
    await useManualPlayback();
    await engine.loadPage(pageWithNarration('https://cdn.test/n.mp3'));
    await engine.toggleNarration();

    expect(narration.playing, isTrue);
  });

  test('narration consent enables playback on later pages', () async {
    await useManualPlayback();
    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n1.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );
    await engine.toggleNarration();
    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n2.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );

    expect(narration.playing, isTrue);
    expect(soundscape.playing, isTrue);
    expect(narration.events.where((e) => e == 'play').length, 2);
    expect(soundscape.events.where((e) => e == 'play').length, 1);
    expect(soundscape.events.where((e) => e.startsWith('source:')), [
      'source:https://cdn.test/s.mp3',
    ]);
  });

  test('soundscape consent enables narration on later pages', () async {
    await useManualPlayback();
    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n1.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );
    await engine.toggleSoundscape();
    expect(narration.playing, isFalse);
    expect(soundscape.playing, isTrue);

    await engine.loadPage(
      pageWithNarration(
        'https://cdn.test/n2.mp3',
        soundscapeUrl: 'https://cdn.test/s.mp3',
      ),
    );
    expect(narration.playing, isTrue);
    expect(soundscape.playing, isTrue);
    expect(soundscape.events.where((e) => e == 'play').length, 1);
  });

  test('stopAll resets consent before the next page load', () async {
    await useManualPlayback();
    final page = pageWithNarration(
      'https://cdn.test/n.mp3',
      soundscapeUrl: 'https://cdn.test/s.mp3',
    );
    await engine.loadPage(page);
    await engine.toggleNarration();
    await engine.toggleSoundscape();
    expect(narration.playing, isTrue);
    expect(soundscape.playing, isTrue);

    await engine.stopAll();
    await engine.loadPage(page);

    expect(narration.playing, isFalse);
    expect(soundscape.playing, isFalse);
    expect(narration.events.where((e) => e == 'play').length, 1);
    expect(soundscape.events.where((e) => e == 'play').length, 1);
  });

  test('end during initialization cannot start delayed playback', () async {
    final pending = engine.loadPage(
      pageWithNarration('https://cdn.test/late.mp3'),
    );
    await engine.stopAll();
    await pending;
    expect(narration.playing, isFalse);
    expect(soundscape.playing, isFalse);
  });
}
