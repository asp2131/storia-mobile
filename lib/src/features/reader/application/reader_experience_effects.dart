abstract interface class ReaderExperienceEffects {
  Future<void> playCelebration();
  Future<void> stopCelebration();
  void dispose();
}

class NoopReaderExperienceEffects implements ReaderExperienceEffects {
  const NoopReaderExperienceEffects();

  @override
  Future<void> playCelebration() async {}

  @override
  Future<void> stopCelebration() async {}

  @override
  void dispose() {}
}
