import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_providers.dart';
import '../../../data/models.dart';
import '../runtime/providers/reader_session_provider.dart';
import '../runtime/providers/reader_word_help_provider.dart';
import '../runtime/reader_session.dart';
import '../runtime/word_help/reader_word_help.dart';
import 'reader_experience_effects.dart';

final readerExperienceEffectsProvider = Provider<ReaderExperienceEffects>(
  (ref) => SfxReaderExperienceEffects(ref.watch(sfxBusProvider)),
);

final readerExperienceWordHelpProvider = Provider.autoDispose
    .family<ReaderWordHelp, String>((ref, bookId) {
      ref.listen<WordHelpSnapshot>(readerWordHelpProvider(bookId), (_, _) {});
      return ref.read(readerWordHelpProvider(bookId).notifier);
    });

final readerExperienceControllerProvider =
    AutoDisposeNotifierProviderFamily<
      ReaderExperienceControllerNotifier,
      ReaderExperienceState,
      String
    >(ReaderExperienceControllerNotifier.new);

class ReaderExperienceState {
  const ReaderExperienceState({
    required this.readerState,
    required this.wordHelpSnapshot,
    required this.showCelebrationGif,
    required this.endedForLifecycle,
    required this.activityNarrationPaused,
  });

  const ReaderExperienceState.initial()
    : readerState = const ReaderViewState.initial(),
      wordHelpSnapshot = const WordHelpSnapshot.idle(),
      showCelebrationGif = false,
      endedForLifecycle = false,
      activityNarrationPaused = false;

  final ReaderViewState readerState;
  final WordHelpSnapshot wordHelpSnapshot;
  final bool showCelebrationGif;
  final bool endedForLifecycle;
  final bool activityNarrationPaused;

  ReaderExperienceState copyWith({
    ReaderViewState? readerState,
    WordHelpSnapshot? wordHelpSnapshot,
    bool? showCelebrationGif,
    bool? endedForLifecycle,
    bool? activityNarrationPaused,
  }) {
    return ReaderExperienceState(
      readerState: readerState ?? this.readerState,
      wordHelpSnapshot: wordHelpSnapshot ?? this.wordHelpSnapshot,
      showCelebrationGif: showCelebrationGif ?? this.showCelebrationGif,
      endedForLifecycle: endedForLifecycle ?? this.endedForLifecycle,
      activityNarrationPaused:
          activityNarrationPaused ?? this.activityNarrationPaused,
    );
  }
}

sealed class ReaderExperienceAction {
  const ReaderExperienceAction();
}

final class ReaderExperienceStart extends ReaderExperienceAction {
  const ReaderExperienceStart({required this.book, this.initialPageIndex = 0});

  final Book book;
  final int initialPageIndex;
}

final class ReaderExperiencePageChanged extends ReaderExperienceAction {
  const ReaderExperiencePageChanged(this.index);

  final int index;
}

final class ReaderExperienceScrollOffsetChanged extends ReaderExperienceAction {
  const ReaderExperienceScrollOffsetChanged(this.offset);

  final double offset;
}

final class ReaderExperienceWordTapped extends ReaderExperienceAction {
  const ReaderExperienceWordTapped({
    required this.word,
    required this.globalIndex,
    required this.pageIndex,
  });

  final String word;
  final int globalIndex;
  final int pageIndex;
}

final class ReaderExperienceWordLongPressed extends ReaderExperienceAction {
  const ReaderExperienceWordLongPressed({
    required this.word,
    required this.globalIndex,
    required this.pageIndex,
  });

  final String word;
  final int globalIndex;
  final int pageIndex;
}

final class ReaderExperienceToggleNarration extends ReaderExperienceAction {
  const ReaderExperienceToggleNarration();
}

final class ReaderExperienceToggleSoundscape extends ReaderExperienceAction {
  const ReaderExperienceToggleSoundscape();
}

final class ReaderExperienceSetNarrationVolume extends ReaderExperienceAction {
  const ReaderExperienceSetNarrationVolume(this.volume);

  final double volume;
}

final class ReaderExperienceSetSoundscapeVolume extends ReaderExperienceAction {
  const ReaderExperienceSetSoundscapeVolume(this.volume);

  final double volume;
}

final class ReaderExperienceTogglePractice extends ReaderExperienceAction {
  const ReaderExperienceTogglePractice();
}

final class ReaderExperiencePauseListening extends ReaderExperienceAction {
  const ReaderExperiencePauseListening();
}

final class ReaderExperienceResumeListening extends ReaderExperienceAction {
  const ReaderExperienceResumeListening();
}

