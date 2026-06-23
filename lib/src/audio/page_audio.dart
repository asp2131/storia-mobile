import 'dart:async';

import '../data/models.dart';

class AudioSnapshot {
  const AudioSnapshot({
    this.isNarrationPlaying = false,
    this.isSoundscapePlaying = false,
    this.narrationPosition = Duration.zero,
  });

  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final Duration narrationPosition;

  static const Object _sentinel = Object();

  AudioSnapshot copyWith({
    Object? isNarrationPlaying = _sentinel,
    Object? isSoundscapePlaying = _sentinel,
    Object? narrationPosition = _sentinel,
  }) {
    return AudioSnapshot(
      isNarrationPlaying: identical(isNarrationPlaying, _sentinel)
          ? this.isNarrationPlaying
          : isNarrationPlaying as bool,
      isSoundscapePlaying: identical(isSoundscapePlaying, _sentinel)
          ? this.isSoundscapePlaying
          : isSoundscapePlaying as bool,
      narrationPosition: identical(narrationPosition, _sentinel)
          ? this.narrationPosition
          : narrationPosition as Duration,
    );
  }
}

abstract interface class PageAudio {
  Future<void> loadPage(PageData page);
  Future<void> toggleNarration();
  Future<void> toggleSoundscape();
  Future<void> setNarrationVolume(double volume);
  Future<void> setSoundscapeVolume(double volume);
  Future<void> duckForPractice();
  Future<void> restoreFromPractice();

  /// Stops narration and soundscape immediately. Called when the reader
  /// screen unmounts so audio doesn't bleed into the next screen.
  Future<void> stopAll();

  Stream<AudioSnapshot> get states;
}
