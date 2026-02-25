import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

class AudioEngine {
  final AudioPlayer _narration = AudioPlayer();
  final AudioPlayer _soundscape = AudioPlayer();

  bool _initialized = false;

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

    _soundscape.setLoopMode(LoopMode.one);
    await _soundscape.setVolume(_soundscapeTargetVolume);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Page loading
  // ---------------------------------------------------------------------------

  Future<void> loadPage(PageData page) async {
    await ensureInitialized();

    final futures = <Future<void>>[];

    if (page.narrationUrl != null && page.narrationUrl!.isNotEmpty) {
      futures.add(_narration.setUrl(page.narrationUrl!).then((_) {}));
    } else {
      futures.add(_narration.stop());
    }

    if (page.soundscapeUrl != null && page.soundscapeUrl!.isNotEmpty) {
      futures.add(_soundscape.setUrl(page.soundscapeUrl!).then((_) {}));
    } else {
      futures.add(_soundscape.stop());
    }

    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Independent narration controls
  // ---------------------------------------------------------------------------

  Future<void> playNarration() async {
    await ensureInitialized();
    _narrationActive = true;
    await _narration.play();
  }

  Future<void> pauseNarration() async {
    _narrationActive = false;
    await _narration.pause();
  }

  Future<void> toggleNarration() async {
    if (_narrationActive) {
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
    _soundscapeActive = true;
    await _soundscape.play();
  }

  Future<void> pauseSoundscape() async {
    _soundscapeActive = false;
    await _soundscape.pause();
  }

  Future<void> toggleSoundscape() async {
    if (_soundscapeActive) {
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

    final nextNarrationUrl = nextPage.narrationUrl;
    final nextSoundscapeUrl = nextPage.soundscapeUrl;
    // Fully stop both channels while transitioning so no overlap leaks
    // between pages.
    await Future.wait([_narration.stop(), _soundscape.stop()]);

    if (nextNarrationUrl != null && nextNarrationUrl.isNotEmpty) {
      await _narration.setUrl(nextNarrationUrl);
      if (_narrationActive) {
        await _narration.play();
      }
    }

    if (nextSoundscapeUrl != null && nextSoundscapeUrl.isNotEmpty) {
      await _soundscape.setVolume(_soundscapeTargetVolume);
      await _soundscape.setUrl(nextSoundscapeUrl);
      if (_soundscapeActive) {
        await _soundscape.play();
      }
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
}
