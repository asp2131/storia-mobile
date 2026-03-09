import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// A singleton [CacheManager] that guards against SQLITE_BUSY errors.
///
/// The default [CacheManager] from `flutter_cache_manager` can throw
/// `DatabaseException(database is locked (code 5 SQLITE_BUSY))` when the app
/// was previously force-killed and a stale SQLite lock-file remains.
///
/// This class:
///   1. Ensures a true single instance (compile-time singleton).
///   2. Deletes stale `-wal` and `-shm` lock files on first access so the
///      database can be opened cleanly.
///   3. Uses a dedicated cache key to avoid collisions with any other cache.
class ResilientCacheManager {
  ResilientCacheManager._();

  static const _key = 'storiaImageCache';

  static CacheManager? _instance;

  /// Returns the singleton [CacheManager], creating it on first call.
  ///
  /// On the very first invocation it also cleans up stale SQLite WAL/SHM files
  /// left behind by a previous crashed process.
  static Future<CacheManager> getInstance() async {
    if (_instance != null) return _instance!;

    await _cleanStaleLockFiles();

    _instance = CacheManager(
      Config(
        _key,
        stalePeriod: const Duration(days: 14),
        maxNrOfCacheObjects: 200,
      ),
    );

    return _instance!;
  }

  /// Synchronous accessor for use after [getInstance] has been awaited once
  /// (e.g. in widget build methods). Falls back to [DefaultCacheManager] if
  /// called before initialisation -- this is safe because [DefaultCacheManager]
  /// is itself a singleton.
  static CacheManager get instance => _instance ?? DefaultCacheManager();

  /// Remove stale WAL/SHM journal files that cause SQLITE_BUSY on re-open.
  static Future<void> _cleanStaleLockFiles() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, '$_key.db');

      for (final suffix in ['-wal', '-shm']) {
        final file = File('$dbPath$suffix');
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Also clean the default cache manager's DB that was previously crashing.
      final filesDir = await getApplicationDocumentsDirectory();
      // The default DB lives next to the files directory.
      final parent = filesDir.parent;
      final defaultDbPath = p.join(
        parent.path,
        'files',
        'libCachedImageData.db',
      );
      for (final suffix in ['-wal', '-shm']) {
        final file = File('$defaultDbPath$suffix');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {
      // Best-effort cleanup -- swallow errors so the app can still start.
    }
  }
}
