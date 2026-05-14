import 'dart:ui' as ui;

import '../core/library_map_layout.dart';
import '../../../data/models.dart';
import '../ports/library_map_event.dart';
import '../ports/library_map_session.dart';
import '../ports/library_map_types.dart';

/// Default limit for browse results returned by [getBrowseResults].
const _browseResultsLimit = 8;

/// Concrete implementation of [LibraryMapSession].
///
/// Owns all state, connects the [LibraryMapEnginePort] (Flame), and emits
/// [LibraryMapEvent]s through the
/// registered callback.
///
/// Thread-safety: all public methods are designed to be called from the
/// Flutter main isolate. The engine and cover ports handle their own
/// background async work internally.
class LibraryMapSessionImpl implements LibraryMapSession {
  LibraryMapSessionImpl({required LibraryMapEnginePort enginePort})
    : _engine = enginePort;

  final LibraryMapEnginePort _engine;
  LibraryMapEventCallback? _onEvent;
  ArrivalMode _pendingArrivalMode = ArrivalMode.walkAndPreview;
  bool _hasPendingSessionNavigation = false;
  bool _isListeningToEngine = false;

  // ── Mutable state ────────────────────────────────────────────────────

  List<Book> _sourceBooks = [];

  final List<LibraryMapBook> _books = [];
  LibraryMapQuery _query = const LibraryMapQuery();
  LibraryMapLengthFilter _lengthFilter = LibraryMapLengthFilter.all;
  Set<String> _visibleBookIds = {};
  LibraryMapBook? _selectedNode;
  LibraryMapBook? _previewBook;
  double _cameraX = 0;
  double _screenWidth = 0;
  double _screenHeight = 0;

  // ── LibraryMapSession ────────────────────────────────────────────────

  @override
  List<LibraryMapBook> get books => List.unmodifiable(_books);

  @override
  LibraryMapQuery get query => _query;

  @override
  LibraryMapLengthFilter get lengthFilter => _lengthFilter;

  @override
  Set<String> get visibleBookIds => Set.unmodifiable(_visibleBookIds);

  @override
  LibraryMapBook? get selectedNode => _selectedNode;

  @override
  LibraryMapBook? get previewBook => _previewBook;

  @override
  double get cameraX => _cameraX;

  @override
  LibraryMapViewport get viewport => LibraryMapViewport(
    screenWidth: _screenWidth,
    screenHeight: _screenHeight,
    cameraX: _cameraX,
    worldWidth: _engineWorldWidth,
  );

  double get _engineWorldWidth => _screenWidth > 0
      ? LibraryMapLayout.computeWorldWidth(_sourceBooks.length, _screenWidth)
      : 0;

  @override
  void setEventCallback(LibraryMapEventCallback callback) {
    _onEvent = callback;
  }

  @override
  void setSearchText(String text) {
    _query = _query.copyWith(searchText: text);
    _applyQuery();
  }

  @override
  void setLengthFilter(LibraryMapLengthFilter filter) {
    _lengthFilter = filter;
    _query = _query.copyWith(lengthFilter: filter);
    _applyQuery();
  }

  @override
  void applyQuery(LibraryMapQuery query) {
    _query = query;
    _lengthFilter = query.lengthFilter;
    _applyQuery();
  }

  @override
  void navigateToBook(
    LibraryMapBook book, {
    ArrivalMode mode = ArrivalMode.walkAndPreview,
  }) {
    _selectedNode = book;
    _pendingArrivalMode = mode;
    _hasPendingSessionNavigation = true;
    _engine.walkToBook(
      book.toBook(),
      openPreviewOnArrival: mode == ArrivalMode.walkAndPreview,
    );
  }

  @override
  void selectBrowseResult(LibraryMapBook book) {
    _onEvent?.call(LibraryMapBrowseBookSelected(book: book));
    navigateToBook(book, mode: ArrivalMode.walk);
  }

  @override
  void dismissPreview() {
    _previewBook = null;
  }

  @override
  ui.Offset? screenPositionOfNode(LibraryMapBook book) {
    return _engine.screenPositionOfBook(book.id);
  }

  @override
  List<LibraryMapBook> getBrowseResults({int limit = _browseResultsLimit}) {
    final source = _engine.broaderBrowseResults(
      searchQuery: _query.searchText,
      filter: _query.lengthFilter,
      visibleIds: _visibleBookIds,
      limit: limit,
    );
    return source
        .map((book) => _toLibraryMapBook(book))
        .whereType<LibraryMapBook>()
        .toList(growable: false);
  }

