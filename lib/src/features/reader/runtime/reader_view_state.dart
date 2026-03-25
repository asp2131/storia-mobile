import 'package:flutter/foundation.dart';

@immutable
class ReaderViewState {
  const ReaderViewState({
    required this.isReady,
    required this.activePageIndex,
    required this.narrationPosition,
    required this.isNarrationPlaying,
    required this.isSoundscapePlaying,
    required this.narrationVolume,
    required this.soundscapeVolume,
    required this.isPracticeMode,
    required this.isListening,
    required this.spokenWordIndices,
    required this.showCelebration,
  });

  const ReaderViewState.initial()
    : isReady = false,
      activePageIndex = 0,
      narrationPosition = Duration.zero,
      isNarrationPlaying = false,
      isSoundscapePlaying = false,
      narrationVolume = 1.0,
      soundscapeVolume = 0.6,
      isPracticeMode = false,
      isListening = false,
      spokenWordIndices = const {},
      showCelebration = false;

  final bool isReady;
  final int activePageIndex;
  final Duration narrationPosition;
  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final double narrationVolume;
  final double soundscapeVolume;
  final bool isPracticeMode;
  final bool isListening;
  final Set<int> spokenWordIndices;
  final bool showCelebration;

  ReaderViewState copyWith({
    bool? isReady,
    int? activePageIndex,
    Duration? narrationPosition,
    bool? isNarrationPlaying,
    bool? isSoundscapePlaying,
    double? narrationVolume,
    double? soundscapeVolume,
    bool? isPracticeMode,
    bool? isListening,
    Set<int>? spokenWordIndices,
    bool? showCelebration,
  }) {
    return ReaderViewState(
      isReady: isReady ?? this.isReady,
      activePageIndex: activePageIndex ?? this.activePageIndex,
      narrationPosition: narrationPosition ?? this.narrationPosition,
      isNarrationPlaying: isNarrationPlaying ?? this.isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying ?? this.isSoundscapePlaying,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      soundscapeVolume: soundscapeVolume ?? this.soundscapeVolume,
      isPracticeMode: isPracticeMode ?? this.isPracticeMode,
      isListening: isListening ?? this.isListening,
      spokenWordIndices: spokenWordIndices ?? this.spokenWordIndices,
      showCelebration: showCelebration ?? this.showCelebration,
    );
  }
}
