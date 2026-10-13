import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/reader/data/reading_checkpoint_repository.dart';
import 'package:loratone/src/features/reader/domain/reading_checkpoint.dart';

const _sampleId = 'loratone-entry-sample';
const _guest = ReadingOwner.guest();
const _child = ReadingOwner.child(userId: 'parent-a', childId: 'reader-a');

ReadingCheckpoint _checkpoint(
  int index, {
  String bookId = _sampleId,
  String revision = '1',
  String? pageId,
  bool completed = false,
  String? savedNextBookId,
  DateTime? updatedAt,
}) => ReadingCheckpoint(
  bookId: bookId,
  contentRevision: revision,
  pageId: pageId ?? 'page-$index',
  pageIndex: index,
  completed: completed,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 5),
  savedNextBookId: savedNextBookId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingCheckpoint encoding', () {
    test('round trips completion, revision, time and saved next book', () {
      final checkpoint = _checkpoint(
        4,
        completed: true,
        savedNextBookId: 'catalog-next',
        updatedAt: DateTime.parse('2026-10-05T12:30:00+02:00'),
      );
      final json = checkpoint.toJson();
      final restored = ReadingCheckpoint.fromJson(jsonDecode(jsonEncode(json)));

      expect(json['version'], 1);
      expect(restored.bookId, _sampleId);
      expect(restored.contentRevision, '1');
      expect(restored.pageId, 'page-4');
      expect(restored.pageIndex, 4);
      expect(restored.completed, isTrue);
      expect(restored.updatedAt, DateTime.utc(2026, 10, 5, 10, 30));
      expect(restored.savedNextBookId, 'catalog-next');
    });

    test('does not encode invalid const checkpoint values', () {
      for (final checkpoint in [
        _checkpoint(-1),
        _checkpoint(0, bookId: ' '),
        _checkpoint(0, revision: ' '),
        _checkpoint(0, pageId: ' '),
        _checkpoint(0, savedNextBookId: ' '),
      ]) {
        expect(checkpoint.toJson, throwsArgumentError);
      }
    });
  });

  group('PreferencesReadingCheckpointRepository', () {
    late SharedPreferences preferences;
    late PreferencesReadingCheckpointRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = PreferencesReadingCheckpointRepository(preferences);
    });

    test('persists complete records across repository recreation', () async {
      await repository.save(
        _guest,
        _checkpoint(4, completed: true, savedNextBookId: 'catalog-next'),
      );
      await preferences.reload();
      final restored = await PreferencesReadingCheckpointRepository(
        preferences,
      ).load(_guest, _sampleId);

      expect(restored!.pageIndex, 4);
      expect(restored.completed, isTrue);
      expect(restored.savedNextBookId, 'catalog-next');
    });

    test(
      'claim never replaces a child position without confirmation',
      () async {
        await repository.save(_child, _checkpoint(4));
        await repository.save(_guest, _checkpoint(2));

        final result = await repository.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: false,
        );

        expect(result, CheckpointClaimResult.existingProgress);
        expect((await repository.load(_child, _sampleId))!.pageIndex, 4);
        expect((await repository.load(_guest, _sampleId))!.pageIndex, 2);
      },
    );

    test(
      'explicit replacement copies the guest and retains its record',
      () async {
        await repository.save(_child, _checkpoint(4));
        await repository.save(
          _guest,
          _checkpoint(2, savedNextBookId: 'catalog-next'),
        );

        expect(
          await repository.claimSample(
            child: _child,
            bookId: _sampleId,
            replaceExisting: true,
          ),
          CheckpointClaimResult.saved,
        );
        expect((await repository.load(_child, _sampleId))!.pageIndex, 2);
        expect(
          (await repository.load(_child, _sampleId))!.savedNextBookId,
          'catalog-next',
        );
        expect((await repository.load(_guest, _sampleId))!.pageIndex, 2);
      },
    );

    test(
      'repeat claim is already saved and never rewrites the timestamp',
      () async {
        await repository.save(_guest, _checkpoint(2, completed: true));
        expect(
          await repository.claimSample(
            child: _child,
            bookId: _sampleId,
            replaceExisting: false,
          ),
          CheckpointClaimResult.saved,
        );
        final childTime = DateTime.utc(2026, 10, 6);
        await repository.save(
          _child,
          _checkpoint(2, completed: true, updatedAt: childTime),
        );

        expect(
          await repository.claimSample(
            child: _child,
            bookId: _sampleId,
            replaceExisting: false,
          ),
          CheckpointClaimResult.alreadySaved,
        );
        expect(
          (await repository.load(_child, _sampleId))!.updatedAt,
          childTime,
        );
        expect((await repository.load(_guest, _sampleId))!.completed, isTrue);
      },
    );

    test(
      'same index with different revision or completion is a conflict',
      () async {
        await repository.save(_guest, _checkpoint(2));
        for (final existing in [
          _checkpoint(2, revision: '2'),
          _checkpoint(2, completed: true),
          _checkpoint(2, pageId: 'different-page'),
        ]) {
          await repository.save(_child, existing);
          expect(
            await repository.claimSample(
              child: _child,
              bookId: _sampleId,
              replaceExisting: false,
            ),
            CheckpointClaimResult.existingProgress,
          );
        }
      },
    );

    test(
      'missing guest is an explicit error even with an existing child',
      () async {
        await repository.save(_child, _checkpoint(3));
        await expectLater(
          repository.claimSample(
            child: _child,
            bookId: _sampleId,
            replaceExisting: false,
          ),
          throwsStateError,
        );
        expect((await repository.load(_child, _sampleId))!.pageIndex, 3);
      },
    );

    test('account and child switches cannot inherit another claim', () async {
      const otherChild = ReadingOwner.child(
        userId: 'parent-a',
        childId: 'reader-b',
      );
      const otherAccount = ReadingOwner.child(
        userId: 'parent-b',
        childId: 'reader-a',
      );
      await repository.save(_guest, _checkpoint(2));
      await repository.claimSample(
        child: _child,
        bookId: _sampleId,
        replaceExisting: false,
      );

      expect(await repository.load(otherChild, _sampleId), isNull);
      expect(await repository.load(otherAccount, _sampleId), isNull);
      expect(await repository.loadAll(otherChild), isEmpty);
      expect(await repository.loadAll(otherAccount), isEmpty);
      expect((await repository.load(_child, _sampleId))!.pageIndex, 2);
      expect((await repository.load(_guest, _sampleId))!.pageIndex, 2);
    });

    test(
      'owner IDs are scoped without delimiter collisions or raw IDs',
      () async {
        const first = ReadingOwner.child(userId: 'parent/reader', childId: 'a');
        const second = ReadingOwner.child(
          userId: 'parent',
          childId: 'reader/a',
        );
        await repository.save(first, _checkpoint(1));
        await repository.save(second, _checkpoint(3));

        expect((await repository.load(first, _sampleId))!.pageIndex, 1);
        expect((await repository.load(second, _sampleId))!.pageIndex, 3);
        for (final key in preferences.getKeys()) {
          expect(key, isNot(contains('parent')));
          expect(key, isNot(contains('reader/a')));
          final json = jsonDecode(preferences.getString(key)!) as Map;
          expect(json.containsKey('userId'), isFalse);
          expect(json.containsKey('childId'), isFalse);
          expect(json.containsKey('email'), isFalse);
          expect(json.containsKey('name'), isFalse);
        }
      },
    );

    test('blank owner IDs are rejected upon repository use', () async {
      for (final owner in const [
        ReadingOwner.child(userId: ' ', childId: 'reader'),
        ReadingOwner.child(userId: 'parent', childId: ''),
      ]) {
        await expectLater(
          repository.load(owner, _sampleId),
          throwsArgumentError,
        );
        await expectLater(
          repository.save(owner, _checkpoint(0)),
          throwsArgumentError,
        );
        await expectLater(repository.loadAll(owner), throwsArgumentError);
        await expectLater(repository.removeOwner(owner), throwsArgumentError);
        await expectLater(
          repository.claimSample(
            child: owner,
            bookId: _sampleId,
            replaceExisting: false,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        repository.claimSample(
          child: _guest,
          bookId: _sampleId,
          replaceExisting: false,
        ),
        throwsArgumentError,
      );
    });

    test(
      'loadAll keeps unfinished and saved-next records across books',
      () async {
        await repository.save(_child, _checkpoint(1, bookId: 'unfinished'));
        await repository.save(
          _child,
          _checkpoint(
            3,
            bookId: 'finished',
            completed: true,
            savedNextBookId: 'next',
            updatedAt: DateTime.utc(2026, 10, 6),
          ),
        );
        await repository.save(_guest, _checkpoint(2, bookId: 'guest-only'));

        final records = await repository.loadAll(_child);
        expect(records.map((record) => record.bookId), [
          'finished',
          'unfinished',
        ]);
        expect(records.first.savedNextBookId, 'next');
        expect(records.last.completed, isFalse);
      },
    );

    test(
      'removeOwner removes only the exact account-child namespace',
      () async {
        const otherChild = ReadingOwner.child(
          userId: 'parent-a',
          childId: 'reader-b',
        );
        await repository.save(_child, _checkpoint(1));
        await repository.save(_child, _checkpoint(2, bookId: 'second'));
        await repository.save(otherChild, _checkpoint(3));
        await repository.save(_guest, _checkpoint(4));
        await preferences.setString('unrelated', 'keep');

        await repository.removeOwner(_child);

        expect(await repository.loadAll(_child), isEmpty);
        expect((await repository.load(otherChild, _sampleId))!.pageIndex, 3);
        expect((await repository.load(_guest, _sampleId))!.pageIndex, 4);
        expect(preferences.getString('unrelated'), 'keep');
      },
    );

    test(
      'corrupt, mismatched and unknown-version records are ignored',
      () async {
        await repository.save(_guest, _checkpoint(2, completed: true));
        final key = preferences.getKeys().single;
        final valid = _checkpoint(2, completed: true).toJson();
        final corruptRecords = <Object>[
          '{broken',
          '[]',
          123,
          jsonEncode({...valid, 'version': 999}),
          jsonEncode({...valid, 'version': 1.0}),
          jsonEncode({...valid, 'bookId': 'another-book'}),
          jsonEncode({...valid, 'contentRevision': ''}),
          jsonEncode({...valid, 'pageId': ' '}),
          jsonEncode({...valid, 'pageIndex': -1}),
          jsonEncode({...valid, 'pageIndex': 2.5}),
          jsonEncode({...valid, 'completed': 'true'}),
          jsonEncode({...valid, 'updatedAt': 'not-a-date'}),
          jsonEncode({...valid, 'savedNextBookId': 12}),
        ];
        for (final value in corruptRecords) {
          if (value is String) {
            await preferences.setString(key, value);
          } else {
            await preferences.setInt(key, value as int);
          }
          expect(await repository.load(_guest, _sampleId), isNull);
          expect(await repository.loadAll(_guest), isEmpty);
        }
      },
    );

    test(
      'loadAll retains healthy books when a different record is corrupt',
      () async {
        await repository.save(_guest, _checkpoint(2));
        final corruptKey = preferences.getKeys().single;
        await repository.save(_guest, _checkpoint(1, bookId: 'healthy'));
        await preferences.setString(corruptKey, '{broken');

        final records = await repository.loadAll(_guest);
        expect(records.single.bookId, 'healthy');
        expect(records.single.pageIndex, 1);
      },
    );
  });

  group('queued persistence and failures', () {
    late _ControlledPreferences preferences;
    late PreferencesReadingCheckpointRepository repository;

    setUp(() {
      preferences = _ControlledPreferences();
      repository = PreferencesReadingCheckpointRepository(preferences);
    });

    test(
      'older writes cannot finish after a newer save on the same book',
      () async {
        final firstSave = repository.save(_guest, _checkpoint(1));
        final firstWrite = await preferences.nextWrite();
        final secondSave = repository.save(_guest, _checkpoint(3));
        await Future<void>.delayed(Duration.zero);
        expect(preferences.startedWrites, 1);

        firstWrite.complete(true);
        await firstSave;
        final secondWrite = await preferences.nextWrite();
        secondWrite.complete(true);
        await secondSave;
        preferences.restoreDurableCache();

        expect((await repository.load(_guest, _sampleId))!.pageIndex, 3);
      },
    );

    test('different books do not wait on an unrelated pending write', () async {
      final firstSave = repository.save(_guest, _checkpoint(1));
      final firstWrite = await preferences.nextWrite();
      final otherSave = repository.save(
        _guest,
        _checkpoint(2, bookId: 'other'),
      );
      final otherWrite = await preferences.nextWrite();
      otherWrite.complete(true);
      await otherSave;
      expect((await repository.load(_guest, 'other'))!.pageIndex, 2);
      firstWrite.complete(true);
      await firstSave;
    });

    test(
      'failure is surfaced and does not poison the next queued save',
      () async {
        final firstSave = repository.save(_guest, _checkpoint(1));
        final failed = expectLater(firstSave, throwsStateError);
        final firstWrite = await preferences.nextWrite();
        final secondSave = repository.save(_guest, _checkpoint(3));
        firstWrite.complete(false);
        await failed;
        final secondWrite = await preferences.nextWrite();
        secondWrite.complete(true);
        await secondSave;
        preferences.restoreDurableCache();

        expect((await repository.load(_guest, _sampleId))!.pageIndex, 3);
      },
    );

    test(
      'failed claim never erases guest or exposes optimistic child data',
      () async {
        await _saveControlled(repository, preferences, _guest, _checkpoint(2));
        final claim = repository.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: false,
        );
        final failed = expectLater(claim, throwsStateError);
        (await preferences.nextWrite()).complete(false);
        await failed;

        final recreated = PreferencesReadingCheckpointRepository(preferences);
        expect(await recreated.load(_child, _sampleId), isNull);
        expect(await recreated.loadAll(_child), isEmpty);
        expect((await recreated.load(_guest, _sampleId))!.pageIndex, 2);
        final retry = recreated.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: false,
        );
        (await preferences.nextWrite()).complete(true);
        expect(await retry, CheckpointClaimResult.saved);
        expect((await recreated.load(_child, _sampleId))!.pageIndex, 2);
      },
    );

    test(
      'thrown replacement write retains the existing child checkpoint',
      () async {
        await _saveControlled(repository, preferences, _child, _checkpoint(4));
        await _saveControlled(repository, preferences, _guest, _checkpoint(2));
        final claim = repository.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: true,
        );
        final failed = expectLater(claim, throwsStateError);
        (await preferences.nextWrite()).completeError(
          StateError('storage unavailable'),
        );
        await failed;

        expect((await repository.load(_child, _sampleId))!.pageIndex, 4);
        expect((await repository.load(_guest, _sampleId))!.pageIndex, 2);
      },
    );

    test(
      'claims await guest writes and cannot overtake newer child saves',
      () async {
        final guestSave = repository.save(_guest, _checkpoint(2));
        final guestWrite = await preferences.nextWrite();
        final claim = repository.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: false,
        );
        final childSave = repository.save(_child, _checkpoint(4));
        guestWrite.complete(true);
        await guestSave;
        final claimWrite = await preferences.nextWrite();
        claimWrite.complete(true);
        expect(await claim, CheckpointClaimResult.saved);
        final childWrite = await preferences.nextWrite();
        childWrite.complete(true);
        await childSave;
        preferences.restoreDurableCache();

        expect((await repository.load(_child, _sampleId))!.pageIndex, 4);
        expect((await repository.load(_guest, _sampleId))!.pageIndex, 2);
      },
    );

    test(
      'a pending child save is observed by the claim conflict check',
      () async {
        await _saveControlled(repository, preferences, _guest, _checkpoint(2));
        final childSave = repository.save(_child, _checkpoint(4));
        final childWrite = await preferences.nextWrite();
        final claim = repository.claimSample(
          child: _child,
          bookId: _sampleId,
          replaceExisting: false,
        );
        childWrite.complete(true);
        await childSave;

        expect(await claim, CheckpointClaimResult.existingProgress);
        expect((await repository.load(_child, _sampleId))!.pageIndex, 4);
      },
    );

    test(
      'repository instances sharing preferences share write ordering',
      () async {
        final otherRepository = PreferencesReadingCheckpointRepository(
          preferences,
        );
        final firstSave = repository.save(_guest, _checkpoint(1));
        final firstWrite = await preferences.nextWrite();
        final secondSave = otherRepository.save(_guest, _checkpoint(3));
        await Future<void>.delayed(Duration.zero);
        expect(preferences.startedWrites, 1);
        firstWrite.complete(true);
        await firstSave;
        (await preferences.nextWrite()).complete(true);
        await secondSave;

        expect((await repository.load(_guest, _sampleId))!.pageIndex, 3);
      },
    );

    test(
      'removeOwner waits for saves and orders later saves after removal',
      () async {
        final firstSave = repository.save(_child, _checkpoint(1));
        final firstWrite = await preferences.nextWrite();
        final removal = repository.removeOwner(_child);
        final laterSave = repository.save(
          _child,
          _checkpoint(3, bookId: 'later'),
        );
        firstWrite.complete(true);
        await firstSave;
        await removal;
        (await preferences.nextWrite()).complete(true);
        await laterSave;
        preferences.restoreDurableCache();

        expect(await repository.load(_child, _sampleId), isNull);
        expect((await repository.loadAll(_child)).single.bookId, 'later');
      },
    );

    test('failed removal remains visible and can be retried', () async {
      await _saveControlled(repository, preferences, _child, _checkpoint(2));
      preferences.failNextRemoval = true;
      await expectLater(repository.removeOwner(_child), throwsStateError);
      expect((await repository.load(_child, _sampleId))!.pageIndex, 2);
      expect((await repository.loadAll(_child)).single.pageIndex, 2);

      await repository.removeOwner(_child);
      expect(await repository.loadAll(_child), isEmpty);
    });
  });

  group('checkpoint content resolution', () {
    test('changed revision prefers a surviving page ID over its old index', () {
      final resolved = resolveReadingCheckpoint(
        checkpoint: _checkpoint(1, pageId: 'page-b', completed: true),
        contentRevision: '2',
        pageIds: const ['page-new', 'page-a', 'page-b', 'page-c'],
      );
      expect(resolved.contentRevision, '2');
      expect(resolved.pageId, 'page-b');
      expect(resolved.pageIndex, 2);
      expect(resolved.completed, isFalse);
    });

    test('missing page ID falls back to a clamped valid index', () {
      final resolved = resolveReadingCheckpoint(
        checkpoint: _checkpoint(8, completed: true),
        contentRevision: '2',
        pageIds: const ['new-a', 'new-b'],
      );
      expect(resolved.pageId, 'new-b');
      expect(resolved.pageIndex, 1);
      expect(resolved.completed, isFalse);
    });

    test(
      'completion is retained only for a valid terminal page in its revision',
      () {
        final terminal = resolveReadingCheckpoint(
          checkpoint: _checkpoint(1, completed: true, savedNextBookId: 'next'),
          contentRevision: '1',
          pageIds: const ['page-0', 'page-1'],
        );
        final nonterminal = resolveReadingCheckpoint(
          checkpoint: _checkpoint(0, completed: true),
          contentRevision: '1',
          pageIds: const ['page-0', 'page-1'],
        );
        expect(terminal.completed, isTrue);
        expect(terminal.savedNextBookId, 'next');
        expect(nonterminal.completed, isFalse);
      },
    );

    test(
      'changed terminal revision does not silently mark new content completed',
      () {
        final resolved = resolveReadingCheckpoint(
          checkpoint: _checkpoint(1, completed: true),
          contentRevision: '2',
          pageIds: const ['page-0', 'page-1'],
        );
        expect(resolved.pageIndex, 1);
        expect(resolved.completed, isFalse);
      },
    );

    test(
      'cannot resolve unavailable content into a fake page zero checkpoint',
      () {
        expect(
          () => resolveReadingCheckpoint(
            checkpoint: _checkpoint(2),
            contentRevision: '2',
            pageIds: const [],
          ),
          throwsArgumentError,
        );
      },
    );

    test('catalog revision is stable SHA256 of ordered unambiguous IDs', () {
      expect(
        catalogContentRevision(const ['page-0', 'page-1']),
        '55dc082e853f74020429aec0a720c5755ef4a4fa9761648a1c03d4e949c5e622',
      );
      expect(
        catalogContentRevision(const ['page-1', 'page-0']),
        isNot(catalogContentRevision(const ['page-0', 'page-1'])),
      );
      expect(
        catalogContentRevision(const ['ab', 'c']),
        isNot(catalogContentRevision(const ['a', 'bc'])),
      );
    });
  });
}

