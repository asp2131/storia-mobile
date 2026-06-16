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
    extends AutoDisposeFamilyNotifier<WordHelpSnapshot, String>
    implements ReaderWordHelp {
  late final ReaderWordHelpEngine _engine;
  final _snapshots = StreamController<WordHelpSnapshot>.broadcast();
  StreamSubscription<WordHelpSnapshot>? _snapshotSubscription;
  ReaderSessionAudioGuardPort? _audioGuardPort;

  @override
  WordHelpSnapshot build(String bookId) {
    final pronunciationAudio = ref.watch(pronunciationPlayerProvider);
    final session = ref.watch(readerSessionProvider);
    final audioGuard = ReaderSessionAudioGuardPort(session);
    _audioGuardPort = audioGuard;

    _engine = ReaderWordHelpEngine(
      manifestPort: PronunciationRepositoryManifestPort(
        ref.watch(pronunciationRepositoryProvider),
      ),
      pronunciationAudio: pronunciationAudio,
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
      if (!_snapshots.isClosed) {
        _snapshots.add(snapshot);
      }
    });

    ref.onDispose(() {
      unawaited(_dispose());
    });

    return _engine.snapshot;
  }

  @override
  WordHelpSnapshot get snapshot => state;

  @override
  Stream<WordHelpSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<WordHelpResult> play(WordHelpRequest request) => _engine.play(request);

  @override
  Future<void> cancel({
    WordHelpCancelReason reason = WordHelpCancelReason.user,
  }) => _engine.cancel(reason: reason);

  @override
  Future<void> dispose() => _dispose();

  Future<void> _dispose() async {
    await _snapshotSubscription?.cancel();
    await _engine.dispose();
    await _audioGuardPort?.dispose();
    if (!_snapshots.isClosed) {
      await _snapshots.close();
    }
  }
}
