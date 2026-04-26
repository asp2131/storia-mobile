import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/providers.dart';
import '../reader_session.dart';
import '../reader_intent.dart';
import '../reader_view_state.dart';
import '../services/pronunciation_playback_service.dart';
import '../services/word_tts_service.dart';
import 'reader_session_provider.dart';

class WordTtsState {
  const WordTtsState({this.tappedWordIndex});
  final int? tappedWordIndex;
}

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

  void _onPageChanged() {
    if (!_flowActive) {
      return;
    }
    _flowId++;
    _flowActive = false;
    _userOverride = true;
    _clearExpectedTransitions();
    _pronunciation.stop();
    _service.stop();
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
    state = WordTtsState(tappedWordIndex: globalIndex);

    await _captureAndPause();
    if (flowId != _flowId) {
      return;
    }

    final outcome = await _pronunciation.tryPlayBreakdownFor(
      rawWord: word,
      bookId: _bookId,
    );
    if (flowId != _flowId) {
      return;
    }

    if (outcome == PronunciationOutcome.fallback ||
        outcome == PronunciationOutcome.error) {
      await _service.speak(word);
    }

    if (flowId == _flowId && state.tappedWordIndex == globalIndex) {
      state = const WordTtsState();
    }

    if (flowId == _flowId) {
      await _restoreIfNeeded();
    }
    if (flowId == _flowId) {
      _flowActive = false;
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
    state = WordTtsState(tappedWordIndex: globalIndex);

    await _captureAndPause();
    if (flowId != _flowId) {
      return;
    }

    final outcome = await _pronunciation.tryPlayBreakdownFor(
      rawWord: word,
      bookId: _bookId,
    );
    if (flowId != _flowId) {
      return;
    }

    if (outcome == PronunciationOutcome.fallback ||
        outcome == PronunciationOutcome.error) {
      await _service.soundOut(word);
    }

    if (flowId == _flowId && state.tappedWordIndex == globalIndex) {
      state = const WordTtsState();
    }

    if (flowId == _flowId) {
      await _restoreIfNeeded();
    }
    if (flowId == _flowId) {
      _flowActive = false;
    }
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
        const ReaderPracticePrimaryAction(),
        listeningTransition: true,
      );
    }
  }

  Future<void> _restoreIfNeeded() async {
    if (_userOverride) {
      _wasNarrationPlaying = false;
      _wasListening = false;
      return;
    }

    if (_wasNarrationPlaying && !_lastState.isNarrationPlaying) {
      await _dispatchExpecting(
        const ReaderToggleNarration(),
        narrationTransition: true,
      );
      _wasNarrationPlaying = false;
    }

    if (_wasListening && !_lastState.isListening) {
      await _dispatchExpecting(
        const ReaderPracticePrimaryAction(),
        listeningTransition: true,
      );
      _wasListening = false;
    }
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
    super.dispose();
  }
}
