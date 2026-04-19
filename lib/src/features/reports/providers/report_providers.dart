import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../child/providers/active_child_provider.dart';
import '../data/report_repository.dart';
import '../domain/report_summary.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportRepository(apiClient);
});

final selectedReportRangeProvider = StateProvider<String>((ref) => '30d');

final reportSummaryProvider = FutureProvider<ReportSummary?>((ref) async {
  final child = await ref.watch(activeChildProvider.future);
  if (child == null) return null;

  final range = ref.watch(selectedReportRangeProvider);
  final repo = ref.watch(reportRepositoryProvider);
  return repo.fetchSummary(childProfileId: child.id, range: range);
});
