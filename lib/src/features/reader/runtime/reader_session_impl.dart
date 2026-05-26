import 'dart:async';

import '../../../data/models.dart';
import 'internal/page_words_indexer.dart';
import 'internal/word_matcher.dart';
import 'ports/audio_port.dart';
import 'ports/scheduler_port.dart';
import 'ports/speech_practice_port.dart';
import 'reader_analytics_tracker.dart';
import 'reader_session.dart';

class ReaderSessionImpl implements ReaderSession {
  ReaderSessionImpl({
    required AudioPort audioPort,
    required SpeechPracticePort speechPort,
    required SchedulerPort scheduler,
    ReaderAnalyticsTracker? analyticsTracker,
  }) : _audioPort = audioPort,
       _speechPort = speechPort,
       _scheduler = scheduler,
       _analyticsTracker = analyticsTracker {
    _narrationPositionSub = _audioPort.narrationPosition.listen((position) {
      _emit(_state.copyWith(narrationPosition: position));
    });
    _narrationPlayingSub = _audioPort.narrationPlaying.listen((playing) {
      _emit(_state.copyWith(isNarrationPlaying: playing));
    });
    _soundscapePlayingSub = _audioPort.soundscapePlaying.listen((playing) {
      _emit(_state.copyWith(isSoundscapePlaying: playing));
    });
  }

  final AudioPort _audioPort;
  final SpeechPracticePort _speechPort;
  final SchedulerPort _scheduler;
  final ReaderAnalyticsTracker? _analyticsTracker;

  final StreamController<ReaderViewState> _controller =
      StreamController<ReaderViewState>.broadcast();
  final StreamController<int> _pageChangeController =
      StreamController<int>.broadcast();
  ReaderViewState _state = const ReaderViewState.initial();

  StreamSubscription<Duration>? _narrationPositionSub;
  StreamSubscription<bool>? _narrationPlayingSub;
  StreamSubscription<bool>? _soundscapePlayingSub;

  Book? _book;
  int _pageRequestId = 0;
  bool _speechInitialized = false;
  bool _speechAvailable = false;
  Map<String, List<int>> _wordToIndices = const {};
  CancelableTask? _celebrationTask;
  bool _wasNarrationPlayingBeforePractice = false;
  double _soundscapeVolumeBeforePractice = 0.6;
  String? _activeSpeechAttemptId;
  bool _activeSpeechAttemptHadSpeech = false;

  @override
  Stream<ReaderViewState> get states async* {
    yield _state;
    yield* _controller.stream;
  }

  @override
  Stream<int> get pageChanges => _pageChangeController.stream;

  @override
  Future<void> dispatch(ReaderIntent intent) async {
    if (intent is ReaderStart) {
      await _handleStart(intent);
      return;
    }
    if (intent is ReaderGoToPage) {
      await _handleGoToPage(intent.pageIndex);
      return;
    }
    if (intent is ReaderToggleNarration) {
      final willPlay = !_state.isNarrationPlaying;
      final shouldTrackPlay =
          intent.source == ReaderIntentSource.user && willPlay;
      await _audioPort.toggleNarration();
      // Optimistically mirror the requested state so rapid sequential toggles
      // do not classify a stop as another play while the audio stream catches up.
      _emit(_state.copyWith(isNarrationPlaying: willPlay));
      if (shouldTrackPlay) {
        _analyticsTracker?.recordNarrationPlayed(
          pageIndex: _state.activePageIndex,
        );
      }
      return;
    }
    if (intent is ReaderToggleSoundscape) {
      final willPlay = !_state.isSoundscapePlaying;
      final shouldTrackPlay =
          intent.source == ReaderIntentSource.user && willPlay;
      await _audioPort.toggleSoundscape();
      // Optimistically mirror the requested state so rapid sequential toggles
      // do not classify a stop as another play while the audio stream catches up.
      _emit(_state.copyWith(isSoundscapePlaying: willPlay));
      if (shouldTrackPlay) {
        _analyticsTracker?.recordSoundscapePlayed(
          pageIndex: _state.activePageIndex,
        );
      }
      return;
    }
    if (intent is ReaderSetNarrationVolume) {
      await _audioPort.setNarrationVolume(intent.volume);
      _emit(_state.copyWith(narrationVolume: intent.volume));
      return;
    }
    if (intent is ReaderSetSoundscapeVolume) {
      await _audioPort.setSoundscapeVolume(intent.volume);
      _emit(_state.copyWith(soundscapeVolume: intent.volume));
      return;
    }
    if (intent is ReaderPauseListening) {
      await _speechPort.stopListening();
      _completeSpeechAttempt(reason: 'paused');
      _emit(_state.copyWith(isListening: false));
      return;
    }
    if (intent is ReaderResumeListening) {
      await _startListening();
      return;
    }
    if (intent is ReaderPracticePrimaryAction) {
      await _handlePracticePrimaryAction();
      return;
    }
    if (intent is ReaderAckCelebration) {
      _clearCelebration();
      return;
    }
    if (intent is ReaderEnd) {
      _completeSpeechAttempt(reason: intent.reason);
      _analyticsTracker?.endSession(reason: intent.reason);
      // Clear in-memory state so a future subscriber (e.g. re-entering the
      // book) does not inherit the stale end page. Reset silently — no emit —
      // so the app-lifecycle pause→resume path keeps the controller's retained
      // page index for its ReaderStart re-seed.
      _resetState();
    }
  }

