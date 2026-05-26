import 'package:flutter/foundation.dart';

import '../../../data/models.dart';

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

sealed class ReaderIntent {
  const ReaderIntent();
}

final class ReaderStart extends ReaderIntent {
  const ReaderStart({required this.book, this.initialPageIndex = 0});

  final Book book;
  final int initialPageIndex;
}

final class ReaderGoToPage extends ReaderIntent {
  const ReaderGoToPage(this.pageIndex);

  final int pageIndex;
}

enum ReaderIntentSource { user, runtime }

final class ReaderToggleNarration extends ReaderIntent {
  const ReaderToggleNarration({this.source = ReaderIntentSource.user});

  final ReaderIntentSource source;
}

final class ReaderToggleSoundscape extends ReaderIntent {
  const ReaderToggleSoundscape({this.source = ReaderIntentSource.user});

  final ReaderIntentSource source;
}

final class ReaderSetNarrationVolume extends ReaderIntent {
  const ReaderSetNarrationVolume(this.volume);

  final double volume;
}

final class ReaderSetSoundscapeVolume extends ReaderIntent {
  const ReaderSetSoundscapeVolume(this.volume);

  final double volume;
}

/// Primary CTA behavior in Reader top bar:
/// - If practice mode is off: enable practice and start listening.
/// - If practice mode is on and listening: stop listening.
/// - If practice mode is on and idle: start listening.
final class ReaderPracticePrimaryAction extends ReaderIntent {
  const ReaderPracticePrimaryAction();
}

final class ReaderPauseListening extends ReaderIntent {
  const ReaderPauseListening();
}

final class ReaderResumeListening extends ReaderIntent {
  const ReaderResumeListening();
}

final class ReaderPauseNarration extends ReaderIntent {
  const ReaderPauseNarration();
}

final class ReaderResumeNarration extends ReaderIntent {
  const ReaderResumeNarration();
}

final class ReaderAckCelebration extends ReaderIntent {
  const ReaderAckCelebration();
}

final class ReaderEnd extends ReaderIntent {
  const ReaderEnd({this.reason = 'dispose'});

  final String reason;
}

abstract interface class ReaderSession {
  Stream<ReaderViewState> get states;

  /// Emits the active page index whenever the reader transitions to a new
  /// page. Useful for cancelling per-page work (e.g. pronunciation playback).
  Stream<int> get pageChanges;

  Future<void> dispatch(ReaderIntent intent);

  Future<void> dispose();
}
