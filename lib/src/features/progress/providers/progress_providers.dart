import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../child/providers/active_child_provider.dart';
import '../data/progress_repository.dart';
import '../domain/book_progress.dart';
import '../domain/continue_reading_item.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProgressRepository(supabase);
});

final continueReadingProvider = FutureProvider<ContinueReadingItem?>((
  ref,
) async {
  final child = await ref.watch(activeChildProvider.future);
  if (child == null) return null;

  final repo = ref.watch(progressRepositoryProvider);
  return repo.fetchContinueReading(childProfileId: child.id);
});

final bookProgressProvider = FutureProvider.family<BookProgress?, String>((
  ref,
  bookId,
) async {
  final child = await ref.watch(activeChildProvider.future);
  if (child == null) return null;

  final repo = ref.watch(progressRepositoryProvider);
  return repo.fetchBookProgress(
    childProfileId: child.id,
    bookId: bookId,
  );
});
