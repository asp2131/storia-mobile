import 'dart:async';

import '../../../data/models.dart';
import 'internal/page_words_indexer.dart';
import 'internal/word_matcher.dart';
import 'ports/audio_port.dart';
import 'ports/scheduler_port.dart';
import 'ports/speech_practice_port.dart';
import 'reader_intent.dart';
import 'reader_session.dart';
import 'reader_view_state.dart';

class ReaderSessionImpl implements ReaderSession {
  ReaderSessionImpl({
    required AudioPort audioPort,
    required SpeechPracticePort speechPort,
    required SchedulerPort scheduler,
  }) : _audioPort = audioPort,
       _speechPort = speechPort,
       _scheduler = scheduler {
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

  final StreamController<ReaderViewState> _controller =
      StreamController<ReaderViewState>.broadcast();
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

  @override
  Stream<ReaderViewState> get states async* {
    yield _state;
    yield* _controller.stream;
  }

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
      await _audioPort.toggleNarration();
      return;
    }
    if (intent is ReaderToggleSoundscape) {
      await _audioPort.toggleSoundscape();
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
    if (intent is ReaderPracticePrimaryAction) {
      await _handlePracticePrimaryAction();
      return;
    }
    if (intent is ReaderAckCelebration) {
      _clearCelebration();
    }
  }

  Future<void> _handleStart(ReaderStart intent) async {
    _book = intent.book;
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
    final nextPage = book.pages[clampedIndex];

    await _speechPort.stopListening();
    _clearCelebration();
    _emit(
      _state.copyWith(
        activePageIndex: clampedIndex,
        isListening: false,
        spokenWordIndices: const {},
      ),
    );
    _wordToIndices = buildWordToIndices(nextPage);

    final requestId = ++_pageRequestId;
    await _audioPort.transitionToPage(nextPage);
    if (requestId != _pageRequestId) {
      return;
    }
  }

  Future<void> _handlePracticePrimaryAction() async {
    if (!_state.isPracticeMode) {
      await _ensureSpeechInitialized();
      if (!_speechAvailable) {
        return;
      }
      _emit(
        _state.copyWith(
          isPracticeMode: true,
          isListening: false,
          showCelebration: false,
          spokenWordIndices: const {},
        ),
      );
      await _startListening();
      return;
    }

    if (_state.isListening) {
      await _speechPort.stopListening();
      _onListeningDone();
      return;
    }

    await _startListening();
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
          _emit(_state.copyWith(spokenWordIndices: updated));
        }
      },
      onDone: _onListeningDone,
      onError: (_) {
        _emit(_state.copyWith(isListening: false));
      },
    );

    _emit(_state.copyWith(isListening: true, showCelebration: false));
  }

  void _onListeningDone() {
    if (!_state.isListening) {
      return;
    }

    final shouldCelebrate = _state.spokenWordIndices.isNotEmpty;
    _emit(
      _state.copyWith(isListening: false, showCelebration: shouldCelebrate),
    );

    if (shouldCelebrate) {
      _scheduleCelebrationClear();
    }
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
    _celebrationTask?.cancel();
    await _narrationPositionSub?.cancel();
    await _narrationPlayingSub?.cancel();
    await _soundscapePlayingSub?.cancel();
    await _speechPort.dispose();
    await _audioPort.dispose();
    await _controller.close();
  }
}
