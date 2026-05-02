import 'dart:async';

import '../../../../data/pronunciation_models.dart';
import '../../pronunciation_highlight.dart';
import '../internal/word_normalizer.dart';
import 'reader_word_help.dart';

const int _fallbackPartDurationMs = 650;
const int _timedHighlightGraceMs = 350;
const int _minPartDurationMs = 100;

class ReaderWordHelpEngine implements ReaderWordHelp {
  ReaderWordHelpEngine({
    required PronunciationManifestPort manifestPort,
    required PronunciationAudioPort pronunciationAudio,
    required FallbackSpeechPort fallbackSpeech,
    required ReaderAudioGuardPort readerAudioGuard,
    required WordHelpAnalyticsPort analytics,
    WordNormalizerPort? normalizer,
    WordHelpSchedulerPort? scheduler,
  }) : _manifestPort = manifestPort,
       _pronunciationAudio = pronunciationAudio,
       _fallbackSpeech = fallbackSpeech,
       _readerAudioGuard = readerAudioGuard,
       _analytics = analytics,
       _normalizer = normalizer ?? const DefaultWordNormalizerPort() {
    _pageChangeSubscription = _readerAudioGuard.pageChanges.listen((_) {
      unawaited(cancel(reason: WordHelpCancelReason.pageChanged));
    });
  }

  final PronunciationManifestPort _manifestPort;
  final PronunciationAudioPort _pronunciationAudio;
  final FallbackSpeechPort _fallbackSpeech;
  final ReaderAudioGuardPort _readerAudioGuard;
  final WordHelpAnalyticsPort _analytics;
  final WordNormalizerPort _normalizer;

  final _snapshots = StreamController<WordHelpSnapshot>.broadcast();
  StreamSubscription<int>? _pageChangeSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  WordHelpSnapshot _snapshot = const WordHelpSnapshot.idle();
  int _lastPronunciationPositionMs = 0;
  int _requestId = 0;
  bool _breakdownFinished = false;
  bool _disposed = false;

  @override
  WordHelpSnapshot get snapshot => _snapshot;

