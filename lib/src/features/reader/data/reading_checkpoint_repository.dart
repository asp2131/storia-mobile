import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reading_checkpoint.dart';

abstract interface class ReadingCheckpointRepository {
  Future<ReadingCheckpoint?> load(ReadingOwner owner, String bookId);
  Future<void> save(ReadingOwner owner, ReadingCheckpoint checkpoint);
  Future<List<ReadingCheckpoint>> loadAll(ReadingOwner owner);
  Future<CheckpointClaimResult> claimSample({
    required ReadingOwner child,
    required String bookId,
    required bool replaceExisting,
  });
  Future<void> removeOwner(ReadingOwner owner);
}

/// Local, single-isolate persistence. Claims copy first and retain guest data;
/// SharedPreferences does not provide crash-atomic multi-key transactions.
class PreferencesReadingCheckpointRepository
    implements ReadingCheckpointRepository {
  PreferencesReadingCheckpointRepository(SharedPreferences preferences)
    : _store = _stores[preferences] ??= _CheckpointStore(preferences);

  // Sharing the preferences instance also shares queues and confirmed values,
  // including across provider/repository recreation after an account switch.
  static final _stores = Expando<_CheckpointStore>();
  static const _namespace = 'reading_checkpoints.v1.';
  final _CheckpointStore _store;

  @override
  Future<ReadingCheckpoint?> load(ReadingOwner owner, String bookId) async {
    final prefix = _ownerPrefix(owner);
    final key = _bookKey(prefix, bookId);
    return _store.forRecords([key], [prefix], () => _read(key, bookId: bookId));
  }

  @override
  Future<void> save(ReadingOwner owner, ReadingCheckpoint checkpoint) async {
    final prefix = _ownerPrefix(owner);
    final key = _bookKey(prefix, checkpoint.bookId);
    final encoded = jsonEncode(checkpoint.toJson());
    await _store.forRecords([key], [prefix], () => _store.write(key, encoded));
  }

  @override
  Future<List<ReadingCheckpoint>> loadAll(ReadingOwner owner) async {
    final prefix = _ownerPrefix(owner);
    return _store.forOwner(prefix, () {
      final records = <ReadingCheckpoint>[];
      for (final key in _store.keysForOwner(prefix)) {
        final record = _read(key);
        if (record != null && _bookKey(prefix, record.bookId) == key) {
          records.add(record);
        }
      }
      records.sort((a, b) {
        final timeOrder = b.updatedAt.compareTo(a.updatedAt);
        return timeOrder != 0 ? timeOrder : a.bookId.compareTo(b.bookId);
      });
      return records;
    });
  }

  @override
  Future<CheckpointClaimResult> claimSample({
    required ReadingOwner child,
    required String bookId,
    required bool replaceExisting,
  }) async {
    final childPrefix = _ownerPrefix(child);
    if (child.isGuest) {
      throw ArgumentError('A sample can only be claimed by a child.', 'child');
    }
    final guestPrefix = _ownerPrefix(const ReadingOwner.guest());
    final guestKey = _bookKey(guestPrefix, bookId);
    final childKey = _bookKey(childPrefix, bookId);
    return _store.forRecords(
      [guestKey, childKey],
      [guestPrefix, childPrefix],
      () async {
        final guest = _read(guestKey, bookId: bookId);
        if (guest == null) {
          throw StateError('There is no valid guest checkpoint to save.');
        }
        final existing = _read(childKey, bookId: bookId);
        if (existing != null) {
          if (_samePosition(existing, guest)) {
            return CheckpointClaimResult.alreadySaved;
          }
          if (!replaceExisting) return CheckpointClaimResult.existingProgress;
        }
        await _store.write(childKey, jsonEncode(guest.toJson()));
        return CheckpointClaimResult.saved;
      },
    );
  }

  @override
  Future<void> removeOwner(ReadingOwner owner) async {
    final prefix = _ownerPrefix(owner);
    await _store.forOwner(prefix, () async {
      final keys = _store.keysForOwner(prefix).toList()..sort();
      for (final key in keys) {
        await _store.remove(key);
      }
    });
  }

  ReadingCheckpoint? _read(String key, {String? bookId}) {
    final raw = _store.read(key);
    if (raw is! String) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final checkpoint = ReadingCheckpoint.fromJson(json);
      if (bookId != null && checkpoint.bookId != bookId) return null;
      return checkpoint;
    } on FormatException {
      // Leave corrupt/unsupported records untouched, but never restore their
      // page or completion flag. Other healthy books remain available.
      return null;
    }
  }

  static bool _samePosition(ReadingCheckpoint a, ReadingCheckpoint b) =>
      a.bookId == b.bookId &&
      a.contentRevision == b.contentRevision &&
      a.pageId == b.pageId &&
      a.pageIndex == b.pageIndex &&
      a.completed == b.completed;

  static String _ownerPrefix(ReadingOwner owner) {
    owner.validate();
    if (owner.isGuest) return '${_namespace}guest.';
    // Array encoding avoids delimiter collisions; hash opaque IDs so the
    // preference key does not expose account identifiers or personal data.
    final scope = _digest(jsonEncode([owner.userId, owner.childId]));
    return '${_namespace}child.$scope.';
  }

  static String _bookKey(String prefix, String bookId) {
    if (bookId.trim().isEmpty) {
      throw ArgumentError('bookId must not be blank.', 'bookId');
    }
    return '$prefix${_digest(bookId)}';
  }

  static String _digest(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}

