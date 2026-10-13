import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_providers.dart';
import '../../child/data/child_profile_providers.dart';
import '../domain/reading_checkpoint.dart';
import 'reading_checkpoint_repository.dart';

final readingCheckpointRepositoryProvider =
    FutureProvider<ReadingCheckpointRepository>((ref) async {
      return PreferencesReadingCheckpointRepository(
        await SharedPreferences.getInstance(),
      );
    });

/// Null while an authenticated reader identity is unresolved. Never substitute
/// guest history for an account whose child selection is loading.
final readingOwnerProvider = Provider<ReadingOwner?>((ref) {
  final session = ref.watch(authViewStateProvider).session;
  if (session == null) return const ReadingOwner.guest();
  final childId = ref.watch(activeChildProfileIdProvider);
  if (childId == null || childId.trim().isEmpty) return null;
  return ReadingOwner.child(userId: session.user.id, childId: childId);
});

final readingCheckpointProvider = FutureProvider.autoDispose
    .family<ReadingCheckpoint?, ({ReadingOwner owner, String bookId})>((
      ref,
      key,
    ) async {
      final repository = await ref.watch(
        readingCheckpointRepositoryProvider.future,
      );
      return repository.load(key.owner, key.bookId);
    });

final readerOpeningCheckpointProvider = FutureProvider.autoDispose
    .family<ReadingCheckpoint?, String>((ref, bookId) async {
      final owner = ref.watch(readingOwnerProvider);
      if (owner == null) return null;
      return ref.watch(
        readingCheckpointProvider((owner: owner, bookId: bookId)).future,
      );
    });

/// Unfinished reading outranks an explicitly saved next read, even when another
/// book was completed more recently. All records belong to the selected reader.
final readingContinuationProvider =
    FutureProvider.autoDispose<ReadingCheckpoint?>((ref) async {
      final owner = ref.watch(readingOwnerProvider);
      if (owner == null || owner.isGuest) return null;
      final repository = await ref.watch(
        readingCheckpointRepositoryProvider.future,
      );
      final records = await repository.loadAll(owner);
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      for (final record in records) {
        if (!record.completed) return record;
      }
      for (final record in records) {
        if (record.savedNextBookId != null) return record;
      }
      return null;
    });
