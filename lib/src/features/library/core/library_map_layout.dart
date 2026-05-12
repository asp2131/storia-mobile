import 'dart:ui' as ui;

import 'package:vector_math/vector_math_64.dart' as vm;

import '../../../data/models.dart';
import '../ports/library_map_types.dart';

/// Layout constants used throughout the library map.
class LibraryMapLayoutConstants {
  const LibraryMapLayoutConstants._();

  /// Width of each book node in pixels.
  static const double nodeWidth = 80;

  /// Minimum total world width so the map is scrollable on small screens.
  static const double minWorldWidth = 600;

  /// Horizontal spacing factor used when computing world width from book count.
  /// A higher value means more space between nodes.
  static const double spacingPerNode = 160;

  /// Vertical offset cycle for terrain wander (mirrors the authored offsets
  /// from library_game.dart). Each node gets the offset at
  /// `index % _verticalOffsets.length`.
  static const List<double> verticalOffsets = [
    -18,
    8,
    -12,
    22,
    -5,
    15,
    -20,
    10,
    -8,
    25,
  ];
}

/// Pure domain class that computes the adventure-map layout from books
/// and the current viewport.
///
/// Contains no side-effects, no Flame references, and no mutable state.
/// Designed to be cheap to recompute on every frame.
class LibraryMapLayout {
  const LibraryMapLayout({
    required this.books,
    required this.screenWidth,
    required this.screenHeight,
    required this.worldWidth,
  });

  /// All books placed on the map with their precomputed node positions.
  final List<LibraryMapBook> books;

  /// Visible screen width in pixels.
  final double screenWidth;

  /// Visible screen height in pixels.
  final double screenHeight;

  /// Total width of the scrollable world in pixels.
  final double worldWidth;

  /// Y coordinate of the route baseline (ground line) as a fraction of
  /// screen height. Matches the 0.72 baseline used in LibraryGame.
  static const double routeBaselineFraction = 0.72;

  /// The route baseline Y in absolute screen pixels.
  double get routeBaselineY => screenHeight * routeBaselineFraction;

  /// Spacing between adjacent book nodes.
  double get nodeSpacing => worldWidth / (books.length + 1);

  /// Maximum possible camera X (right edge when scrolled fully left).
  double get maxCameraX =>
      (worldWidth - screenWidth).clamp(0.0, double.infinity);

  /// Returns the world X coordinate for node at [index].
  double nodeXAt(int index) => nodeSpacing * (index + 1);

  /// Returns the vertical offset for node at [index] using the authored
  /// terrain-wander offsets. Offsets cycle for books beyond the cycle length.
  double verticalOffsetAt(int index) {
    return LibraryMapLayoutConstants.verticalOffsets[
        index % LibraryMapLayoutConstants.verticalOffsets.length];
  }

  /// Returns the world Y coordinate (on the route) for node at [index].
  double nodeYAt(int index) => routeBaselineY + verticalOffsetAt(index);

  /// Returns the world-space center position of node at [index].
  vm.Vector2 nodePositionAt(int index) =>
      vm.Vector2(nodeXAt(index), nodeYAt(index));

  /// Returns the world-space position of node [book].
  vm.Vector2 nodePositionOfBook(LibraryMapBook book) =>
      nodePositionAt(book.nodeIndex);

  /// Computes a world width large enough to fit [bookCount] nodes with
  /// generous spacing, honouring the minimum width.
  ///
  /// Mirrors the [_worldWidthForBooks] logic from [LibraryScreen].
  static double computeWorldWidth(int bookCount, double screenWidth) {
    final needed =
        (bookCount + 1) * LibraryMapLayoutConstants.spacingPerNode;
    return needed.clamp(
      screenWidth.clamp(LibraryMapLayoutConstants.minWorldWidth, double.infinity),
      double.infinity,
    );
  }

  /// Builds a layout with [sourceBooks] placed at computed node positions,
  /// using [screenWidth] and [screenHeight] to calculate positions.
  static LibraryMapLayout build({
    required List<Book> sourceBooks,
    required double screenWidth,
    required double screenHeight,
  }) {
    final worldWidth = computeWorldWidth(sourceBooks.length, screenWidth);
    final routeBaseY = screenHeight * routeBaselineFraction;
    final spacing = worldWidth / (sourceBooks.length + 1);

    final books = List<LibraryMapBook>.generate(sourceBooks.length, (i) {
      final x = spacing * (i + 1);
      final yOffset = LibraryMapLayoutConstants.verticalOffsets[
          i % LibraryMapLayoutConstants.verticalOffsets.length];
      return LibraryMapBook.fromBook(
        sourceBooks[i],
        nodeIndex: i,
        worldX: x,
        worldY: routeBaseY + yOffset,
      );
    });

    return LibraryMapLayout(
      books: books,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      worldWidth: worldWidth,
    );
  }

  /// Returns the visible [LibraryMapBook] node IDs given the current camera X.
  Set<String> computeVisibleIds(double cameraX) {
    final visibleLeft = cameraX - LibraryMapLayoutConstants.nodeWidth;
    final visibleRight =
        cameraX + screenWidth + LibraryMapLayoutConstants.nodeWidth;

    return books
        .where((b) => b.worldX >= visibleLeft && b.worldX <= visibleRight)
        .map((b) => b.id)
        .toSet();
  }

  /// Returns the screen-space top-left offset of [book]'s node when the
  /// camera is at [cameraX], or `null` if the node is off-screen.
  ui.Offset? screenOffsetOfNode(LibraryMapBook book, double cameraX) {
    final nodeWorldX = book.worldX - LibraryMapLayoutConstants.nodeWidth / 2;
    final screenX = nodeWorldX - cameraX;
    if (screenX + LibraryMapLayoutConstants.nodeWidth < 0 ||
        screenX > screenWidth) {
      return null;
    }
    return ui.Offset(screenX, book.worldY);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryMapLayout &&
          runtimeType == other.runtimeType &&
          books.length == other.books.length &&
          screenWidth == other.screenWidth &&
          screenHeight == other.screenHeight &&
          worldWidth == other.worldWidth;

  @override
  int get hashCode =>
      Object.hash(books.length, screenWidth, screenHeight, worldWidth);
}