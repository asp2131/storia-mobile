import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../data/models.dart';
import 'page_audio.dart';
import 'pronunciation_player.dart';
import 'raw_player.dart';

typedef RawPlayerFactory = RawPlayer Function();

class AudioEngine implements PageAudio, PronunciationPlayer {
  AudioEngine({
    required RawPlayerFactory playerFactory,
    RawPlayer? narrationPlayer,
    RawPlayer? soundscapePlayer,
    RawPlayer? pronunciationPlayer,
  })  : _narration = narrationPlayer ?? playerFactory(),
        _soundscape = soundscapePlayer ?? playerFactory(),
        _pronunciation = pronunciationPlayer ?? playerFactory();

  final RawPlayer _narration;
  final RawPlayer _soundscape;
  final RawPlayer _pronunciation;

  static const Duration _restartThreshold = Duration(milliseconds: 250);

  final StreamController<bool> _pronunciationPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<AudioSnapshot> _snapshotController =
      StreamController<AudioSnapshot>.broadcast();

  bool _initialized = false;
  int _pageAudioRequestId = 0;
  int _pronunciationRequestId = 0;
  String? _currentSoundscapeUrl;

  bool _narrationActive = false;
  bool _soundscapeActive = false;
  double _soundscapeTargetVolume = 0.6;

  bool _wasNarrationPlayingBeforePractice = false;
  double _soundscapeVolumeBeforePractice = 0.6;

  StreamSubscription<Duration>? _narrationPositionSub;
  StreamSubscription<bool>? _narrationPlayingSub;
  StreamSubscription<bool>? _soundscapePlayingSub;

  AudioSnapshot _currentSnapshot = const AudioSnapshot();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    await _soundscape.setLoopMode(RawLoopMode.off);
    await _soundscape.setVolume(_soundscapeTargetVolume);

    _narrationPositionSub = _narration.positionStream.listen((pos) {
      _currentSnapshot = _currentSnapshot.copyWith(narrationPosition: pos);
      _emitSnapshot();
    });
    _narrationPlayingSub = _narration.playingStream.listen((playing) {
      _currentSnapshot = _currentSnapshot.copyWith(isNarrationPlaying: playing);
      _emitSnapshot();
    });
    _soundscapePlayingSub = _soundscape.playingStream.listen((playing) {
      _currentSnapshot =
          _currentSnapshot.copyWith(isSoundscapePlaying: playing);
      _emitSnapshot();
    });

