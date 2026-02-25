import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

class AudioEngine {
  static const Duration _restartThreshold = Duration(milliseconds: 250);

  final AudioPlayer _narration = AudioPlayer();
  final AudioPlayer _soundscape = AudioPlayer();

  bool _initialized = false;
  int _pageAudioRequestId = 0;
  String? _currentSoundscapeUrl;

  /// Whether the user has toggled narration on (independent of player state).
  bool _narrationActive = false;

  /// Whether the user has toggled soundscape on (independent of player state).
  bool _soundscapeActive = false;

  double _soundscapeTargetVolume = 0.6;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _soundscape.setLoopMode(LoopMode.off);
    await _soundscape.setVolume(_soundscapeTargetVolume);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Page loading
  // ---------------------------------------------------------------------------

  Future<void> loadPage(PageData page) async {
    await ensureInitialized();
    final requestId = ++_pageAudioRequestId;

    await Future.wait([_narration.stop(), _soundscape.stop()]);
    if (requestId != _pageAudioRequestId) {
      return;
    }

    final narrationUrl = page.narrationUrl;
    if (narrationUrl != null && narrationUrl.isNotEmpty) {
      await _narration.setUrl(narrationUrl);
      if (requestId != _pageAudioRequestId) {
        return;
      }
      if (_narrationActive) {
        await _narration.play();
      }
    }

    final soundscapeUrl = page.soundscapeUrl;
    if (soundscapeUrl != null && soundscapeUrl.isNotEmpty) {
      await _soundscape.setVolume(_soundscapeTargetVolume);
      await _soundscape.setUrl(soundscapeUrl);
      _currentSoundscapeUrl = soundscapeUrl;
      if (requestId != _pageAudioRequestId) {
        return;
      }
      if (_soundscapeActive) {
        await _soundscape.play();
      }
    } else {
      _currentSoundscapeUrl = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Independent narration controls
  // ---------------------------------------------------------------------------

  Future<void> playNarration() async {
    await ensureInitialized();
    await _restartIfCompleted(_narration);
    _narrationActive = true;
    await _narration.play();
  }

  Future<void> pauseNarration() async {
    _narrationActive = false;
    await _narration.pause();
  }

  Future<void> toggleNarration() async {
    if (_narrationActive && _narration.playing) {
      await pauseNarration();
    } else {
      await playNarration();
    }
  }

  // ---------------------------------------------------------------------------
  // Independent soundscape controls
  // ---------------------------------------------------------------------------

  Future<void> playSoundscape() async {
    await ensureInitialized();
    await _restartIfCompleted(_soundscape);
    _soundscapeActive = true;
    await _soundscape.play();
  }

  Future<void> pauseSoundscape() async {
    _soundscapeActive = false;
    await _soundscape.pause();
  }

  Future<void> toggleSoundscape() async {
    if (_soundscapeActive && _soundscape.playing) {
      await pauseSoundscape();
    } else {
      await playSoundscape();
    }
  }

  // ---------------------------------------------------------------------------
  // Page transitions
  // ---------------------------------------------------------------------------

  Future<void> transitionToPage(PageData nextPage) async {
    await ensureInitialized();
    final requestId = ++_pageAudioRequestId;

    final nextNarrationUrl = nextPage.narrationUrl;
    final nextSoundscapeUrl = nextPage.soundscapeUrl;

    await _narration.stop();
    if (requestId != _pageAudioRequestId) {
      return;
    }

    if (nextNarrationUrl != null && nextNarrationUrl.isNotEmpty) {
      await _narration.setUrl(nextNarrationUrl);
      if (requestId != _pageAudioRequestId) {
        return;
      }
      if (_narrationActive) {
        await _narration.play();
      }
    }

    final hasSoundscape =
        nextSoundscapeUrl != null && nextSoundscapeUrl.isNotEmpty;
    final isSameSoundscape =
        hasSoundscape && nextSoundscapeUrl == _currentSoundscapeUrl;

    if (isSameSoundscape) {
      return;
    }

    await _soundscape.stop();
    if (requestId != _pageAudioRequestId) {
      return;
    }

    if (nextSoundscapeUrl != null && nextSoundscapeUrl.isNotEmpty) {
      await _soundscape.setVolume(_soundscapeTargetVolume);
      await _soundscape.setUrl(nextSoundscapeUrl);
      _currentSoundscapeUrl = nextSoundscapeUrl;
      if (requestId != _pageAudioRequestId) {
        return;
      }
      if (_soundscapeActive) {
        await _soundscape.play();
      }
    } else {
      _currentSoundscapeUrl = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  Stream<Duration> get narrationPosition => _narration.positionStream;
  Stream<bool> get narrationPlaying => _narration.playingStream;
  Stream<bool> get soundscapePlaying => _soundscape.playingStream;

  bool get isNarrationActive => _narrationActive;
  bool get isSoundscapeActive => _soundscapeActive;

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  Future<void> setNarrationVolume(double volume) =>
      _narration.setVolume(volume);

  Future<void> setSoundscapeVolume(double volume) {
    _soundscapeTargetVolume = volume;
    return _soundscape.setVolume(volume);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _narration.dispose();
    await _soundscape.dispose();
  }

  Future<void> _restartIfCompleted(AudioPlayer player) async {
    final duration = player.duration;
    if (duration == null || duration <= Duration.zero) {
      return;
    }

    final restartCutoff = duration > _restartThreshold
        ? duration - _restartThreshold
        : Duration.zero;
    final isNearEnd = player.position >= restartCutoff;
    final isCompleted = player.processingState == ProcessingState.completed;

    if (isNearEnd || isCompleted) {
      await player.seek(Duration.zero);
    }
  }
}