class _CheckpointStore {
  _CheckpointStore(this.preferences);

  final SharedPreferences preferences;
  final _recordTails = <String, Future<void>>{};
  final _ownerBarriers = <String, Future<void>>{};

  // The legacy plugin updates its cache before platform persistence completes,
  // even when persistence returns false or throws. Retain the prior confirmed
  // view on failure so a retry is not incorrectly reported as alreadySaved.
  final _failedWriteValues = <String, Object?>{};

  Object? read(String key) => _failedWriteValues.containsKey(key)
      ? _failedWriteValues[key]
      : preferences.get(key);

  Iterable<String> keysForOwner(String prefix) => {
    ...preferences.getKeys(),
    ..._failedWriteValues.keys,
  }.where((key) => key.startsWith(prefix));

  Future<void> write(String key, String value) async {
    final previous = read(key);
    try {
      if (!await preferences.setString(key, value)) {
        throw StateError('The reading checkpoint could not be saved.');
      }
      _failedWriteValues.remove(key);
    } catch (_) {
      _failedWriteValues[key] = previous;
      rethrow;
    }
  }

  Future<void> remove(String key) async {
    final previous = read(key);
    try {
      if (!await preferences.remove(key)) {
        throw StateError('The reading checkpoint could not be removed.');
      }
      _failedWriteValues.remove(key);
    } catch (_) {
      _failedWriteValues[key] = previous;
      rethrow;
    }
  }

  /// Reserve all claim keys together before yielding. Waiting on failure-free
  /// gates ensures that one failed operation cannot poison later queued work.
  Future<T> forRecords<T>(
    List<String> keys,
    List<String> ownerPrefixes,
    FutureOr<T> Function() operation,
  ) {
    final dependencies = <Future<void>>[];
    for (final prefix in ownerPrefixes) {
      final barrier = _ownerBarriers[prefix];
      if (barrier != null) dependencies.add(barrier);
    }
    for (final key in keys) {
      final tail = _recordTails[key];
      if (tail != null) dependencies.add(tail);
    }
    final gate = Completer<void>();
    for (final key in keys) {
      _recordTails[key] = gate.future;
    }
    return _run(dependencies, operation, () {
      gate.complete();
      for (final key in keys) {
        if (identical(_recordTails[key], gate.future)) _recordTails.remove(key);
      }
    });
  }

  /// Owner-wide reads/removal wait on all prior book writes. Later writes see
  /// this barrier, so a delayed save cannot resurrect a removed owner record.
  Future<T> forOwner<T>(String prefix, FutureOr<T> Function() operation) {
    final dependencies = <Future<void>>[];
    final previousBarrier = _ownerBarriers[prefix];
    if (previousBarrier != null) dependencies.add(previousBarrier);
    for (final entry in _recordTails.entries) {
      if (entry.key.startsWith(prefix)) dependencies.add(entry.value);
    }
    final gate = Completer<void>();
    _ownerBarriers[prefix] = gate.future;
    return _run(dependencies, operation, () {
      gate.complete();
      if (identical(_ownerBarriers[prefix], gate.future)) {
        _ownerBarriers.remove(prefix);
      }
    });
  }

  static Future<T> _run<T>(
    List<Future<void>> dependencies,
    FutureOr<T> Function() operation,
    void Function() release,
  ) async {
    try {
      await Future.wait(dependencies);
      return await operation();
    } finally {
      release();
    }
  }
}
