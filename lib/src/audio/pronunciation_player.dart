abstract interface class PronunciationPlayer {
  Future<void> play(List<String> urls);
  Future<void> stop();
  Stream<Duration> get position;
  Stream<bool> get playing;
}
