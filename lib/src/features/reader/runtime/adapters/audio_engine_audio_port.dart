import '../../../../audio/audio_engine.dart';
import '../../../../data/models.dart';
import '../ports/audio_port.dart';

class AudioEngineAudioPort implements AudioPort {
  AudioEngineAudioPort(this._engine);

  final AudioEngine _engine;

  @override
  Stream<Duration> get narrationPosition => _engine.narrationPosition;

  @override
  Stream<bool> get narrationPlaying => _engine.narrationPlaying;

  @override
  Stream<bool> get soundscapePlaying => _engine.soundscapePlaying;

  @override
  Future<void> ensureInitialized() => _engine.ensureInitialized();

  @override
  Future<void> loadPage(PageData page) => _engine.loadPage(page);

  @override
  Future<void> transitionToPage(PageData page) => _engine.transitionToPage(page);

  @override
  Future<void> toggleNarration() => _engine.toggleNarration();

  @override
  Future<void> toggleSoundscape() => _engine.toggleSoundscape();

  @override
  Future<void> setNarrationVolume(double volume) =>
      _engine.setNarrationVolume(volume);

  @override
  Future<void> setSoundscapeVolume(double volume) =>
      _engine.setSoundscapeVolume(volume);

  @override
  Future<void> dispose() async {
    // Owned by audioEngineProvider lifecycle.
  }
}
