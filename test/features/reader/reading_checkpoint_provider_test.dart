import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/reader/data/reading_checkpoint_provider.dart';
import 'package:loratone/src/features/reader/domain/reading_checkpoint.dart';

const _a = ReadingOwner.child(userId: 'account', childId: 'a');
const _b = ReadingOwner.child(userId: 'account', childId: 'b');
ReadingCheckpoint _record(
  String id,
  int hour, {
  bool completed = false,
  String? next,
}) => ReadingCheckpoint(
  bookId: id,
  contentRevision: 'v1',
  pageId: 'page',
  pageIndex: 0,
  completed: completed,
  updatedAt: DateTime.utc(2026, 1, 1, hour),
  savedNextBookId: next,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'newest unfinished story outranks a later completed saved-next and another child',
    () async {
      final container = ProviderContainer(
        overrides: [readingOwnerProvider.overrideWithValue(_a)],
      );
      addTearDown(container.dispose);
      final repository = await container.read(
        readingCheckpointRepositoryProvider.future,
      );
      await repository.save(_a, _record('old-unfinished', 1));
      await repository.save(_a, _record('recent-unfinished', 2));
      await repository.save(
        _a,
        _record('finished', 3, completed: true, next: 'next'),
      );
      await repository.save(_b, _record('other-child', 4));
      final result = await container.read(readingContinuationProvider.future);
      expect(result!.bookId, 'recent-unfinished');
    },
  );

  test(
    'when all reads are finished the most recently saved next remains actionable',
    () async {
      final container = ProviderContainer(
        overrides: [readingOwnerProvider.overrideWithValue(_a)],
      );
      addTearDown(container.dispose);
      final repository = await container.read(
        readingCheckpointRepositoryProvider.future,
      );
      await repository.save(
        _a,
        _record('finished-without-next', 4, completed: true),
      );
      await repository.save(
        _a,
        _record('older-next', 1, completed: true, next: 'old'),
      );
      await repository.save(
        _a,
        _record('newer-next', 2, completed: true, next: 'new'),
      );
      final result = await container.read(readingContinuationProvider.future);
      expect(result!.savedNextBookId, 'new');
    },
  );
}
