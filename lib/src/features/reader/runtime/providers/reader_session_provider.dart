import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../adapters/audio_engine_audio_port.dart';
import '../adapters/flutter_scheduler_port.dart';
import '../adapters/speech_to_text_practice_port.dart';
import '../reader_session.dart';
import '../reader_session_impl.dart';

final readerSessionProvider = Provider<ReaderSession>((ref) {
  final audioEngine = ref.watch(audioEngineProvider);
  final session = ReaderSessionImpl(
    audioPort: AudioEngineAudioPort(audioEngine),
    speechPort: SpeechToTextPracticePort(),
    scheduler: FlutterSchedulerPort(),
  );

  ref.onDispose(() {
    session.dispose();
  });

  return session;
});
