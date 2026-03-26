import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../reader_session.dart';
import '../reader_intent.dart';
import '../reader_view_state.dart';
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

final wordTtsProvider =
    StateNotifierProvider<WordTtsNotifier, WordTtsState>((ref) {
  final service = ref.watch(wordTtsServiceProvider);
  final session = ref.watch(readerSessionProvider);
  return WordTtsNotifier(service: service, session: session);
});

class WordTtsNotifier extends StateNotifier<WordTtsState> {
  WordTtsNotifier({
    required WordTtsService service,
    required ReaderSession session,
  })  : _service = service,
        _session = session,
        super(const WordTtsState());

  final WordTtsService _service;
  final ReaderSession _session;
  bool _wasNarrationPlaying = false;
  bool _wasListening = false;
  StreamSubscription<ReaderViewState>? _stateSubscription;
  ReaderViewState _lastState = const ReaderViewState.initial();

  void attachStateStream(Stream<ReaderViewState> states) {
    _stateSubscription?.cancel();
    _stateSubscription = states.listen((s) => _lastState = s);
  }

  /// Called when a word is tapped in the overlay.
  /// Interrupts any current TTS, pauses narration/mic if needed,
  /// speaks the word, then restores previous state.
  Future<void> onWordTapped(String word, int globalIndex) async {
    // Interrupt: cancel any in-progress speech and update highlight immediately
    await _service.stop();
    state = WordTtsState(tappedWordIndex: globalIndex);

    // Pause narration if playing
    _wasNarrationPlaying = _lastState.isNarrationPlaying;
    if (_wasNarrationPlaying) {
      await _session.dispatch(const ReaderToggleNarration());
    }

    // Pause mic if listening (practice mode)
    _wasListening = _lastState.isListening;
    if (_wasListening) {
      await _session.dispatch(const ReaderPracticePrimaryAction());
    }

    // Speak the word — future completes when TTS finishes or is interrupted
    await _service.speak(word);

    // Only clear highlight if this word is still the active one (not interrupted by another tap)
    if (state.tappedWordIndex == globalIndex) {
      state = const WordTtsState();
    }

    // Resume narration if it was playing before
    if (_wasNarrationPlaying && !_lastState.isNarrationPlaying) {
      await _session.dispatch(const ReaderToggleNarration());
      _wasNarrationPlaying = false;
    }

    // Resume mic if it was listening before
    if (_wasListening && !_lastState.isListening) {
      await _session.dispatch(const ReaderPracticePrimaryAction());
      _wasListening = false;
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}
