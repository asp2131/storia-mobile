import '../../../../audio/pronunciation_player.dart';
import '../../../../data/pronunciation_models.dart';
import '../../pronunciation_highlight.dart';

abstract interface class ReaderWordHelp {
  WordHelpSnapshot get snapshot;
  Stream<WordHelpSnapshot> get snapshots;

  Future<WordHelpResult> play(WordHelpRequest request);

  Future<void> cancel({required WordHelpCancelReason reason});

  Future<void> dispose();
}

enum WordHelpMode { word, breakdown }

class WordHelpRequest {
  const WordHelpRequest({
    required this.bookId,
    required this.pageIndex,
    required this.wordIndex,
    required this.rawWord,
    required this.mode,
  });

  final String bookId;
  final int pageIndex;
  final int wordIndex;
  final String rawWord;
  final WordHelpMode mode;
}

enum WordHelpPhase {
  idle,
  resolvingManifest,
  pausingReaderAudio,
  playingPronunciation,
  playingFallbackTts,
  restoringReaderAudio,
  cancelled,
  failed,
}

class WordHelpSnapshot {
  const WordHelpSnapshot({
    required this.phase,
    this.activeWordIndex,
    this.highlightParts = const [],
    this.activeHighlightPartIndex,
  });

  const WordHelpSnapshot.idle()
    : phase = WordHelpPhase.idle,
      activeWordIndex = null,
      highlightParts = const [],
      activeHighlightPartIndex = null;

  final WordHelpPhase phase;
  final int? activeWordIndex;
  final List<PronunciationHighlightPart> highlightParts;
  final int? activeHighlightPartIndex;

  WordHelpSnapshot copyWith({
    WordHelpPhase? phase,
    Object? activeWordIndex = _sentinel,
    List<PronunciationHighlightPart>? highlightParts,
    Object? activeHighlightPartIndex = _sentinel,
  }) {
    return WordHelpSnapshot(
      phase: phase ?? this.phase,
      activeWordIndex: activeWordIndex == _sentinel
          ? this.activeWordIndex
          : activeWordIndex as int?,
      highlightParts: highlightParts ?? this.highlightParts,
      activeHighlightPartIndex: activeHighlightPartIndex == _sentinel
          ? this.activeHighlightPartIndex
          : activeHighlightPartIndex as int?,
    );
  }
}

const Object _sentinel = Object();

enum WordHelpOutcome { pronunciationPlayed, fallbackPlayed, cancelled, failed }

class WordHelpResult {
  const WordHelpResult({required this.outcome, this.error});

  final WordHelpOutcome outcome;
  final Object? error;
}

enum WordHelpCancelReason { user, pageChanged, superseded, disposed }

class ReaderAudioSnapshot {
  const ReaderAudioSnapshot({
    required this.wasNarrationPlaying,
    required this.wasListening,
  });

  final bool wasNarrationPlaying;
  final bool wasListening;
}

abstract interface class PronunciationManifestPort {
  Future<BookPronunciationManifest?> getManifest(String bookId);
}

typedef PronunciationAudioPort = PronunciationPlayer;

abstract interface class FallbackSpeechPort {
  Future<void> speakWord(String word);
  Future<void> speakBreakdown(String word);
  Future<void> stop();
}

abstract interface class ReaderAudioGuardPort {
  Future<ReaderAudioSnapshot> captureAndPause();
  Future<void> restore(ReaderAudioSnapshot snapshot);
  Stream<int> get pageChanges;
}

abstract interface class WordHelpAnalyticsPort {
  void recordWordHelp({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  });
}

abstract interface class WordNormalizerPort {
  String? normalize(String rawWord);
}

abstract interface class WordHelpSchedulerPort {
  void scheduleMicrotask(void Function() callback);
}
