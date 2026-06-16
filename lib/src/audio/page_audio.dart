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

  AudioSnapshot copyWith({
    bool? isNarrationPlaying,
    bool? isSoundscapePlaying,
    Duration? narrationPosition,
  }) {
    return AudioSnapshot(
      isNarrationPlaying: isNarrationPlaying ?? this.isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying ?? this.isSoundscapePlaying,
      narrationPosition: narrationPosition ?? this.narrationPosition,
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
  Stream<AudioSnapshot> get states;
}
