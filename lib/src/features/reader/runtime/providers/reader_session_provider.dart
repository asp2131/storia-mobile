import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../core/resilient_cache_manager.dart';
import '../../../../data/providers.dart';
import '../adapters/flutter_scheduler_port.dart';
import '../adapters/speech_to_text_practice_port.dart';
import '../reader_analytics_tracker.dart';
import '../reader_session.dart';
import '../reader_session_impl.dart';

/// Completes when the illustration at [url] has decoded a frame (or errored), so
/// narration/soundscape can wait for the picture. Shares the reader's cache, so
/// the renderer's own decode is a cache hit — one fetch, not two.
Future<void> _awaitImageReady(String? url) {
  if (url == null || url.isEmpty) return Future<void>.value();
  final completer = Completer<void>();
  final stream = CachedNetworkImageProvider(
    url,
    cacheManager: ResilientCacheManager.instance,
  ).resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  void finish() {
    if (!completer.isCompleted) completer.complete();
    stream.removeListener(listener);
  }

  listener = ImageStreamListener(
    (_, __) => finish(),
    onError: (_, __) => finish(),
  );
  stream.addListener(listener);
  return completer.future;
}

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
    imageReadyProbe: _awaitImageReady,
  );

  ref.onDispose(() {
    session.dispose();
  });

  return session;
});
