import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/resilient_cache_manager.dart';
import '../ports/library_map_session.dart';

/// Adapter that wraps [ResilientCacheManager] behind the [LibraryMapCoverPort]
/// interface.
///
/// Handles network fetch, cache management, and image decoding. Returns a
/// decoded [ui.Image] ready for rendering by the Flame engine.
class ResilientCoverStoreAdapter implements LibraryMapCoverPort {
  ResilientCoverStoreAdapter._();

  static LibraryMapCoverPort? _instance;

  /// Returns the shared singleton adapter instance.
  static LibraryMapCoverPort get instance {
    return _instance ??= ResilientCoverStoreAdapter._();
  }

  /// In-flight load promises keyed by book ID to avoid duplicate fetch
  /// attempts for the same cover while one is already loading.
  final Map<String, Future<ui.Image?>> _loading = {};

  @override
  Future<ui.Image?> loadCover(String bookId, String url) {
    if (url.isEmpty) return Future.value(null);

    // Return any already-in-flight promise for this book.
    final existing = _loading[bookId];
    if (existing != null) return existing;

    final promise = _doLoad(bookId, url);
    _loading[bookId] = promise;

    return promise;
  }

  Future<ui.Image?> _doLoad(String bookId, String url) async {
    try {
      final cacheManager = ResilientCacheManager.instance;
      final file = await cacheManager.getSingleFile(url);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e, s) {
      debugPrint('[ResilientCoverStoreAdapter] Failed to load cover '
          'for book $bookId ($url): $e\n$s');
      return null;
    } finally {
      // Allow a retry if the previous attempt failed.
      _loading.remove(bookId);
    }
  }
}