  void _resetState() {
    _celebrationTask?.cancel();
    _celebrationTask = null;
    _state = const ReaderViewState.initial();
  }

  Future<void> _handleStart(ReaderStart intent) async {
    _book = intent.book;
    _analyticsTracker?.startBook(
      intent.book,
      initialPageIndex: intent.initialPageIndex,
    );
    final pages = intent.book.pages;
    if (pages.isEmpty) {
      _emit(_state.copyWith(isReady: true, activePageIndex: 0));
      return;
    }

    final initialIndex = intent.initialPageIndex.clamp(0, pages.length - 1);
    _emit(
      _state.copyWith(
        isReady: true,
        activePageIndex: initialIndex,
        spokenWordIndices: const {},
        showCelebration: false,
        isListening: false,
      ),
    );

    _wordToIndices = buildWordToIndices(pages[initialIndex]);

    final requestId = ++_pageRequestId;
    await _audioPort.ensureInitialized();
    await _audioPort.loadPage(pages[initialIndex]);
    if (requestId != _pageRequestId) {
      return;
    }
  }

  Future<void> _handleGoToPage(int pageIndex) async {
    final book = _book;
    if (book == null || book.pages.isEmpty) {
      return;
    }

    final clampedIndex = pageIndex.clamp(0, book.pages.length - 1);
    final previousPageIndex = _state.activePageIndex;
    final nextPage = book.pages[clampedIndex];
    final isPageChange = clampedIndex != previousPageIndex;

    await _speechPort.stopListening();
    _completeSpeechAttempt(reason: 'page_changed');
    _clearCelebration();
    _emit(
      _state.copyWith(
        activePageIndex: clampedIndex,
        isListening: false,
        spokenWordIndices: const {},
      ),
    );
    _wordToIndices = buildWordToIndices(nextPage);
    if (isPageChange) {
      _analyticsTracker?.recordPageNavigation(previousPageIndex, clampedIndex);
      _analyticsTracker?.recordPageViewed(clampedIndex);
      if (!_pageChangeController.isClosed) {
        _pageChangeController.add(clampedIndex);
      }
    }

    final requestId = ++_pageRequestId;
    await _audioPort.transitionToPage(nextPage);
    if (requestId != _pageRequestId) {
      return;
    }
  }

  Future<void> _handlePracticePrimaryAction() async {
    if (!_state.isListening) {
      // Start practice: save state, duck audio, begin listening.
      await _ensureSpeechInitialized();
      if (!_speechAvailable) {
        return;
      }

      _wasNarrationPlayingBeforePractice = _state.isNarrationPlaying;
      _soundscapeVolumeBeforePractice = _state.soundscapeVolume;

      // Pause narration if currently playing.
      if (_state.isNarrationPlaying) {
        await _audioPort.toggleNarration();
      }

      // Duck soundscape volume.
      await _audioPort.setSoundscapeVolume(0.3);

      _emit(
        _state.copyWith(
          isPracticeMode: true,
          isListening: false,
          showCelebration: false,
          spokenWordIndices: const {},
          soundscapeVolume: 0.3,
        ),
      );
      await _startListening();
      return;
    }

    // Stop practice: stop listening, restore audio state.
    await _speechPort.stopListening();
    await _restorePracticeAudioState();
    _onListeningDone();
  }

