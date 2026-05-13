import 'library_map_types.dart';

/// Base class for all library map domain events.
sealed class LibraryMapEvent {
  LibraryMapEvent() : occurredAt = DateTime.now();

  /// The [DateTime] at which this event was emitted.
  final DateTime occurredAt;
}

/// Fired when the map camera has moved (panning or walking).
final class LibraryMapCameraChanged extends LibraryMapEvent {
  LibraryMapCameraChanged({required this.cameraX, required this.viewport});

  /// The new camera X (world-coordinate of the visible left edge).
  final double cameraX;

  /// Snapshot of the current viewport.
  final LibraryMapViewport viewport;
}

/// Fired when the player arrives at a book node.
final class LibraryMapBookArrived extends LibraryMapEvent {
  LibraryMapBookArrived({required this.book, required this.arrivalMode});

  /// The book that was arrived at.
  final LibraryMapBook book;

  /// How the player arrived at this book.
  final ArrivalMode arrivalMode;
}

/// Fired when the user taps a book node on the map.
final class LibraryMapBookTapped extends LibraryMapEvent {
  LibraryMapBookTapped({required this.book});

  /// The book that was tapped.
  final LibraryMapBook book;
}

/// Fired when the set of visible book IDs changes.
final class LibraryMapVisibleBooksChanged extends LibraryMapEvent {
  LibraryMapVisibleBooksChanged({required this.visibleIds});

  /// The new set of visible book IDs.
  final Set<String> visibleIds;
}

/// Fired when the user selects a book from the browse-results panel.
final class LibraryMapBrowseBookSelected extends LibraryMapEvent {
  LibraryMapBrowseBookSelected({required this.book});

  /// The book that was selected.
  final LibraryMapBook book;
}