final class ReaderExperienceActivityShown extends ReaderExperienceAction {
  const ReaderExperienceActivityShown();
}

final class ReaderExperienceActivityDismissed extends ReaderExperienceAction {
  const ReaderExperienceActivityDismissed();
}

final class ReaderExperienceAckCelebration extends ReaderExperienceAction {
  const ReaderExperienceAckCelebration();
}

final class ReaderExperienceEnd extends ReaderExperienceAction {
  const ReaderExperienceEnd({this.reason = 'screen_dispose'});

  final String reason;
}

class ReaderExperienceController {
  ReaderExperienceController({
    required ReaderSession session,
    required ReaderWordHelp wordHelp,
    ReaderExperienceEffects effects = const NoopReaderExperienceEffects(),
  }) : _session = session,
       _wordHelp = wordHelp,
       _effects = effects,
       _state = ReaderExperienceState(
         readerState: const ReaderViewState.initial(),
         wordHelpSnapshot: wordHelp.snapshot,
         showCelebrationGif: false,
         endedForLifecycle: false,
         activityNarrationPaused: false,
       ) {
    _sessionSubscription = _session.states.listen(_onReaderStateChanged);
    _wordHelpSubscription = _wordHelp.snapshots.listen(_onWordHelpChanged);
  }

  final ReaderSession _session;
  final ReaderWordHelp _wordHelp;
  final ReaderExperienceEffects _effects;
  final _states = StreamController<ReaderExperienceState>.broadcast();
  final _narrationPositionNotifier = ValueNotifier<Duration>(Duration.zero);
  final _scrollOffsetNotifier = ValueNotifier<double>(0.0);

  late ReaderExperienceState _state;
  StreamSubscription<ReaderViewState>? _sessionSubscription;
  StreamSubscription<WordHelpSnapshot>? _wordHelpSubscription;
  Book? _currentBook;
  bool _isDisposed = false;

  ReaderExperienceState get state => _state;
  Stream<ReaderExperienceState> get states => _states.stream;
  ValueListenable<Duration> get narrationPositionListenable =>
      _narrationPositionNotifier;
  ValueListenable<double> get scrollOffsetListenable => _scrollOffsetNotifier;

  Future<void> dispatch(ReaderExperienceAction action) async {
    if (_isDisposed) {
      return;
    }

    switch (action) {
      case ReaderExperienceStart(:final book, :final initialPageIndex):
        _currentBook = book;
        await _session.dispatch(
          ReaderStart(book: book, initialPageIndex: initialPageIndex),
        );
      case ReaderExperiencePageChanged(:final index):
        await _effects.playPageChange();
        await _session.dispatch(ReaderGoToPage(index));
      case ReaderExperienceScrollOffsetChanged(:final offset):
        _scrollOffsetNotifier.value = offset;
      case ReaderExperienceWordTapped(
        :final word,
        :final globalIndex,
        :final pageIndex,
      ):
        if (_currentBook == null) {
          throw StateError('ReaderExperienceController must be started first.');
        }
        await _effects.playWordTap();
        await _playWordHelp(
          word: word,
          globalIndex: globalIndex,
          pageIndex: pageIndex,
          mode: WordHelpMode.word,
        );
      case ReaderExperienceWordLongPressed(
        :final word,
        :final globalIndex,
        :final pageIndex,
      ):
        await _playWordHelp(
          word: word,
          globalIndex: globalIndex,
          pageIndex: pageIndex,
          mode: WordHelpMode.breakdown,
        );
      case ReaderExperienceToggleNarration():
        await _session.dispatch(const ReaderToggleNarration());
      case ReaderExperienceToggleSoundscape():
        await _session.dispatch(const ReaderToggleSoundscape());
      case ReaderExperienceSetNarrationVolume(:final volume):
        await _session.dispatch(ReaderSetNarrationVolume(volume));
      case ReaderExperienceSetSoundscapeVolume(:final volume):
        await _session.dispatch(ReaderSetSoundscapeVolume(volume));
      case ReaderExperienceTogglePractice():
        await _session.dispatch(const ReaderPracticePrimaryAction());
      case ReaderExperiencePauseListening():
        await _session.dispatch(const ReaderPauseListening());
      case ReaderExperienceResumeListening():
        await _session.dispatch(const ReaderResumeListening());
      case ReaderExperienceActivityShown():
        if (_state.readerState.isNarrationPlaying) {
          _setState(_state.copyWith(activityNarrationPaused: true));
          await _session.dispatch(const ReaderPauseNarration());
        }
      case ReaderExperienceActivityDismissed():
        if (_state.activityNarrationPaused) {
          _setState(_state.copyWith(activityNarrationPaused: false));
          await _session.dispatch(const ReaderResumeNarration());
        }
      case ReaderExperienceAckCelebration():
        await _session.dispatch(const ReaderAckCelebration());
      case ReaderExperienceEnd(:final reason):
        await _session.dispatch(ReaderEnd(reason: reason));
    }
  }

