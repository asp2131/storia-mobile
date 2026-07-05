import 'package:flutter_soloud/flutter_soloud.dart';

enum SfxCue { pageChange, wordTap, celebration }

class SfxBus {
  SfxBus({SfxBackend? backend}) : _backend = backend ?? SoLoudSfxBackend();

  final SfxBackend _backend;
  bool _disabled = false;

  Future<void> pageChange() => _play(SfxCue.pageChange);
  Future<void> wordTap() => _play(SfxCue.wordTap);
  Future<void> celebration() => _play(SfxCue.celebration);

  Future<void> _play(SfxCue cue) async {
    if (_disabled) return;
    try {
      await _backend.play(cue);
    } catch (_) {
      _disabled = true;
    }
  }

  Future<void> dispose() async {
    try {
      await _backend.dispose();
    } catch (_) {
      // SFX is optional; teardown must never crash reader disposal.
    }
  }
}

abstract interface class SfxBackend {
  Future<void> play(SfxCue cue);
  Future<void> dispose();
}

class SoLoudSfxBackend implements SfxBackend {
  final SoLoud _soloud = SoLoud.instance;
  final Map<SfxCue, AudioSource> _sources = {};

  @override
  Future<void> play(SfxCue cue) async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    final source = _sources[cue] ??= await _soloud.loadAsset(cue.assetPath);
    await _soloud.play(source, volume: cue.volume);
  }

  @override
  Future<void> dispose() async {
    if (!_soloud.isInitialized) return;
    await _soloud.disposeAllSources();
    _sources.clear();
    _soloud.deinit();
  }
}

extension on SfxCue {
  String get assetPath => switch (this) {
    SfxCue.pageChange => 'assets/audio/sfx/page_turn.wav',
    SfxCue.wordTap => 'assets/audio/sfx/word_tap.wav',
    SfxCue.celebration => 'assets/audio/sfx/celebration.wav',
  };

  double get volume => switch (this) {
    SfxCue.pageChange => 0.22,
    SfxCue.wordTap => 0.16,
    SfxCue.celebration => 0.32,
  };
}