  Future<void> _restorePracticeAudioState() async {
    // Restore soundscape volume.
    await _audioPort.setSoundscapeVolume(_soundscapeVolumeBeforePractice);
    _emit(
      _state.copyWith(
        soundscapeVolume: _soundscapeVolumeBeforePractice,
        isPracticeMode: false,
      ),
    );

    // Resume narration if it was playing before practice started.
    if (_wasNarrationPlayingBeforePractice && !_state.isNarrationPlaying) {
      await _audioPort.toggleNarration();
    }
  }

  Future<void> _ensureSpeechInitialized() async {
    if (_speechInitialized) {
      return;
    }
    _speechAvailable = await _speechPort.initialize();
    _speechInitialized = true;
  }

  Future<void> _startListening() async {
    if (!_state.isPracticeMode || !_speechAvailable || _state.isListening) {
      return;
    }

    await _speechPort.startListening(
      onResult: (recognizedWords, {required isFinal}) {
        final updated = matchSpokenWords(
          recognizedWords: recognizedWords,
          wordToIndices: _wordToIndices,
          existingIndices: _state.spokenWordIndices,
        );

        if (isFinal) {
          final hasAnyWord = recognizedWords.trim().isNotEmpty;
          _activeSpeechAttemptHadSpeech =
              _activeSpeechAttemptHadSpeech || hasAnyWord;
          _completeSpeechAttempt(
            reason: 'final_result',
            matchedWordCount: updated.length,
          );
          _emit(
            _state.copyWith(
              spokenWordIndices: updated,
              isListening: false,
              showCelebration: hasAnyWord,
            ),
          );
          if (hasAnyWord) {
            _scheduleCelebrationClear();
          }
        } else {
          if (recognizedWords.trim().isNotEmpty) {
            _activeSpeechAttemptHadSpeech = true;
          }
          _emit(_state.copyWith(spokenWordIndices: updated));
        }
      },
      onDone: _onListeningDone,
      onError: (_) {
        _completeSpeechAttempt(reason: 'error');
        _emit(_state.copyWith(isListening: false));
      },
    );

    _activeSpeechAttemptId = _analyticsTracker?.recordSpeechAttemptStarted(
      pageIndex: _state.activePageIndex,
    );
    _activeSpeechAttemptHadSpeech = false;
    _emit(_state.copyWith(isListening: true, showCelebration: false));
  }

  Future<void> _onListeningDone() async {
    if (!_state.isListening) {
      return;
    }

    final shouldCelebrate = _state.spokenWordIndices.isNotEmpty;
    _completeSpeechAttempt(
      reason: 'done',
      matchedWordCount: _state.spokenWordIndices.length,
    );
    _emit(
      _state.copyWith(isListening: false, showCelebration: shouldCelebrate),
    );

    if (shouldCelebrate) {
      _scheduleCelebrationClear();
    }

    // Restore audio state when listening ends naturally.
    if (_state.isPracticeMode) {
      await _restorePracticeAudioState();
    }
  }

  void _completeSpeechAttempt({required String reason, int? matchedWordCount}) {
    final attemptId = _activeSpeechAttemptId;
    if (attemptId == null) {
      return;
    }

    _analyticsTracker?.recordSpeechAttemptCompleted(
      attemptId: attemptId,
      reason: reason,
      matchedWordCount: matchedWordCount ?? _state.spokenWordIndices.length,
      hadSpeech: _activeSpeechAttemptHadSpeech,
      pageIndex: _state.activePageIndex,
    );
    _activeSpeechAttemptId = null;
    _activeSpeechAttemptHadSpeech = false;
  }

  void _scheduleCelebrationClear() {
    _celebrationTask?.cancel();
    _celebrationTask = _scheduler.schedule(const Duration(seconds: 3), () {
      _clearCelebration();
    });
  }

  void _clearCelebration() {
    _celebrationTask?.cancel();
    _celebrationTask = null;
    if (_state.showCelebration) {
      _emit(_state.copyWith(showCelebration: false));
    }
  }

  void _emit(ReaderViewState next) {
    _state = next;
    if (!_controller.isClosed) {
      _controller.add(_state);
    }
  }

  @override
  Future<void> dispose() async {
    _completeSpeechAttempt(reason: 'dispose');
    _analyticsTracker?.endSession(reason: 'provider_dispose');
    _celebrationTask?.cancel();
    await _narrationPositionSub?.cancel();
    await _narrationPlayingSub?.cancel();
    await _soundscapePlayingSub?.cancel();
    await _speechPort.dispose();
    await _audioPort.dispose();
    await _controller.close();
    await _pageChangeController.close();
  }
}
