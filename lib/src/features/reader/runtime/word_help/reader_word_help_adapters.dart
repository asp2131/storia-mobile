import 'dart:async';

import '../../../../audio/audio_engine.dart';
import '../../../../data/pronunciation_models.dart';
import '../../../../data/pronunciation_repository.dart';
import '../reader_analytics_tracker.dart';
import '../reader_intent.dart';
import '../reader_session.dart';
import '../reader_view_state.dart';
import '../services/word_tts_service.dart';
import 'reader_word_help.dart';

class PronunciationRepositoryManifestPort implements PronunciationManifestPort {
  const PronunciationRepositoryManifestPort(this._repository);

  final PronunciationRepository _repository;

  @override
  Future<BookPronunciationManifest?> getManifest(String bookId) =>
      _repository.getManifestForBook(bookId);
}

class AudioEnginePronunciationPort implements PronunciationAudioPort {
  const AudioEnginePronunciationPort(this._engine);

  final AudioEngine _engine;

  @override
  Stream<Duration> get position => _engine.pronunciationPosition;

  @override
  Future<void> playSequence(List<String> urls) =>
      _engine.playPronunciationSequence(urls);

  @override
  Future<void> stop() => _engine.stopPronunciation();
}

class FlutterTtsFallbackSpeechPort implements FallbackSpeechPort {
  const FlutterTtsFallbackSpeechPort(this._service);

  final WordTtsService _service;

  @override
  Future<void> speakWord(String word) => _service.speak(word);

  @override
  Future<void> speakBreakdown(String word) => _service.soundOut(word);

  @override
  Future<void> stop() => _service.stop();
}

class ReaderSessionAudioGuardPort implements ReaderAudioGuardPort {
  ReaderSessionAudioGuardPort(this._session) {
    _stateSubscription = _session.states.listen((state) {
      _lastState = state;
    });
  }

  final ReaderSession _session;
  ReaderViewState _lastState = const ReaderViewState.initial();
  StreamSubscription<ReaderViewState>? _stateSubscription;

  @override
  Stream<int> get pageChanges => _session.pageChanges;

  @override
  Future<ReaderAudioSnapshot> captureAndPause() async {
    final snapshot = ReaderAudioSnapshot(
      wasNarrationPlaying: _lastState.isNarrationPlaying,
      wasListening: _lastState.isListening,
    );
    if (snapshot.wasNarrationPlaying) {
      await _session.dispatch(
        const ReaderToggleNarration(source: ReaderIntentSource.runtime),
      );
    }
    if (snapshot.wasListening) {
      await _session.dispatch(const ReaderPauseListening());
    }
    return snapshot;
  }

  @override
  Future<void> restore(ReaderAudioSnapshot snapshot) async {
    if (snapshot.wasNarrationPlaying && !_lastState.isNarrationPlaying) {
      await _session.dispatch(
        const ReaderToggleNarration(source: ReaderIntentSource.runtime),
      );
    }
    if (snapshot.wasListening && !_lastState.isListening) {
      await _session.dispatch(const ReaderResumeListening());
    }
  }

  Future<void> dispose() async {
    await _stateSubscription?.cancel();
  }
}

class ReaderAnalyticsWordHelpPort implements WordHelpAnalyticsPort {
  const ReaderAnalyticsWordHelpPort(this._tracker);

  final ReaderAnalyticsTracker _tracker;

  @override
  void recordWordHelp({
    required int wordIndex,
    required WordHelpMode mode,
    required WordHelpOutcome outcome,
  }) {
    final outcomeName = switch (outcome) {
      WordHelpOutcome.pronunciationPlayed => 'played',
      WordHelpOutcome.fallbackPlayed => 'fallback',
      WordHelpOutcome.cancelled => 'cancelled',
      WordHelpOutcome.failed => 'error',
    };
    switch (mode) {
      case WordHelpMode.word:
        _tracker.recordWordAudioPlayed(
          wordIndex: wordIndex,
          outcome: outcomeName,
        );
      case WordHelpMode.breakdown:
        _tracker.recordPhonemeAudioPlayed(
          wordIndex: wordIndex,
          outcome: outcomeName,
        );
    }
  }
}
