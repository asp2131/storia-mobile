import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/library/ports/library_map_session.dart';
import 'package:storia_kids/src/features/library/ports/library_map_types.dart';

/// A fake implementation of [LibraryMapEnginePort] that stores all calls
/// and provides deterministic test data.
///
/// Does not interact with any Flame internals.
class FakeLibraryMapEnginePort implements LibraryMapEnginePort {
  FakeLibraryMapEnginePort({this.onWalkToBook, this.onApplyFilter});

  /// Calls made to [walkToBook].
  final List<Book> walkToBookCalls = [];

  /// Calls made to [applyFilter].
  final List<Set<String>> applyFilterCalls = [];

  /// Values passed for [openPreviewOnArrival] in [walkToBook] calls.
  final List<bool> openPreviewOnArrivalCalls = [];

  /// Callback invoked with the book argument whenever [walkToBook] is called.
  void Function(Book book)? onWalkToBook;

  /// Callback invoked with the visible IDs whenever [applyFilter] is called.
  void Function(Set<String> ids)? onApplyFilter;

  // ── State ──────────────────────────────────────────────────────────────

  List<Book> loadedBooks = [];

  /// Camera X that listeners will observe.
  final TestValueNotifier<double> _cameraXNotifier = TestValueNotifier(0.0);

  /// Book the player has arrived at.
  final TestValueNotifier<Book?> _arrivedAtBook = TestValueNotifier<Book?>(
    null,
  );

  /// Last dimensions received by [loadBooks].
  double? lastScreenWidth;
  double? lastScreenHeight;

  /// Whether [dispose] was called.
  bool disposed = false;

  /// Manually set world width.
  double worldWidth = 0;

  /// Manually set node X per book ID.
  final Map<String, double> nodeXByBookId = {};

  /// Manually set screen position per book ID.
  final Map<String, ui.Offset> screenPositionByBookId = {};

  /// Browse results to return.
  List<Book> browseResults = [];

  /// Mutable set of visible IDs for [applyFilter].
  Set<String> currentVisibleIds = {};

  void setLoadedBooks(List<Book> books) {
    loadedBooks = books;
    currentVisibleIds = books.map((b) => b.id).toSet();
  }

  void simulateCameraChange(double x) {
    _cameraXNotifier.update(x);
  }

  void simulateArrival(Book book) {
    _arrivedAtBook.update(book);
  }

  int get cameraListenerCount => _cameraXNotifier.listenerCount;

  int get arrivalListenerCount => _arrivedAtBook.listenerCount;

  // ── LibraryMapEnginePort ───────────────────────────────────────────────

  @override
  void loadBooks(
    List<Book> books, {
    required double screenWidth,
    required double screenHeight,
  }) {
    loadedBooks = books;
    currentVisibleIds = books.map((b) => b.id).toSet();
    lastScreenWidth = screenWidth;
    lastScreenHeight = screenHeight;
  }

  @override
  void applyFilter(Set<String> visibleIds) {
    currentVisibleIds = visibleIds;
    applyFilterCalls.add(visibleIds);
    onApplyFilter?.call(visibleIds);
  }

  @override
  void walkToBook(Book book, {bool openPreviewOnArrival = true}) {
    walkToBookCalls.add(book);
    openPreviewOnArrivalCalls.add(openPreviewOnArrival);
    onWalkToBook?.call(book);
  }

  @override
  void navigateToBookNode(Book book) {
    walkToBookCalls.add(book);
    onWalkToBook?.call(book);
  }

  @override
  double? nodeXForBook(String bookId) => nodeXByBookId[bookId];

  @override
  ui.Offset? screenPositionOfBook(String bookId) =>
      screenPositionByBookId[bookId];

  @override
  List<Book> broaderBrowseResults({
    required String searchQuery,
    required LibraryMapLengthFilter filter,
    required Set<String> visibleIds,
    int limit = 8,
  }) => browseResults;

  @override
  ValueListenable<double> get cameraXNotifier => _cameraXNotifier;

  @override
  ValueListenable<Book?> get arrivedAtBook => _arrivedAtBook;

  @override
  void dispose() {
    disposed = true;
  }
}

/// A fake implementation of [LibraryMapCoverPort] that resolves covers
/// from an in-memory store, with optional pre-loaded images.
class InMemoryCoverStoreAdapter implements LibraryMapCoverPort {
  InMemoryCoverStoreAdapter({this.onLoadCover});

  /// All [loadCover] calls recorded in order.
  final List<LoadCoverCall> loadCoverCalls = [];

  /// Optional callback invoked for each [loadCover] call.
  void Function(String bookId, String url)? onLoadCover;

  /// In-memory image store keyed by (bookId, url).
  final Map<String, ui.Image?> _covers = {};

  /// Default image returned for unknown covers (can be overridden per-call
  /// by adding entries to [_covers] first).
  ui.Image? defaultMissingImage;

  /// Pre-loads a cover image for a specific book.
  void setCover(String bookId, String url, ui.Image? image) {
    _covers['$bookId:$url'] = image;
  }

  @override
  Future<ui.Image?> loadCover(String bookId, String url) async {
    loadCoverCalls.add(LoadCoverCall(bookId: bookId, url: url));
    onLoadCover?.call(bookId, url);
    return _covers['$bookId:$url'] ?? defaultMissingImage;
  }
}

class LoadCoverCall {
  const LoadCoverCall({required this.bookId, required this.url});
  final String bookId;
  final String url;
}

/// A [ValueListenable] that can be mutated by tests.
class TestValueNotifier<T> implements ValueListenable<T> {
  TestValueNotifier(this._value);

  T _value;
  final List<VoidCallback> _listeners = [];

  void update(T value) {
    _value = value;
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  T get value => _value;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  int get listenerCount => _listeners.length;
}
