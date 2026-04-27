import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/pronunciation_models.dart';
import '../../../../data/providers.dart';
import '../../pronunciation_highlight.dart';
import '../reader_session.dart';
import '../reader_intent.dart';
import '../reader_view_state.dart';
import '../services/pronunciation_playback_service.dart';
import '../services/word_tts_service.dart';
import 'reader_session_provider.dart';

class WordTtsState {
  const WordTtsState({
    this.tappedWordIndex,
    this.highlightParts = const [],
    this.activeHighlightPartIndex,
  });

  final int? tappedWordIndex;
  final List<PronunciationHighlightPart> highlightParts;
  final int? activeHighlightPartIndex;

  WordTtsState copyWith({
    int? tappedWordIndex,
    List<PronunciationHighlightPart>? highlightParts,
    Object? activeHighlightPartIndex = _sentinel,
  }) {
    return WordTtsState(
      tappedWordIndex: tappedWordIndex ?? this.tappedWordIndex,
      highlightParts: highlightParts ?? this.highlightParts,
      activeHighlightPartIndex: activeHighlightPartIndex == _sentinel
          ? this.activeHighlightPartIndex
          : activeHighlightPartIndex as int?,
    );
  }
}

const Object _sentinel = Object();

final wordTtsServiceProvider = Provider<WordTtsService>((ref) {
  final service = WordTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pronunciationPlaybackServiceProvider =
    Provider<PronunciationPlaybackService>((ref) {
      final audioEngine = ref.watch(audioEngineProvider);
      final repository = ref.watch(pronunciationRepositoryProvider);
      return PronunciationPlaybackService(
        audioEngine: audioEngine,
        repository: repository,
      );
    });

final wordTtsProvider = StateNotifierProvider<WordTtsNotifier, WordTtsState>((
  ref,
) {
  final service = ref.watch(wordTtsServiceProvider);
  final pronunciation = ref.watch(pronunciationPlaybackServiceProvider);
  final session = ref.watch(readerSessionProvider);
  return WordTtsNotifier(
    service: service,
    pronunciation: pronunciation,
    session: session,
  );
});

class WordTtsNotifier extends StateNotifier<WordTtsState> {
  static const int _fallbackPartDurationMs = 650;
  static const int _timedHighlightGraceMs = 350;
  static const int _minPartDurationMs = 100;

  WordTtsNotifier({
    required WordTtsService service,
    required PronunciationPlaybackService pronunciation,
    required ReaderSession session,
  }) : _service = service,
       _pronunciation = pronunciation,
       _session = session,
       super(const WordTtsState()) {
    _pageChangeSubscription = session.pageChanges.listen((_) {
      _onPageChanged();
    });
  }

  final WordTtsService _service;
  final PronunciationPlaybackService _pronunciation;
  final ReaderSession _session;

  bool _wasNarrationPlaying = false;
  bool _wasListening = false;
  StreamSubscription<ReaderViewState>? _stateSubscription;
  StreamSubscription<int>? _pageChangeSubscription;
  StreamSubscription<Duration>? _pronunciationPositionSubscription;
  ReaderViewState _lastState = const ReaderViewState.initial();

  /// Monotonically increasing identifier for the in-flight long-press flow.
  /// Used to drop stale completions after page-change / cancel-and-replace.
  int _flowId = 0;

  /// Set when the user toggles narration / practice mid-flow. Suppresses the
  /// auto-resume step.
  bool _userOverride = false;

  /// State streams are broadcast asynchronously. These counters suppress the
  /// exact transitions caused by our own pause/restore dispatches even when the
  /// state event arrives after the dispatch future completes.
  int _expectedNarrationTransitions = 0;
  int _expectedListeningTransitions = 0;

  /// `true` between `capturing` and `restoring` phases of an active long-press.
  bool _flowActive = false;

  int _lastPronunciationPositionMs = 0;
  bool _pronunciationBreakdownFinished = false;

  String _bookId = '';

  void attachStateStream(Stream<ReaderViewState> states) {
    _stateSubscription?.cancel();
    _stateSubscription = states.listen(_onStateChanged);
  }

  void setBookId(String bookId) {
    _bookId = bookId;
  }

  void _onStateChanged(ReaderViewState next) {
    final previous = _lastState;
    _lastState = next;

    if (!_flowActive) {
      return;
    }

    final narrationToggled =
        previous.isNarrationPlaying != next.isNarrationPlaying;
    final listeningToggled = previous.isListening != next.isListening;
    var unexpectedUserToggle = false;

    if (narrationToggled) {
      if (_expectedNarrationTransitions > 0) {
        _expectedNarrationTransitions--;
      } else {
        unexpectedUserToggle = true;
      }
    }

    if (listeningToggled) {
      if (_expectedListeningTransitions > 0) {
        _expectedListeningTransitions--;
      } else {
        unexpectedUserToggle = true;
      }
    }

    if (unexpectedUserToggle) {
      _userOverride = true;
    }
  }

  Future<void> _onPageChanged() async {
    if (!_flowActive) {
      return;
    }
    await _restoreCapturedAudio();
    _flowId++;
    _flowActive = false;
    _userOverride = true;
    _clearExpectedTransitions();
    _stopPronunciationPositionTracking();
    await _pronunciation.stop();
    await _service.stop();
    if (state.tappedWordIndex != null) {
      state = const WordTtsState();
    }
  }

  /// Tap: manifest-first pronunciation playback (matches web parity).
  /// Pauses narration/mic, plays Supabase breakdown→fullWord clip, falls back
  /// to on-device TTS only when manifest has no entry or playback errors.
  Future<void> onWordTapped(String word, int globalIndex) async {
    final flowId = ++_flowId;
    _flowActive = true;
    _userOverride = false;
    _clearExpectedTransitions();

    await _service.stop();
    await _pronunciation.stop();
    _stopPronunciationPositionTracking();
    state = WordTtsState(tappedWordIndex: globalIndex);

    try {
      await _captureAndPause();
      if (flowId != _flowId) {
        return;
      }

      final outcome = await _pronunciation.tryPlayBreakdownFor(
        rawWord: word,
        bookId: _bookId,
        onPlaybackReady: (plan) {
          if (flowId == _flowId) {
            _startPronunciationHighlightTracking(globalIndex, plan);
          }
        },
      );
      if (flowId != _flowId) {
        return;
      }

      if (outcome == PronunciationOutcome.fallback ||
          outcome == PronunciationOutcome.error) {
        await _service.speak(word);
      }

      _stopPronunciationPositionTracking();
      if (flowId == _flowId && state.tappedWordIndex == globalIndex) {
        state = const WordTtsState();
      }

      if (flowId == _flowId) {
        await _restoreIfNeeded();
      }
    } finally {
      if (flowId == _flowId) {
        _stopPronunciationPositionTracking();
        await _pronunciation.stop();
        await _service.stop();
        if (state.tappedWordIndex == globalIndex) {
          state = const WordTtsState();
        }
        await _restoreIfNeeded();
        _flowActive = false;
      }
    }
  }

  /// Long-press: try the manifest-backed pronunciation first; fall back to
  /// `soundOut` TTS when there's no entry or audio playback errors.
  Future<void> onWordLongPressed(String word, int globalIndex) async {
    final flowId = ++_flowId;
    _flowActive = true;
    _userOverride = false;
    _clearExpectedTransitions();

    await _service.stop();
    await _pronunciation.stop();
    _stopPronunciationPositionTracking();
    state = WordTtsState(tappedWordIndex: globalIndex);

    try {
      await _captureAndPause();
      if (flowId != _flowId) {
        return;
      }

      final outcome = await _pronunciation.tryPlayBreakdownFor(
        rawWord: word,
        bookId: _bookId,
        onPlaybackReady: (plan) {
          if (flowId == _flowId) {
            _startPronunciationHighlightTracking(globalIndex, plan);
          }
        },
      );
      if (flowId != _flowId) {
        return;
      }

      if (outcome == PronunciationOutcome.fallback ||
          outcome == PronunciationOutcome.error) {
        await _service.soundOut(word);
      }

      _stopPronunciationPositionTracking();
      if (flowId == _flowId && state.tappedWordIndex == globalIndex) {
        state = const WordTtsState();
      }

      if (flowId == _flowId) {
        await _restoreIfNeeded();
      }
    } finally {
      if (flowId == _flowId) {
        _stopPronunciationPositionTracking();
        await _pronunciation.stop();
        await _service.stop();
        if (state.tappedWordIndex == globalIndex) {
          state = const WordTtsState();
        }
        await _restoreIfNeeded();
        _flowActive = false;
      }
    }
  }

  void _startPronunciationHighlightTracking(
    int globalIndex,
    PronunciationPlaybackPlan plan,
  ) {
    if (!plan.includesBreakdown) {
      state = WordTtsState(tappedWordIndex: globalIndex);
      return;
    }

    final parts = _buildHighlightParts(plan);
    if (parts.isEmpty) {
      state = WordTtsState(tappedWordIndex: globalIndex);
      return;
    }

    _lastPronunciationPositionMs = 0;
    _pronunciationBreakdownFinished = false;
    state = WordTtsState(
      tappedWordIndex: globalIndex,
      highlightParts: parts,
      activeHighlightPartIndex: 0,
    );

    _pronunciationPositionSubscription?.cancel();
    _pronunciationPositionSubscription = _pronunciation.pronunciationPosition
        .listen((position) {
          if (state.tappedWordIndex != globalIndex ||
              state.highlightParts.isEmpty ||
              _pronunciationBreakdownFinished) {
            return;
          }
          final positionMs = position.inMilliseconds;
          final resetToNextClip =
              positionMs + 100 < _lastPronunciationPositionMs;
          _lastPronunciationPositionMs = positionMs;

          if (resetToNextClip) {
            _pronunciationBreakdownFinished = true;
            state = WordTtsState(tappedWordIndex: globalIndex);
            return;
          }

          final activeIndex = _activeHighlightPartIndexFor(
            positionMs,
            state.highlightParts,
          );
          _setActiveHighlightPart(activeIndex);
        });
  }

  List<PronunciationHighlightPart> _buildHighlightParts(
    PronunciationPlaybackPlan plan,
  ) {
    final entry = plan.entry;
    final rawSegments = entry.breakdownSegments;
    final syllables = entry.syllables
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final segmentChunks = rawSegments
        .map(
          (s) => s.chunk.trim().isNotEmpty ? s.chunk.trim() : s.spoken.trim(),
        )
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    // Visual highlighting is syllable-first. The rich metadata spec stores
    // orthographic syllables separately from spoken breakdown chunks, and they
    // do not always have a 1:1 count (e.g. "inside" may have syllables
    // ["in", "side"] even if the breakdown timing arrives as one segment).
    final labels = syllables.isNotEmpty ? syllables : segmentChunks;

    if (labels.isEmpty) {
      return const [];
    }

    // Normalize segments so missing startMs is inferred from previous endMs.
    final timedSegments = _normalizeSegments(rawSegments);

    // Prefer the actual audio duration over a hardcoded heuristic.
    final totalDurationMs = entry.breakdown?.durationMs ??
        _inferTotalDurationFromSegments(timedSegments) ??
        labels.length * _fallbackPartDurationMs;

    return [
      for (var i = 0; i < labels.length; i++)
        PronunciationHighlightPart(
          text: labels[i],
          startMs: _startMsForPart(
            index: i,
            partCount: labels.length,
            timedSegments: timedSegments,
            totalDurationMs: totalDurationMs,
          ),
          endMs: _endMsForPart(
            index: i,
            partCount: labels.length,
            timedSegments: timedSegments,
            totalDurationMs: totalDurationMs,
          ),
        ),
    ];
  }

  /// Fills in missing startMs values by chaining from the previous segment's
  /// endMs (or 0 for the first segment). This handles the common case where
  /// the database stores only endMs boundaries.
  List<PronunciationBreakdownSegment> _normalizeSegments(
    List<PronunciationBreakdownSegment> segments,
  ) {
    if (segments.isEmpty) return segments;

    final normalized = <PronunciationBreakdownSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      var start = seg.startMs;
      var end = seg.endMs;

      // Infer startMs from previous segment's endMs or 0.
      if (start == null && end != null) {
        start = i > 0 && normalized[i - 1].endMs != null
            ? normalized[i - 1].endMs
            : 0;
      }

      // Infer endMs from next segment's startMs when available.
      if (end == null && start != null) {
        end = i + 1 < segments.length && segments[i + 1].startMs != null
            ? segments[i + 1].startMs
            : start + _fallbackPartDurationMs;
      }

      normalized.add(
        PronunciationBreakdownSegment(
          index: seg.index,
          chunk: seg.chunk,
          spoken: seg.spoken,
          startMs: start,
          endMs: end,
        ),
      );
    }
    return normalized;
  }

  int? _inferTotalDurationFromSegments(
    List<PronunciationBreakdownSegment> segments,
  ) {
    final ends = segments
        .map((s) => s.endMs)
        .whereType<int>()
        .toList(growable: false);
    if (ends.isEmpty) return null;
    return ends.reduce((a, b) => a > b ? a : b);
  }

  int _startMsForPart({
    required int index,
    required int partCount,
    required List<PronunciationBreakdownSegment> timedSegments,
    required int totalDurationMs,
  }) {
    if (timedSegments.length == partCount &&
        timedSegments[index].startMs != null) {
      return timedSegments[index].startMs!;
    }

    final distributed = _distributedMsForPart(
      index: index,
      partCount: partCount,
      timedSegments: timedSegments,
      totalDurationMs: totalDurationMs,
      isEnd: false,
    );
    return distributed ?? index * (totalDurationMs ~/ partCount);
  }

  int _endMsForPart({
    required int index,
    required int partCount,
    required List<PronunciationBreakdownSegment> timedSegments,
    required int totalDurationMs,
  }) {
    if (timedSegments.length == partCount &&
        timedSegments[index].endMs != null) {
      final end = timedSegments[index].endMs!;
      final start = _startMsForPart(
        index: index,
        partCount: partCount,
        timedSegments: timedSegments,
        totalDurationMs: totalDurationMs,
      );
      // Enforce a minimum duration so zero-length segments don't flash.
      return end > start ? end : start + _minPartDurationMs;
    }

    final distributed = _distributedMsForPart(
      index: index,
      partCount: partCount,
      timedSegments: timedSegments,
      totalDurationMs: totalDurationMs,
      isEnd: true,
    );
    return distributed ?? (index + 1) * (totalDurationMs ~/ partCount);
  }

  int? _distributedMsForPart({
    required int index,
    required int partCount,
    required List<PronunciationBreakdownSegment> timedSegments,
    required int totalDurationMs,
    required bool isEnd,
  }) {
    if (partCount <= 0 || timedSegments.isEmpty) {
      return null;
    }

    // Collect segments that have at least one timing anchor.
    final anchored = timedSegments
        .where((s) => s.startMs != null || s.endMs != null)
        .toList(growable: false);
    if (anchored.isEmpty) {
      return null;
    }

    final starts = anchored
        .map((segment) => segment.startMs)
        .whereType<int>()
        .toList(growable: false);
    final ends = anchored
        .map((segment) => segment.endMs)
        .whereType<int>()
        .toList(growable: false);

    // Use the actual span of timed data, or fall back to the audio duration.
    final start = starts.isNotEmpty
        ? starts.reduce((a, b) => a < b ? a : b)
        : 0;
    final end = ends.isNotEmpty
        ? ends.reduce((a, b) => a > b ? a : b)
        : totalDurationMs;

    if (end <= start) {
      return null;
    }

    final ratioIndex = isEnd ? index + 1 : index;
    return start + (((end - start) * ratioIndex) / partCount).round();
  }

  int? _lastTimedEndMs(List<PronunciationHighlightPart> parts) {
    final timedEnds = parts
        .where((part) => part.hasTiming)
        .map((part) => part.endMs!)
        .toList(growable: false);
    if (timedEnds.isEmpty) {
      return null;
    }
    return timedEnds.reduce((a, b) => a > b ? a : b);
  }

  int? _activeHighlightPartIndexFor(
    int positionMs,
    List<PronunciationHighlightPart> parts,
  ) {
    final lastEnd = _lastTimedEndMs(parts);
    if (lastEnd != null && positionMs > lastEnd + _timedHighlightGraceMs) {
      return null;
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

  void _setActiveHighlightPart(int? activeIndex) {
    if (state.activeHighlightPartIndex == activeIndex) {
      return;
    }
    state = state.copyWith(activeHighlightPartIndex: activeIndex);
  }

  void _stopPronunciationPositionTracking() {
    _pronunciationPositionSubscription?.cancel();
    _pronunciationPositionSubscription = null;
    _lastPronunciationPositionMs = 0;
    _pronunciationBreakdownFinished = false;
  }

  Future<void> _captureAndPause() async {
    _wasNarrationPlaying = _lastState.isNarrationPlaying;
    if (_wasNarrationPlaying) {
      await _dispatchExpecting(
        const ReaderToggleNarration(),
        narrationTransition: true,
      );
    }

    _wasListening = _lastState.isListening;
    if (_wasListening) {
      await _dispatchExpecting(
        const ReaderPauseListening(),
        listeningTransition: true,
      );
    }
  }

  Future<void> _restoreCapturedAudio() async {
    if (_wasNarrationPlaying && !_lastState.isNarrationPlaying) {
      await _dispatchExpecting(
        const ReaderToggleNarration(),
        narrationTransition: true,
      );
      _wasNarrationPlaying = false;
    }

    if (_wasListening && !_lastState.isListening) {
      await _dispatchExpecting(
        const ReaderResumeListening(),
        listeningTransition: true,
      );
      _wasListening = false;
    }
  }

  Future<void> _restoreIfNeeded() async {
    if (_userOverride) {
      _wasNarrationPlaying = false;
      _wasListening = false;
      return;
    }

    await _restoreCapturedAudio();
  }

  Future<void> _dispatchExpecting(
    ReaderIntent intent, {
    bool narrationTransition = false,
    bool listeningTransition = false,
  }) async {
    if (narrationTransition) {
      _expectedNarrationTransitions++;
    }
    if (listeningTransition) {
      _expectedListeningTransitions++;
    }
    await _session.dispatch(intent);
  }

  void _clearExpectedTransitions() {
    _expectedNarrationTransitions = 0;
    _expectedListeningTransitions = 0;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _pageChangeSubscription?.cancel();
    _pronunciationPositionSubscription?.cancel();
    super.dispose();
  }
}
