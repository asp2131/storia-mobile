import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../data/models.dart';
import 'library_map_event.dart';
import 'library_map_types.dart';

/// Callback type for receiving domain events from the session.
typedef LibraryMapEventCallback = void Function(LibraryMapEvent event);

/// Port interface for the Flame-powered map engine.
///
/// All Flame internals (FlameGame, components, camera, notifiers) are hidden
/// behind this interface so the rest of the app is Flame-agnostic.
abstract class LibraryMapEnginePort {
  /// Starts the engine and places [books] as nodes on the map.
  ///
  /// Must be called before any other engine method.
  void loadBooks(List<Book> books, {required double screenHeight});

  /// Applies a visibility filter so only [visibleIds] are highlighted;
  /// books outside the set are dimmed.
  void applyFilter(Set<String> visibleIds);

  /// Navigates the player avatar to [book]'s node and fires a
  /// [LibraryMapBookArrived] event when the player arrives.
  void walkToBook(Book book, {bool openPreviewOnArrival = true});

  /// Navigates the player to [book]'s node without showing a preview.
  void navigateToBookNode(Book book);

  /// Returns the world-coordinate X of the center of [book]'s node,
  /// or `null` if the book has not been placed.
  double? nodeXForBook(String bookId);

  /// Returns the screen-space offset of [book]'s node top-left corner,
  /// or `null` if the book has not been placed.
  ui.Offset? screenPositionOfBook(String bookId);

  /// Returns all books that match [searchQuery] + [filter] but are NOT
  /// in [visibleIds] (used for the browse-results panel).
  List<Book> broaderBrowseResults({
    required String searchQuery,
    required LibraryMapLengthFilter filter,
    required Set<String> visibleIds,
    int limit = 8,
  });

  /// Stream of camera X updates (world-coordinate of visible left edge).
  ValueListenable<double> get cameraXNotifier;

  /// Stream of [Book] arrived events (fires when the player reaches a node).
  ValueListenable<Book?> get arrivedAtBook;

  /// Disposes engine resources.
  void dispose();
}

/// Port interface for cover image retrieval and decoding.
///
/// Implementations wrap [ResilientCacheManager] or any equivalent caching
/// layer and return decoded [ui.Image] ready for rendering.
abstract class LibraryMapCoverPort {
  /// Retrieves the cover image for [bookId] at [url], using the cache if
  /// available, and returns a decoded [ui.Image].
  ///
  /// Returns `null` if the image cannot be loaded or decoded.
  Future<ui.Image?> loadCover(String bookId, String url);
}

/// The main session interface for the library adventure map.
///
/// Owns all state (books, query, filter, visible nodes, selected node,
/// preview book, camera X) and orchestrates the [LibraryMapEnginePort]
/// and [LibraryMapCoverPort] adapters. Emits [LibraryMapEvent] events
/// through the [eventCallback].
///
/// Consumers (widgets, Riverpod providers) use this interface exclusively;
/// they have no direct reference to Flame or the cache manager.
abstract class LibraryMapSession {
  /// All books currently placed on the map.
  List<LibraryMapBook> get books;

  /// The active query (search text + length filter).
  LibraryMapQuery get query;

  /// The current length filter.
  LibraryMapLengthFilter get lengthFilter;

  /// IDs of books currently visible (not dimmed) on the map.
  Set<String> get visibleBookIds;

  /// The currently selected book node, or `null` if none.
  LibraryMapBook? get selectedNode;

  /// Book currently shown in the preview overlay, or `null`.
  LibraryMapBook? get previewBook;

  /// Current camera X (world-coordinate of visible left edge).
  double get cameraX;

  /// Current viewport snapshot.
  LibraryMapViewport get viewport;

  /// Registers a callback to receive domain events.
  void setEventCallback(LibraryMapEventCallback callback);

  /// Updates the search text and reapplies the filter.
  void setSearchText(String text);

  /// Updates the length filter and reapplies the filter.
  void setLengthFilter(LibraryMapLengthFilter filter);

  /// Applies the full query (search + length filter) and updates visible IDs.
  void applyQuery(LibraryMapQuery query);

  /// Navigates the player to [book]'s node.
  void navigateToBook(
    LibraryMapBook book, {
    ArrivalMode mode = ArrivalMode.walkAndPreview,
  });

  /// Navigates to a book from the browse-results panel (no preview).
  void selectBrowseResult(LibraryMapBook book);

  /// Dismisses the current preview overlay.
  void dismissPreview();

  /// Returns the screen-space position of [book]'s node, or `null`.
  ui.Offset? screenPositionOfNode(LibraryMapBook book);

  /// Returns books that match the current query but are not in [visibleBookIds]
  /// (used to populate the browse panel).
  List<LibraryMapBook> getBrowseResults({int limit = 8});

  /// Disposes the session and releases resources.
  void dispose();
}