  @override
  Stream<WordHelpSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _snapshots.stream;
  }

  @override
  Future<WordHelpResult> play(WordHelpRequest request) async {
    final requestId = ++_requestId;
    ReaderAudioSnapshot? captured;
    _emit(
      WordHelpSnapshot(
        phase: WordHelpPhase.resolvingManifest,
        activeWordIndex: request.wordIndex,
      ),
    );

    try {
      final normalized = _normalizer.normalize(request.rawWord);
      if (!_isCurrent(requestId) || normalized == null) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      final manifest = await _manifestPort.getManifest(request.bookId);
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      final pronunciation = manifest?.lookup(normalized);
      final urls = _urlsFor(request.mode, pronunciation);
      _emit(_snapshot.copyWith(phase: WordHelpPhase.pausingReaderAudio));
      captured = await _readerAudioGuard.captureAndPause();
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }

      if (urls.isNotEmpty) {
        _emit(_snapshot.copyWith(phase: WordHelpPhase.playingPronunciation));
        _startHighlightTracking(request.wordIndex, pronunciation);
        try {
          await _pronunciationAudio.playSequence(urls);
          if (!_isCurrent(requestId)) {
            return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
          }
          _recordAnalytics(
            wordIndex: request.wordIndex,
            mode: request.mode,
            outcome: WordHelpOutcome.pronunciationPlayed,
          );
          return const WordHelpResult(
            outcome: WordHelpOutcome.pronunciationPlayed,
          );
        } catch (_) {
          if (!_isCurrent(requestId)) {
            return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
          }
          await _stopPronunciationSafely();
          _stopHighlightTracking();
        }
      }

      _emit(_snapshot.copyWith(phase: WordHelpPhase.playingFallbackTts));
      await _playFallback(request);
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }
      _recordAnalytics(
        wordIndex: request.wordIndex,
        mode: request.mode,
        outcome: WordHelpOutcome.fallbackPlayed,
      );
      return const WordHelpResult(outcome: WordHelpOutcome.fallbackPlayed);
    } catch (error) {
      if (!_isCurrent(requestId)) {
        return const WordHelpResult(outcome: WordHelpOutcome.cancelled);
      }
      _emit(_snapshot.copyWith(phase: WordHelpPhase.failed));
      _recordAnalytics(
        wordIndex: request.wordIndex,
        mode: request.mode,
        outcome: WordHelpOutcome.failed,
      );
      return WordHelpResult(outcome: WordHelpOutcome.failed, error: error);
    } finally {
      if (_isCurrent(requestId)) {
        if (captured != null) {
          _emit(_snapshot.copyWith(phase: WordHelpPhase.restoringReaderAudio));
          await _readerAudioGuard.restore(captured);
        }
        _stopHighlightTracking();
        _emit(const WordHelpSnapshot.idle());
      }
    }
  }

  List<String> _urlsFor(WordHelpMode mode, WordPronunciation? pronunciation) {
    if (pronunciation == null) {
      return const [];
    }

    final breakdownUrl = pronunciation.breakdown?.url;
    final fullWordUrl = pronunciation.fullWord?.url;
    return switch (mode) {
      WordHelpMode.word =>
        fullWordUrl == null || fullWordUrl.isEmpty ? const [] : [fullWordUrl],
      WordHelpMode.breakdown => [
        if (breakdownUrl != null && breakdownUrl.isNotEmpty) breakdownUrl,
        if (fullWordUrl != null && fullWordUrl.isNotEmpty) fullWordUrl,
      ],
    };
  }

  Future<void> _playFallback(WordHelpRequest request) {
    return switch (request.mode) {
      WordHelpMode.word => _fallbackSpeech.speakWord(request.rawWord),
      WordHelpMode.breakdown => _fallbackSpeech.speakBreakdown(request.rawWord),
    };
  }

  void _startHighlightTracking(
    int wordIndex,
    WordPronunciation? pronunciation,
  ) {
    final parts = _buildHighlightParts(pronunciation);
    if (parts.isEmpty) {
      _emit(_snapshot.copyWith(activeWordIndex: wordIndex));
      return;
    }

    _lastPronunciationPositionMs = 0;
    _breakdownFinished = false;
    _emit(
      _snapshot.copyWith(
        activeWordIndex: wordIndex,
        highlightParts: parts,
        activeHighlightPartIndex: 0,
      ),
    );

    unawaited(_positionSubscription?.cancel());
    _positionSubscription = _pronunciationAudio.position.listen((position) {
      if (_snapshot.activeWordIndex != wordIndex ||
          _snapshot.highlightParts.isEmpty ||
          _breakdownFinished) {
        return;
      }

      final positionMs = position.inMilliseconds;
      final resetToNextClip = positionMs + 100 < _lastPronunciationPositionMs;
      _lastPronunciationPositionMs = positionMs;

      if (resetToNextClip) {
        _breakdownFinished = true;
        _emit(
          _snapshot.copyWith(
            highlightParts: const [],
            activeHighlightPartIndex: null,
          ),
        );
        return;
      }

      final activeIndex = _activeHighlightPartIndexFor(
        positionMs,
        _snapshot.highlightParts,
      );
      if (_snapshot.activeHighlightPartIndex != activeIndex) {
        _emit(_snapshot.copyWith(activeHighlightPartIndex: activeIndex));
      }
    });
  }

  List<PronunciationHighlightPart> _buildHighlightParts(
    WordPronunciation? pronunciation,
  ) {
    if (pronunciation == null || pronunciation.breakdown == null) {
      return const [];
    }

    final labels = pronunciation.syllables
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final fallbackLabels = pronunciation.breakdownSegments
        .map(
          (segment) => segment.chunk.trim().isNotEmpty
              ? segment.chunk.trim()
              : segment.spoken.trim(),
        )
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final effectiveLabels = labels.isNotEmpty ? labels : fallbackLabels;
    if (effectiveLabels.isEmpty) {
      return const [];
    }

    final timedSegments = pronunciation.breakdownSegments;
    final totalDurationMs =
        pronunciation.breakdown?.durationMs ??
        _inferTotalDurationFromSegments(timedSegments) ??
        effectiveLabels.length * _fallbackPartDurationMs;

    return [
      for (var i = 0; i < effectiveLabels.length; i++)
        PronunciationHighlightPart(
          text: effectiveLabels[i],
          startMs: _startMsForPart(
            i,
            effectiveLabels.length,
            timedSegments,
            totalDurationMs,
          ),
          endMs: _endMsForPart(
            i,
            effectiveLabels.length,
            timedSegments,
            totalDurationMs,
          ),
        ),
    ];
  }

  int? _inferTotalDurationFromSegments(
    List<PronunciationBreakdownSegment> segments,
  ) {
    final ends = segments
        .map((s) => s.endMs)
        .whereType<int>()
        .toList(growable: false);
    if (ends.isEmpty) {
      return null;
    }
    return ends.reduce((a, b) => a > b ? a : b);
  }

  int _startMsForPart(
    int index,
    int partCount,
    List<PronunciationBreakdownSegment> segments,
    int totalDurationMs,
  ) {
    if (segments.length == partCount && segments[index].startMs != null) {
      return segments[index].startMs!;
    }
    return ((totalDurationMs * index) / partCount).round();
  }

  int _endMsForPart(
    int index,
    int partCount,
    List<PronunciationBreakdownSegment> segments,
    int totalDurationMs,
  ) {
    if (segments.length == partCount && segments[index].endMs != null) {
      final start = _startMsForPart(
        index,
        partCount,
        segments,
        totalDurationMs,
      );
      final end = segments[index].endMs!;
      return end > start ? end : start + _minPartDurationMs;
    }
    return ((totalDurationMs * (index + 1)) / partCount).round();
  }

  int? _activeHighlightPartIndexFor(
    int positionMs,
    List<PronunciationHighlightPart> parts,
  ) {
    final timedEnds = parts
        .map((part) => part.endMs)
        .whereType<int>()
        .toList(growable: false);
    if (timedEnds.isNotEmpty) {
      final lastEnd = timedEnds.reduce((a, b) => a > b ? a : b);
      if (positionMs > lastEnd + _timedHighlightGraceMs) {
        return null;
      }
    }

    var latestStarted = 0;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final start = part.startMs;
      final end = part.endMs;
      if (start == null || end == null) {
        continue;
      }
      if (positionMs >= start && positionMs <= end) {
        return i;
      }
      if (positionMs >= start) {
        latestStarted = i;
      }
      if (positionMs < start) {
        return latestStarted;
      }
    }
    return latestStarted;
  }

  void _stopHighlightTracking() {
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _lastPronunciationPositionMs = 0;
    _breakdownFinished = false;
  }

  Future<void> _stopPronunciationSafely() async {
    try {
      await _pronunciationAudio.stop();
    } catch (_) {}
  }

  void _recordAnalytics({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  }) {
    try {
      _analytics.recordWordHelp(
        wordIndex: wordIndex,
        mode: mode,
        outcome: outcome,
      );
    } catch (_) {}
  }

  bool _isCurrent(int requestId) => !_disposed && requestId == _requestId;

  void _emit(WordHelpSnapshot next) {
    _snapshot = next;
    if (!_snapshots.isClosed) {
      _snapshots.add(next);
    }
  }

  @override
  Future<void> cancel({required WordHelpCancelReason reason}) async {
    _requestId++;
    _stopHighlightTracking();
    await _pronunciationAudio.stop();
    await _fallbackSpeech.stop();
    if (reason == WordHelpCancelReason.disposed) {
      _emit(const WordHelpSnapshot.idle());
      return;
    }
    _emit(const WordHelpSnapshot(phase: WordHelpPhase.cancelled));
    _emit(const WordHelpSnapshot.idle());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pageChangeSubscription?.cancel();
    _stopHighlightTracking();
    await cancel(reason: WordHelpCancelReason.disposed);
    await _snapshots.close();
  }
}

class DefaultWordNormalizerPort implements WordNormalizerPort {
  const DefaultWordNormalizerPort();

  @override
  String? normalize(String rawWord) => normalizeWordToken(rawWord);
}
