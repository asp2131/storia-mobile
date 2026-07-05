import '../../../audio/sfx_bus.dart';

abstract interface class ReaderExperienceEffects {
  Future<void> playPageChange();
  Future<void> playWordTap();
  Future<void> playCelebration();
  Future<void> stopCelebration();
  void dispose();
}

class SfxReaderExperienceEffects implements ReaderExperienceEffects {
  const SfxReaderExperienceEffects(this._sfxBus);

  final SfxBus _sfxBus;

  @override
  Future<void> playPageChange() => _sfxBus.pageChange();

  @override
  Future<void> playWordTap() => _sfxBus.wordTap();

  @override
  Future<void> playCelebration() => _sfxBus.celebration();

  @override
  Future<void> stopCelebration() async {}

  @override
  void dispose() {}
}

class NoopReaderExperienceEffects implements ReaderExperienceEffects {
  const NoopReaderExperienceEffects();

  @override
  Future<void> playPageChange() async {}

  @override
  Future<void> playWordTap() async {}

  @override
  Future<void> playCelebration() async {}

  @override
  Future<void> stopCelebration() async {}

  @override
  void dispose() {}
}