  @override
  void dispose() {
    _stopListeningToEngine();
    _engine.dispose();
    _onEvent = null;
  }

  // ── Wiring ────────────────────────────────────────────────────────────

  /// Loads [books] into the engine and computes node positions.
  ///
  /// Called once when the session is first attached to a screen with a
  /// non-empty book list. Screen dimensions must be provided so world width
  /// and node positions can be computed.
  void loadBooks(
    List<Book> books, {
    required double screenWidth,
    required double screenHeight,
  }) {
    _sourceBooks = books;
    _screenWidth = screenWidth;
    _screenHeight = screenHeight;

    // Build domain models with computed positions.
    _books.clear();
    if (books.isNotEmpty) {
      final layout = LibraryMapLayout.build(
        sourceBooks: books,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      _books.addAll(layout.books);
    }

    // Initialise visible set to all books.
    _visibleBookIds = _books.map((b) => b.id).toSet();

    // Reloading can replace engine notifiers (real adapter) or reuse them
    // (tests/fakes). Detach before load, then attach exactly once.
    _stopListeningToEngine();

    // Load into Flame engine.
    _engine.loadBooks(
      books,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );

    _startListeningToEngine();

    _emitEvent(LibraryMapVisibleBooksChanged(visibleIds: _visibleBookIds));
  }

  /// Applies the current query (search text + length filter) to derive
  /// which books are visible on the map.
  void _applyQuery() {
    final normalizedQuery = _query.searchText.trim().toLowerCase();
    final filtered = _books
        .where((book) {
          final matchesSearch =
              normalizedQuery.isEmpty ||
              book.title.toLowerCase().contains(normalizedQuery) ||
              (book.author ?? '').toLowerCase().contains(normalizedQuery);
          final matchesFilter = switch (_query.lengthFilter) {
            LibraryMapLengthFilter.all => true,
            LibraryMapLengthFilter.quickReads => book.isQuickRead,
            LibraryMapLengthFilter.longerReads => !book.isQuickRead,
          };
          return matchesSearch && matchesFilter;
        })
        .map((b) => b.id)
        .toSet();

    if (filtered.isEmpty && _query.hasActiveFilter) {
      // If filter yields nothing, keep the old visible set so the user
      // can still navigate. This matches the original LibraryScreen behaviour.
      return;
    }

    _visibleBookIds = filtered;
    _engine.applyFilter(_visibleBookIds);
    _emitEvent(LibraryMapVisibleBooksChanged(visibleIds: _visibleBookIds));
  }

  void _onCameraChanged() {
    final newCameraX = _engine.cameraXNotifier.value;
    if ((newCameraX - _cameraX).abs() > 0.01) {
      _cameraX = newCameraX;
      _emitEvent(
        LibraryMapCameraChanged(cameraX: _cameraX, viewport: viewport),
      );
    }
  }

  void _onBookArrived() {
    final arrivedBook = _engine.arrivedAtBook.value;
    if (arrivedBook == null) return;

    final mapBook = _toLibraryMapBook(arrivedBook);
    if (mapBook == null) return;

    final arrivalMode = _hasPendingSessionNavigation
        ? _pendingArrivalMode
        : ArrivalMode.walkAndPreview;
    if (arrivalMode == ArrivalMode.walkAndPreview) {
      _previewBook = mapBook;
    }
    _selectedNode = mapBook;
    _hasPendingSessionNavigation = false;
    _pendingArrivalMode = ArrivalMode.walkAndPreview;
    _emitEvent(LibraryMapBookArrived(book: mapBook, arrivalMode: arrivalMode));
  }

  void _startListeningToEngine() {
    if (_isListeningToEngine) return;
    _engine.cameraXNotifier.addListener(_onCameraChanged);
    _engine.arrivedAtBook.addListener(_onBookArrived);
    _isListeningToEngine = true;
  }

  void _stopListeningToEngine() {
    if (!_isListeningToEngine) return;
    _engine.cameraXNotifier.removeListener(_onCameraChanged);
    _engine.arrivedAtBook.removeListener(_onBookArrived);
    _isListeningToEngine = false;
  }

  /// Converts a source [Book] to a [LibraryMapBook] using the precomputed
  /// position from [_books].
  LibraryMapBook? _toLibraryMapBook(Book book) {
    try {
      return _books.firstWhere((b) => b.id == book.id);
    } catch (_) {
      return null;
    }
  }

  void _emitEvent(LibraryMapEvent event) {
    _onEvent?.call(event);
  }
}
