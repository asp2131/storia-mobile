import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/providers.dart';
import '../services/word_tts_service.dart';
import '../word_help/reader_word_help.dart';
import '../word_help/reader_word_help_adapters.dart';
import '../word_help/reader_word_help_engine.dart';
import 'reader_session_provider.dart';

final wordTtsServiceProvider = Provider<WordTtsService>((ref) {
  final service = WordTtsService();
  ref.onDispose(service.dispose);
  return service;
});

final readerWordHelpProvider =
    AutoDisposeNotifierProviderFamily<
      ReaderWordHelpController,
      WordHelpSnapshot,
      String
    >(ReaderWordHelpController.new);

class ReaderWordHelpController
    extends AutoDisposeFamilyNotifier<WordHelpSnapshot, String> {
  late final ReaderWordHelpEngine _engine;
  StreamSubscription<WordHelpSnapshot>? _snapshotSubscription;
  ReaderSessionAudioGuardPort? _audioGuardPort;

  @override
  WordHelpSnapshot build(String bookId) {
    final audioEngine = ref.watch(audioEngineProvider);
    final session = ref.watch(readerSessionProvider);
    final audioGuard = ReaderSessionAudioGuardPort(session);
    _audioGuardPort = audioGuard;

    _engine = ReaderWordHelpEngine(
      manifestPort: PronunciationRepositoryManifestPort(
        ref.watch(pronunciationRepositoryProvider),
      ),
      pronunciationAudio: AudioEnginePronunciationPort(audioEngine),
      fallbackSpeech: FlutterTtsFallbackSpeechPort(
        ref.watch(wordTtsServiceProvider),
      ),
      readerAudioGuard: audioGuard,
      analytics: ReaderAnalyticsWordHelpPort(
        ref.watch(readerAnalyticsTrackerProvider),
      ),
    );

    _snapshotSubscription = _engine.snapshots.listen((snapshot) {
      state = snapshot;
    });

    ref.onDispose(() {
      unawaited(_dispose());
    });

    return _engine.snapshot;
  }

  Future<WordHelpResult> play(WordHelpRequest request) => _engine.play(request);

  Future<void> cancel({
    WordHelpCancelReason reason = WordHelpCancelReason.user,
  }) => _engine.cancel(reason: reason);

  Future<void> _dispose() async {
    await _snapshotSubscription?.cancel();
    await _engine.dispose();
    await _audioGuardPort?.dispose();
  }
}
