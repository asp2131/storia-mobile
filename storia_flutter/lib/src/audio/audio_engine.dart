import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models.dart';

class AudioEngine {
  final AudioPlayer _narration = AudioPlayer();
  final AudioPlayer _soundscape = AudioPlayer();

  bool _initialized = false;
  Timer? _crossfadeTimer;
  String? _currentSoundscapeUrl;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _soundscape.setLoopMode(LoopMode.one);
    await _soundscape.setVolume(0.6);

    _initialized = true;
  }

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
      _currentSoundscapeUrl = page.soundscapeUrl;
    } else {
      futures.add(_soundscape.stop());
      _currentSoundscapeUrl = null;
    }

    await Future.wait(futures);
  }

  Future<void> play() async {
    await ensureInitialized();
    await Future.wait([_narration.play(), _soundscape.play()]);
  }

  Future<void> pause() async {
    await Future.wait([_narration.pause(), _soundscape.pause()]);
  }

  Future<void> transitionToPage(PageData nextPage) async {
    await ensureInitialized();

    final nextSoundscapeUrl = nextPage.soundscapeUrl;

    if (nextSoundscapeUrl == null || nextSoundscapeUrl.isEmpty) {
      await _soundscape.stop();
      await _narration.stop();
      _currentSoundscapeUrl = null;
      return;
    }

    if (_currentSoundscapeUrl == nextSoundscapeUrl) {
      if (nextPage.narrationUrl != null && nextPage.narrationUrl!.isNotEmpty) {
        await _narration.setUrl(nextPage.narrationUrl!);
        await _narration.play();
      }
      return;
    }

    _crossfadeTimer?.cancel();
    await _soundscape.setVolume(0);
    await loadPage(nextPage);
    await _soundscape.play();
    await _narration.play();

    const steps = 15;
    const duration = Duration(milliseconds: 1500);
    const targetVolume = 0.6;
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

  Stream<Duration> get narrationPosition => _narration.positionStream;
  Stream<bool> get narrationPlaying => _narration.playingStream;

  Future<void> setNarrationVolume(double volume) =>
      _narration.setVolume(volume);
  Future<void> setSoundscapeVolume(double volume) =>
      _soundscape.setVolume(volume);

  Future<void> dispose() async {
    _crossfadeTimer?.cancel();
    await _narration.dispose();
    await _soundscape.dispose();
  }
}