  Future<void> handleLifecycleState(AppLifecycleState lifecycleState) async {
    if (_isDisposed) {
      return;
    }

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _setState(_state.copyWith(endedForLifecycle: true));
      await _session.dispatch(ReaderEnd(reason: 'app_${lifecycleState.name}'));
      return;
    }

    if (lifecycleState == AppLifecycleState.resumed &&
        _state.endedForLifecycle) {
      _setState(_state.copyWith(endedForLifecycle: false));
      final book = _currentBook;
      if (book != null) {
        await _session.dispatch(
          ReaderStart(
            book: book,
            initialPageIndex: _state.readerState.activePageIndex,
          ),
        );
      }
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    await _session.dispatch(const ReaderEnd(reason: 'screen_dispose'));
    await _wordHelp.cancel(reason: WordHelpCancelReason.disposed);
    await _sessionSubscription?.cancel();
    await _wordHelpSubscription?.cancel();
    await _states.close();
    _narrationPositionNotifier.dispose();
    _scrollOffsetNotifier.dispose();
    _effects.dispose();
  }

  Future<void> _playWordHelp({
    required String word,
    required int globalIndex,
    required int pageIndex,
    required WordHelpMode mode,
  }) async {
    final book = _currentBook;
    if (book == null) {
      throw StateError('ReaderExperienceController must be started first.');
    }

    await _wordHelp.play(
      WordHelpRequest(
        bookId: book.id,
        pageIndex: pageIndex,
        wordIndex: globalIndex,
        rawWord: word,
        mode: mode,
      ),
    );
  }

  Future<void> _onReaderStateChanged(ReaderViewState next) async {
    if (_isDisposed) {
      return;
    }

    _narrationPositionNotifier.value = next.narrationPosition;

    final wasCelebrating = _state.readerState.showCelebration;
    final isCelebrating = next.showCelebration;
    var showCelebrationGif = _state.showCelebrationGif;

    if (isCelebrating && !wasCelebrating) {
      await _effects.playCelebration();
      showCelebrationGif = true;
    } else if (!isCelebrating && wasCelebrating) {
      await _effects.stopCelebration();
      showCelebrationGif = false;
    }

    _setState(
      _state.copyWith(
        readerState: next,
        showCelebrationGif: showCelebrationGif,
      ),
    );
  }

  void _onWordHelpChanged(WordHelpSnapshot snapshot) {
    if (_isDisposed) {
      return;
    }

    _setState(_state.copyWith(wordHelpSnapshot: snapshot));
  }

  void _setState(ReaderExperienceState next) {
    if (_isDisposed) {
      return;
    }

    _state = next;
    _states.add(next);
  }
}

class ReaderExperienceControllerNotifier
    extends AutoDisposeFamilyNotifier<ReaderExperienceState, String> {
  ReaderExperienceController? _controller;
  StreamSubscription<ReaderExperienceState>? _stateSubscription;

  ReaderExperienceController get controller {
    final controller = _controller;
    if (controller == null) {
      throw StateError('ReaderExperienceController provider is not built yet.');
    }
    return controller;
  }

  ValueListenable<Duration> get narrationPositionListenable =>
      controller.narrationPositionListenable;

  ValueListenable<double> get scrollOffsetListenable =>
      controller.scrollOffsetListenable;

  @override
  ReaderExperienceState build(String bookId) {
    _disposeController();

    final nextController = ReaderExperienceController(
      session: ref.watch(readerSessionProvider),
      wordHelp: ref.watch(readerExperienceWordHelpProvider(bookId)),
      effects: ref.watch(readerExperienceEffectsProvider),
    );
    _controller = nextController;
    _stateSubscription = nextController.states.listen((next) {
      state = next;
    });

    ref.onDispose(_disposeController);

    return nextController.state;
  }

  Future<void> dispatch(ReaderExperienceAction action) {
    return controller.dispatch(action);
  }

  Future<void> handleLifecycleState(AppLifecycleState lifecycleState) {
    return controller.handleLifecycleState(lifecycleState);
  }

  void _disposeController() {
    final subscription = _stateSubscription;
    _stateSubscription = null;
    unawaited(subscription?.cancel());

    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
  }
}

typedef ReaderCoordinator = ReaderExperienceController;
