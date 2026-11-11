import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/data/reading_checkpoint_provider.dart';
import '../reader/domain/reading_checkpoint.dart';

/// Every book the selected reader has opened, most recent first. Guests have
/// no shelf: their checkpoints are not tied to a child.
final libraryShelfProvider =
    FutureProvider.autoDispose<List<ReadingCheckpoint>>((ref) async {
      final owner = ref.watch(readingOwnerProvider);
      if (owner == null || owner.isGuest) return const [];
      final repository = await ref.watch(
        readingCheckpointRepositoryProvider.future,
      );
      final records = await repository.loadAll(owner);
      return records..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });

/// Wall clock for the comics countdown; tests override it.
final libraryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Announced launch date for the comics banner; null until one is set.
// ponytail: hardcoded; move to remote config if launch dates change often.
final comicsLaunchProvider = Provider<DateTime?>((ref) => null);
