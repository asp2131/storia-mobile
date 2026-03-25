import '../../../../data/models.dart';

abstract interface class AudioPort {
  Stream<Duration> get narrationPosition;
  Stream<bool> get narrationPlaying;
  Stream<bool> get soundscapePlaying;

  Future<void> ensureInitialized();
  Future<void> loadPage(PageData page);
  Future<void> transitionToPage(PageData page);
  Future<void> toggleNarration();
  Future<void> toggleSoundscape();
  Future<void> setNarrationVolume(double volume);
  Future<void> setSoundscapeVolume(double volume);
  Future<void> dispose();
}
