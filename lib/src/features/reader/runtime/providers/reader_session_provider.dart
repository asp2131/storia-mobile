import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/providers.dart';
import '../adapters/flutter_scheduler_port.dart';
import '../adapters/speech_to_text_practice_port.dart';
import '../reader_analytics_tracker.dart';
import '../reader_session.dart';
import '../reader_session_impl.dart';

final readerAnalyticsTrackerProvider = Provider<ReaderAnalyticsTracker>((ref) {
  return ReaderAnalyticsTracker(
    analyticsRepository: ref.watch(analyticsRepositoryProvider),
  );
});

final readerSessionProvider = Provider<ReaderSession>((ref) {
  final pageAudio = ref.watch(pageAudioProvider);
  final session = ReaderSessionImpl(
    pageAudio: pageAudio,
    speechPort: SpeechToTextPracticePort(),
    scheduler: FlutterSchedulerPort(),
    analyticsTracker: ref.watch(readerAnalyticsTrackerProvider),
  );

  ref.onDispose(() {
    session.dispose();
  });

  return session;
});