    _initialized = true;
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_currentSnapshot);
    }
  }

  @override
  Future<void> loadPage(PageData page) async {
    await _ensureInitialized();
    final requestId = ++_pageAudioRequestId;

    await _narration.stop();
    if (requestId != _pageAudioRequestId) return;

    final narrationUrl = page.narrationUrl;
    if (narrationUrl != null && narrationUrl.isNotEmpty) {
      await _narration.setSource(narrationUrl);
      if (requestId != _pageAudioRequestId) return;
      if (_narrationActive) {
        await _narration.play();
      }
    }

    final soundscapeUrl = page.soundscapeUrl;
    final hasSoundscape = soundscapeUrl != null && soundscapeUrl.isNotEmpty;
    final isSameSoundscape =
        hasSoundscape && soundscapeUrl == _currentSoundscapeUrl;

    if (isSameSoundscape) return;

    await _soundscape.stop();
    if (requestId != _pageAudioRequestId) return;

    if (hasSoundscape) {
      await _soundscape.setVolume(_soundscapeTargetVolume);
      await _soundscape.setSource(soundscapeUrl);
      _currentSoundscapeUrl = soundscapeUrl;
      if (requestId != _pageAudioRequestId) return;
      if (_soundscapeActive) {
        await _soundscape.play();
      }
    } else {
      _currentSoundscapeUrl = null;
    }
  }

  @override
  Future<void> stopAll() async {
    _pageAudioRequestId++;
    _narrationActive = false;
    _soundscapeActive = false;
    _currentSoundscapeUrl = null;
    await _narration.stop();
    await _soundscape.stop();
  }

  @override
  Future<void> toggleNarration() async {
    await _ensureInitialized();
    if (_narrationActive && _narration.isPlaying) {
      _narrationActive = false;
      await _narration.pause();
    } else {
      await _restartIfCompleted(_narration);
      _narrationActive = true;
      await _narration.play();
    }
  }

  @override
  Future<void> toggleSoundscape() async {
    await _ensureInitialized();
    if (_soundscapeActive && _soundscape.isPlaying) {
      _soundscapeActive = false;
      await _soundscape.pause();
    } else {
      await _restartIfCompleted(_soundscape);
      _soundscapeActive = true;
      await _soundscape.play();
    }
  }

  @override
  Future<void> setNarrationVolume(double volume) =>
      _narration.setVolume(volume);

  @override
  Future<void> setSoundscapeVolume(double volume) {
    _soundscapeTargetVolume = volume;
    return _soundscape.setVolume(volume);
  }

  @override
  Future<void> duckForPractice() async {
    _wasNarrationPlayingBeforePractice =
        _narrationActive && _narration.isPlaying;
    _soundscapeVolumeBeforePractice = _soundscapeTargetVolume;

    if (_wasNarrationPlayingBeforePractice) {
      _narrationActive = false;
      await _narration.pause();
    }
    await setSoundscapeVolume(0.3);
  }

  @override
  Future<void> restoreFromPractice() async {
    await setSoundscapeVolume(_soundscapeVolumeBeforePractice);

    if (_wasNarrationPlayingBeforePractice && !_narration.isPlaying) {
      _narrationActive = true;
      await _narration.play();
    }
  }

  @override
  Stream<AudioSnapshot> get states => _snapshotController.stream;

  bool get isNarrationActive => _narrationActive;
  bool get isSoundscapeActive => _soundscapeActive;

  @override
  Future<void> play(List<String> urls) async {
    final filtered = urls.where((u) => u.isNotEmpty).toList(growable: false);
    if (filtered.isEmpty) return;

    await _ensureInitialized();
    final requestId = ++_pronunciationRequestId;
    await _pronunciation.stop();
    if (requestId != _pronunciationRequestId) return;

    _emitPronunciationPlaying(true);
    try {
      for (final url in filtered) {
        if (requestId != _pronunciationRequestId) return;
        await _pronunciation.setSource(url);
        if (requestId != _pronunciationRequestId) return;
        await _pronunciation.seek(Duration.zero);
        final done = _waitForPronunciationSegmentToEnd(requestId);
        await _pronunciation.play();
        await done;
        if (requestId != _pronunciationRequestId) return;
      }
    } finally {
      if (requestId == _pronunciationRequestId) {
        _emitPronunciationPlaying(false);
      }
    }
  }

  @override
  Future<void> stop() async {
    _pronunciationRequestId++;
    await _pronunciation.stop();
    _emitPronunciationPlaying(false);
  }

  @override
  Stream<Duration> get position => _pronunciation.positionStream;

  @override
  Stream<bool> get playing => _pronunciationPlayingController.stream;

  bool get isPronunciationPlaying => _pronunciation.isPlaying;

  Future<void> _waitForPronunciationSegmentToEnd(int requestId) async {
    await _pronunciation.stateStream.firstWhere((state) {
      if (requestId != _pronunciationRequestId) return true;
      return state == RawPlayerState.completed ||
          state == RawPlayerState.idle;
    });
  }

  void _emitPronunciationPlaying(bool value) {
    if (_pronunciationPlayingController.isClosed) return;
    _pronunciationPlayingController.add(value);
  }

  Future<void> dispose() async {
    await _narrationPositionSub?.cancel();
    await _narrationPlayingSub?.cancel();
    await _soundscapePlayingSub?.cancel();
    await _pronunciationPlayingController.close();
    await _snapshotController.close();
    await _narration.dispose();
    await _soundscape.dispose();
    await _pronunciation.dispose();
  }

  Future<void> _restartIfCompleted(RawPlayer player) async {
    final dur = player.duration;
    if (dur == null || dur <= Duration.zero) return;

    final restartCutoff =
        dur > _restartThreshold ? dur - _restartThreshold : Duration.zero;
    final isNearEnd = player.position >= restartCutoff;
    final isCompleted = player.state == RawPlayerState.completed;

    if (isNearEnd || isCompleted) {
      await player.seek(Duration.zero);
    }
  }
}
