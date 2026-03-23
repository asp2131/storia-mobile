import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/models.dart';

class ReaderPracticeState {
  final bool isPracticeMode;
  final bool isListening;
  final Set<int> spokenWordIndices;
  final bool showCelebration;

  const ReaderPracticeState({
    this.isPracticeMode = false,
    this.isListening = false,
    this.spokenWordIndices = const {},
    this.showCelebration = false,
  });

  ReaderPracticeState copyWith({
    bool? isPracticeMode,
    bool? isListening,
    Set<int>? spokenWordIndices,
    bool? showCelebration,
  }) {
    return ReaderPracticeState(
      isPracticeMode: isPracticeMode ?? this.isPracticeMode,
      isListening: isListening ?? this.isListening,
      spokenWordIndices: spokenWordIndices ?? this.spokenWordIndices,
      showCelebration: showCelebration ?? this.showCelebration,
    );
  }
}

class ReaderPracticeNotifier extends StateNotifier<ReaderPracticeState> {
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  // Word index lookup built from the current page
  Map<String, List<int>> _wordToIndices = {};

  ReaderPracticeNotifier() : super(const ReaderPracticeState());

  // ---------------------------------------------------------------------------
  // Page words — call whenever the active page changes
  // ---------------------------------------------------------------------------

  void loadPageWords(PageData page) {
    _wordToIndices = {};
    var index = 0;

    // Priority 1: narration timestamps (most accurate word list)
    final timestamps = page.narrationTimestamps;
    if (timestamps != null && timestamps.isNotEmpty) {
      for (final ts in timestamps) {
        final word = _clean(ts.word);
        if (word.isNotEmpty) {
          _wordToIndices.putIfAbsent(word, () => []).add(index);
          index++;
        }
      }
      return;
    }

    // Priority 2: overlay text elements
    if (page.overlay != null) {
      for (final element in page.overlay!.elements) {
        final tokens = element.text
            .split(RegExp(r'\s+'))
            .where((t) => t.trim().isNotEmpty);
        for (final token in tokens) {
          final word = _clean(token);
          if (word.isNotEmpty) {
            _wordToIndices.putIfAbsent(word, () => []).add(index);
            index++;
          }
        }
      }
      return;
    }

    // Priority 3: plain text content
    final text = page.textContent;
    if (text != null && text.trim().isNotEmpty) {
      final tokens =
          text.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty);
      for (final token in tokens) {
        final word = _clean(token);
        if (word.isNotEmpty) {
          _wordToIndices.putIfAbsent(word, () => []).add(index);
          index++;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Practice mode toggle
  // ---------------------------------------------------------------------------

  Future<void> togglePracticeMode() async {
    if (state.isPracticeMode) {
      // Turning off — stop listening if active
      if (state.isListening) await _stopListening();
      state = const ReaderPracticeState();
    } else {
      // Turning on — initialize speech
      _speechAvailable = await _speech.initialize(
        onError: (_) => state = state.copyWith(isListening: false),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _onListeningDone();
          }
        },
      );
      state = state.copyWith(isPracticeMode: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Listen controls
  // ---------------------------------------------------------------------------

  Future<void> startListening() async {
    if (!state.isPracticeMode || !_speechAvailable || state.isListening) return;

    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(partialResults: true),
    );
    state = state.copyWith(isListening: true, showCelebration: false);
  }

  Future<void> stopListening() async {
    if (!state.isListening) return;
    await _stopListening();
    _onListeningDone();
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    state = state.copyWith(isListening: false);
  }

  void _onListeningDone() {
    if (!state.isListening) return;
    state = state.copyWith(isListening: false);
    // Always celebrate as long as something was recognized
    if (state.spokenWordIndices.isNotEmpty) {
      state = state.copyWith(showCelebration: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Speech result — updates highlighted words in real time
  // ---------------------------------------------------------------------------

  void _onSpeechResult(SpeechRecognitionResult result) {
    final spokenWords = result.recognizedWords
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);

    final matched = <int>{};
    for (final word in spokenWords) {
      final indices = _wordToIndices[word];
      if (indices != null) matched.addAll(indices);
    }

    final updated = {...state.spokenWordIndices, ...matched};

    if (result.finalResult) {
      state = state.copyWith(
        spokenWordIndices: updated,
        isListening: false,
        // Celebrate if anything was recognized at all (encourages kids)
        showCelebration: result.recognizedWords.trim().isNotEmpty,
      );
    } else {
      state = state.copyWith(spokenWordIndices: updated);
    }
  }

  // ---------------------------------------------------------------------------
  // Page change — reset spoken words, keep practice mode on
  // ---------------------------------------------------------------------------

  void resetForPage() {
    state = state.copyWith(
      spokenWordIndices: {},
      showCelebration: false,
      isListening: false,
    );
    if (state.isListening) _speech.stop();
  }

  // ---------------------------------------------------------------------------
  // Celebration acknowledged
  // ---------------------------------------------------------------------------

  void acknowledgeCelebration() {
    state = state.copyWith(showCelebration: false);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _clean(String word) =>
      word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}

final readerPracticeProvider =
    StateNotifierProvider.autoDispose<ReaderPracticeNotifier, ReaderPracticeState>(
  (ref) => ReaderPracticeNotifier(),
);