Future<void> _saveControlled(
  PreferencesReadingCheckpointRepository repository,
  _ControlledPreferences preferences,
  ReadingOwner owner,
  ReadingCheckpoint checkpoint,
) async {
  final saving = repository.save(owner, checkpoint);
  (await preferences.nextWrite()).complete(true);
  await saving;
}

// Models the legacy plugin's optimistic cache separately from durable storage.
// All exercised repository operations are real; only the preferences boundary
// controls the completion/failure of the asynchronous platform write.
class _ControlledPreferences implements SharedPreferences {
  final _cache = <String, Object>{};
  final _durable = <String, Object>{};
  final _unreadWrites = Queue<Completer<bool>>();
  final _writeWaiters = Queue<Completer<Completer<bool>>>();
  int startedWrites = 0;
  bool failNextRemoval = false;

  Future<Completer<bool>> nextWrite() {
    if (_unreadWrites.isNotEmpty) {
      return Future.value(_unreadWrites.removeFirst());
    }
    final waiter = Completer<Completer<bool>>();
    _writeWaiters.add(waiter);
    return waiter.future;
  }

  void restoreDurableCache() {
    _cache
      ..clear()
      ..addAll(_durable);
  }

  @override
  Object? get(String key) => _cache[key];

  @override
  Set<String> getKeys() => _cache.keys.toSet();

  @override
  Future<bool> setString(String key, String value) async {
    _cache[key] = value;
    startedWrites += 1;
    final write = Completer<bool>();
    if (_writeWaiters.isEmpty) {
      _unreadWrites.add(write);
    } else {
      _writeWaiters.removeFirst().complete(write);
    }
    final successful = await write.future;
    if (successful) _durable[key] = value;
    return successful;
  }

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    if (failNextRemoval) {
      failNextRemoval = false;
      return false;
    }
    _durable.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
