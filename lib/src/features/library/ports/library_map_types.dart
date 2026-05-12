import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../data/models.dart';

/// Domain model for a book displayed on the library adventure map.
///
/// Wraps the source [Book] and enriches it with map-specific metadata
/// (node index, position on the route, vertical offset for terrain wander).
@immutable
class LibraryMapBook {
  const LibraryMapBook({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    required this.pageCount,
    required this.nodeIndex,
    required this.worldX,
    required this.worldY,
  });

  /// Creates a [LibraryMapBook] from a source [Book] and its computed node position.
  factory LibraryMapBook.fromBook(
    Book book, {
    required int nodeIndex,
    required double worldX,
    required double worldY,
  }) {
    return LibraryMapBook(
      id: book.id,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      pageCount: book.pageCount,
      nodeIndex: nodeIndex,
      worldX: worldX,
      worldY: worldY,
    );
  }

  /// Unique book identifier (matches [Book.id]).
  final String id;

  /// Display title.
  final String title;

  /// Author name, if known.
  final String? author;

  /// Remote cover image URL.
  final String? coverUrl;

  /// Number of pages.
  final int pageCount;

  /// Zero-based index in the adventure-map route order.
  final int nodeIndex;

  /// Horizontal world-coordinate of this book node's center.
  final double worldX;

  /// Vertical world-coordinate of this book node's center.
  final double worldY;

  /// Shortcut: page count ≤ 12 is a "quick read".
  bool get isQuickRead => pageCount <= 12;

  /// Converts this domain model back to the source [Book] (for read navigation).
  Book toBook() => Book(
        id: id,
        title: title,
        author: author,
        coverUrl: coverUrl,
        pageCount: pageCount,
        pages: const [],
      );

  /// World-space position of the node center.
  vm.Vector2 get nodePosition => vm.Vector2(worldX, worldY);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryMapBook &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Filter controlling which books are visible on the map.
enum LibraryMapLengthFilter {
  /// Show all books regardless of length.
  all,

  /// Show only quick reads (≤ 12 pages).
  quickReads,

  /// Show only longer reads (> 12 pages).
  longerReads,
}

/// User's active browsing intent for the map.
@immutable
class LibraryMapQuery {
  const LibraryMapQuery({
    this.searchText = '',
    this.lengthFilter = LibraryMapLengthFilter.all,
  });

  /// Free-text search terms (matched against title and author, case-insensitive).
  final String searchText;

  /// Active length filter.
  final LibraryMapLengthFilter lengthFilter;

  LibraryMapQuery copyWith({
    String? searchText,
    LibraryMapLengthFilter? lengthFilter,
  }) {
    return LibraryMapQuery(
      searchText: searchText ?? this.searchText,
      lengthFilter: lengthFilter ?? this.lengthFilter,
    );
  }

  /// Returns true when any filter is active.
  bool get hasActiveFilter =>
      searchText.trim().isNotEmpty || lengthFilter != LibraryMapLengthFilter.all;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryMapQuery &&
          runtimeType == other.runtimeType &&
          searchText == other.searchText &&
          lengthFilter == other.lengthFilter;

  @override
  int get hashCode => Object.hash(searchText, lengthFilter);
}

/// Describes the current viewport onto the map world.
@immutable
class LibraryMapViewport {
  const LibraryMapViewport({
    required this.screenWidth,
    required this.screenHeight,
    required this.cameraX,
    required this.worldWidth,
  });

  /// Visible screen width in pixels.
  final double screenWidth;

  /// Visible screen height in pixels.
  final double screenHeight;

  /// World-coordinate of the left edge of the visible region.
  final double cameraX;

  /// Total width of the scrollable world.
  final double worldWidth;

  /// Horizontal scroll progress in [0, 1] (approximate).
  double get horizontalProgress {
    if (worldWidth <= screenWidth) return 0;
    final maxCameraX = worldWidth - screenWidth;
    return (cameraX / maxCameraX).clamp(0.0, 1.0);
  }

  /// Returns the visible world X range (left, right).
  (double, double) get visibleWorldRange => (
        cameraX,
        cameraX + screenWidth,
      );

  /// Returns the visible world X range as a closed interval.
  (double, double) get visibleWorldRangeValues => (
        cameraX,
        (cameraX + screenWidth).clamp(0.0, worldWidth),
      );
}

/// Controls how the player arrives at a book node.
enum ArrivalMode {
  /// Walk to the node and stop there.
  walk,

  /// Walk to the node and immediately open the book preview.
  walkAndPreview,

  /// Jump directly to the node without walking (no animation).
  jump,
}