import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../progress/providers/progress_providers.dart';
import '../application/reading_session_coordinator.dart';
import '../data/reading_session_repository.dart';
import '../../../data/providers.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(apiClient: ref.watch(apiClientProvider));
});

final readingSessionRepositoryProvider =
    Provider<ReadingSessionRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ReadingSessionRepository(supabase, apiClient);
});

final readingSessionCoordinatorProvider =
    Provider<ReadingSessionCoordinator>((ref) {
  final coordinator = ReadingSessionCoordinator(
    progressRepository: ref.watch(progressRepositoryProvider),
    sessionRepository: ref.watch(readingSessionRepositoryProvider),
    analyticsService: ref.watch(analyticsServiceProvider),
  );

  ref.onDispose(coordinator.dispose);

  return coordinator;
});
