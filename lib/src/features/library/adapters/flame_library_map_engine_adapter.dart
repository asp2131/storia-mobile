import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../data/models.dart';
import '../game/library_game.dart';
import '../ports/library_map_session.dart';
import '../ports/library_map_types.dart';

/// Adapter that wraps the Flame [LibraryGame] behind the [LibraryMapEnginePort]
/// interface.
///
/// All Flame internals are encapsulated here: FlameGame, camera, components,
/// and notifiers are never exposed outside this file.
class FlameLibraryMapEngineAdapter implements LibraryMapEnginePort {
  FlameLibraryMapEngineAdapter._();

  static FlameLibraryMapEngineAdapter? _instance;

  /// Returns the shared singleton adapter instance.
  ///
  /// The underlying [LibraryGame] is lazily created on first [loadBooks] call.
  /// A new [LibraryGame] is created each time [loadBooks] is called to allow
  /// recreating the map with a different world width when the screen size
  /// changes.
  static FlameLibraryMapEngineAdapter get instance {
    return _instance ??= FlameLibraryMapEngineAdapter._();
  }

  LibraryGame? _game;

  @override
  void loadBooks(
    List<Book> books, {
    required double screenWidth,
    required double screenHeight,
  }) {
    // Dispose the old game and create a fresh one.
    _game?.dispose();
    _game = LibraryGame(
      worldWidth: _worldWidthForBooks(books.length, screenWidth),
    );
    _game!.loadBooks(books, screenHeight: screenHeight);
  }

  @override
  void applyFilter(Set<String> visibleIds) {
    _game?.applyFilter(visibleIds);
  }

  @override
  void walkToBook(Book book, {bool openPreviewOnArrival = true}) {
    final centerX = _game?.nodeXForBook(book.id);
    if (centerX != null) {
      _game?.walkToBook(
        book,
        centerX,
        openPreviewOnArrival: openPreviewOnArrival,
      );
    }
  }

  @override
  void navigateToBookNode(Book book) {
    _game?.navigateToBookNode(book);
  }

  @override
  double? nodeXForBook(String bookId) {
    return _game?.nodeXForBook(bookId);
  }

  @override
  ui.Offset? screenPositionOfBook(String bookId) {
    return _game?.screenPositionOfBook(bookId);
  }

  @override
  List<Book> broaderBrowseResults({
    required String searchQuery,
    required LibraryMapLengthFilter filter,
    required Set<String> visibleIds,
    int limit = 8,
  }) {
    return _game?.broaderBrowseResults(
          searchQuery: searchQuery,
          filter: _ShelfFilterAdapter.fromLibraryMapLengthFilter(filter),
          visibleIds: visibleIds,
          limit: limit,
        ) ??
        [];
  }

  @override
  ValueListenable<double> get cameraXNotifier {
    return _game?.cameraXNotifier ?? const _ConstantNotifier(0.0);
  }

  @override
  ValueListenable<Book?> get arrivedAtBook {
    return _game?.arrivedAtBook ?? const _ConstantNotifier<Book?>(null);
  }

  @override
  void dispose() {
    _game?.dispose();
    _game = null;
    _instance = null;
  }

  /// Mirrors [_worldWidthForBooks] from [LibraryScreen].
  static double _worldWidthForBooks(int count, double screenWidth) {
    const nodeSpacing = 160.0;
    const minWorldWidth = 600.0;
    final needed = (count + 1) * nodeSpacing;
    return needed.clamp(
      screenWidth.clamp(minWorldWidth, double.infinity),
      double.infinity,
    );
  }

  /// Returns the underlying [LibraryGame], exposed only for [LibraryMapScreen]
  /// to pass to `GameWidget`. **Do not call from business logic.**
  LibraryGame? get game => _game;
}

/// A [ValueListenable] that always returns the same value.
class _ConstantNotifier<T> implements ValueListenable<T> {
  const _ConstantNotifier(this._value);
  final T _value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  T get value => _value;
}

/// Adapter that bridges [LibraryMapLengthFilter] to the private [_ShelfFilter]
/// enum used inside [LibraryGame.broaderBrowseResults].
class _ShelfFilterAdapter {
  _ShelfFilterAdapter._();

  static _ShelfFilter fromLibraryMapLengthFilter(
    LibraryMapLengthFilter filter,
  ) {
    return switch (filter) {
      LibraryMapLengthFilter.all => _ShelfFilter.all,
      LibraryMapLengthFilter.quickReads => _ShelfFilter.quick,
      LibraryMapLengthFilter.longerReads => _ShelfFilter.longer,
    };
  }
}

/// Private shelf filter enum that mirrors the one in [LibraryScreen].
/// This copy exists so the adapter can map the public filter without
/// importing the private enum from [LibraryScreen].
enum _ShelfFilter { all, quick, longer }
