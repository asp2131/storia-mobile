import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

class AudioEngine {
  final AudioPlayer _narration = AudioPlayer();
  final AudioPlayer _soundscape = AudioPlayer();

  bool _initialized = false;
  Timer? _crossfadeTimer;
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

    _soundscape.setLoopMode(LoopMode.one);
    await _soundscape.setVolume(_soundscapeTargetVolume);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Helpers — just_audio_background requires MediaItem tags on every source.
  // ---------------------------------------------------------------------------

  AudioSource _taggedSource(String url, {required String title}) {
    return AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: url,
        title: title,
      ),
    );
  }

  Future<void> _loadUrl(AudioPlayer player, String url,
      {required String title}) async {
    await player.setAudioSource(_taggedSource(url, title: title));
  }

  // ---------------------------------------------------------------------------
  // Page loading
  // ---------------------------------------------------------------------------

  Future<void> loadPage(PageData page) async {
    await ensureInitialized();

    final futures = <Future<void>>[];

    if (page.narrationUrl != null && page.narrationUrl!.isNotEmpty) {
      futures.add(
        _loadUrl(_narration, page.narrationUrl!, title: 'Narration'),
      );
    } else {
      futures.add(_narration.stop());
    }

    if (page.soundscapeUrl != null && page.soundscapeUrl!.isNotEmpty) {
      futures.add(
        _loadUrl(_soundscape, page.soundscapeUrl!, title: 'Soundscape'),
      );
      _currentSoundscapeUrl = page.soundscapeUrl;
    } else {
      futures.add(_soundscape.stop());
      _currentSoundscapeUrl = null;
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

    // --- Narration transition ---
    if (nextNarrationUrl != null && nextNarrationUrl.isNotEmpty) {
      await _narration.stop();
      await _loadUrl(_narration, nextNarrationUrl, title: 'Narration');
      if (_narrationActive) {
        await _narration.play();
      }
    } else {
      await _narration.stop();
    }

    // --- Soundscape transition ---
    if (nextSoundscapeUrl == null || nextSoundscapeUrl.isEmpty) {
      await _soundscape.stop();
      _currentSoundscapeUrl = null;
      return;
    }

    // Same soundscape – keep playing, nothing to do.
    if (_currentSoundscapeUrl == nextSoundscapeUrl) {
      return;
    }

    // Different soundscape – crossfade.
    _crossfadeTimer?.cancel();
    await _soundscape.setVolume(0);
    await _loadUrl(_soundscape, nextSoundscapeUrl, title: 'Soundscape');
    _currentSoundscapeUrl = nextSoundscapeUrl;

    if (_soundscapeActive) {
      await _soundscape.play();

      const steps = 15;
      const duration = Duration(milliseconds: 1500);
      final targetVolume = _soundscapeTargetVolume;
      final tick = duration ~/ steps;
      var currentStep = 0;

      _crossfadeTimer = Timer.periodic(tick, (timer) async {
        currentStep += 1;
        final progress = currentStep / steps;
        await _soundscape.setVolume(targetVolume * progress);
        if (currentStep >= steps) {
          timer.cancel();
        }
      });
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
    _crossfadeTimer?.cancel();
    await _narration.dispose();
    await _soundscape.dispose();
  }
}
