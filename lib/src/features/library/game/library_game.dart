import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../data/models.dart';
import 'ambient_particles.dart';
import 'map_book_node_component.dart';
import 'map_route_component.dart';
import 'player_component.dart';

/// A Flame game that renders the player character walking through the library.
///
/// The background is transparent -- Flutter widgets behind the GameWidget
/// provide the room visuals. This game only handles the character and
/// tap-to-move interaction.
class LibraryGame extends FlameGame with TapCallbacks {
  LibraryGame({required this.worldWidth}) : _world = World(), super();

  /// Total scrollable width of the world (derived from book count).
  final double worldWidth;

  final World _world;

  late final PlayerComponent _player;

  /// Emits the [Book] the player has arrived at, or `null` when dismissed.
  final ValueNotifier<Book?> arrivedAtBook = ValueNotifier<Book?>(null);

  /// Notifies Flutter of camera X for syncing the background scroll.
  final ValueNotifier<double> cameraXNotifier = ValueNotifier<double>(0);

  /// The book the player is currently walking toward (if any).
  Book? _pendingBook;

  /// The X coordinate associated with the pending book.
  double? _pendingBookTargetX;

  /// Currently placed book node components keyed by book ID.
  final Map<String, MapBookNodeComponent> _bookComponents = {};

  /// The current route component (removed & replaced on reload).
  MapRouteComponent? _routeComponent;

  final List<Book> _books = [];
  final Map<String, int> _bookIndexes = {};
  final Map<String, double> _bookNodeCenterX = {};
  final Set<String> _visibleBookIds = <String>{};

  int? _currentNodeIndex;
  int? _destinationNodeIndex;

  /// Node positions calculated during [loadBooks], exposed for route-following.
  final List<Vector2> _nodePositions = [];

  /// Authored vertical offsets per node index to create terrain wander.
  /// Repeats cyclically so any number of books is supported.
  static const List<double> _verticalOffsets = [
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

  // ── Camera scroll state ──────────────────────────────────────────────
  double _cameraX = 0;

  /// Current camera X for external reading.
  double get cameraX => _cameraX;

  /// Fraction of the screen to look ahead in the movement direction.
  static const double _lookAheadFraction = 0.18;

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  ui.Color backgroundColor() => const ui.Color(0x00000000); // transparent

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.world = _world;
    await add(_world);

    final worldHeight = size.y;

    _player = PlayerComponent(
      startPosition: Vector2(worldWidth * 0.15, worldHeight * 0.72),
    );
    _world.add(_player);

    final initialLeftEdge = (_player.position.x - size.x / 2).clamp(
      0.0,
      (worldWidth - size.x).clamp(0.0, double.infinity),
    );
    _cameraX = initialLeftEdge;
    camera.viewfinder.position = Vector2(_cameraX + size.x / 2, size.y / 2);
    cameraXNotifier.value = _cameraX;

    // Subtle floating dust motes for cozy atmosphere.
    _world.add(
      AmbientParticlesComponent(
        worldWidth: worldWidth,
        worldHeight: worldHeight,
      ),
    );
  }

  // ── Book management ─────────────────────────────────────────────────

  /// Place books as adventure-map nodes along a winding route.
  ///
  /// [screenHeight] is the full viewport height, used to calculate the route
  /// baseline at ~72% of screen height.
  void loadBooks(List<Book> books, {required double screenHeight}) {
    _books
      ..clear()
      ..addAll(books);
    _bookIndexes
      ..clear()
      ..addEntries(
        books.indexed.map((entry) => MapEntry(entry.$2.id, entry.$1)),
      );
    _visibleBookIds
      ..clear()
      ..addAll(books.map((book) => book.id));
    _bookNodeCenterX.clear();
    _currentNodeIndex = books.isEmpty ? null : 0;
    _destinationNodeIndex = _currentNodeIndex;
    // Remove old components.
    for (final comp in _bookComponents.values) {
      comp.removeFromParent();
    }
    _bookComponents.clear();
    _nodePositions.clear();

    if (_routeComponent != null) {
      _routeComponent!.removeFromParent();
      _routeComponent = null;
    }

    if (books.isEmpty) return;

    // ── Calculate adventure-map node positions ──
    const double nodeWidth = 80;
    final routeBaseY = screenHeight * 0.72;
    final spacing = worldWidth / (books.length + 1);

    // Warm accent colors cycled per node.
    const accentColors = [
      ui.Color(0xFFFFB74D), // amber
      ui.Color(0xFFE8A0BF), // pink
      ui.Color(0xFFA5D6A7), // green
      ui.Color(0xFF90CAF9), // blue
    ];

    for (var i = 0; i < books.length; i++) {
      final x = spacing * (i + 1);
      final yOffset = _verticalOffsets[i % _verticalOffsets.length];
      _nodePositions.add(Vector2(x, routeBaseY + yOffset));
    }

    // ── Add route behind nodes ──
    _routeComponent = MapRouteComponent(nodePositions: _nodePositions);
    _world.add(_routeComponent!);

    // ── Add book node components ──
    for (var i = 0; i < books.length; i++) {
      final book = books[i];
      final nodePos = _nodePositions[i];
      final comp = MapBookNodeComponent(
        book: book,
        // Center the 80px-wide node on the route point.
        position: Vector2(nodePos.x - nodeWidth / 2, nodePos.y - 100),
        accentColor: accentColors[i % accentColors.length],
        onBookTapped: (tappedBook, targetX) {
          walkToBook(tappedBook, targetX + nodeWidth / 2);
        },
      );
      _bookNodeCenterX[book.id] = nodePos.x;
      comp.isSelected = i == _currentNodeIndex;
      _bookComponents[book.id] = comp;
      _world.add(comp);
    }

    _routeComponent?.setHighlightToNodeIndex(_currentNodeIndex);

    // Fire-and-forget parallel cover image loading.
    _loadCoverImages(books);
  }

  /// Asynchronously loads cover images for all books with a valid [coverUrl].
  ///
  /// Each image is fetched via [ResilientCacheManager], decoded into a
  /// `dart:ui` [ui.Image], wrapped in a [Sprite], and assigned to the
  /// corresponding [MapBookNodeComponent]. Failures are silently swallowed
  /// so the placeholder remains visible.
  void _loadCoverImages(List<Book> books) {
    final cacheManager = ResilientCacheManager.instance;

    for (final book in books) {
      final url = book.coverUrl;
      if (url == null || url.isEmpty) {
        // No URL — stop shimmer immediately.
        _bookComponents[book.id]?.isCoverLoading = false;
        continue;
      }

      // Fire-and-forget per book.
      () async {
        try {
          final file = await cacheManager.getSingleFile(url);
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final sprite = Sprite(frame.image);
          _bookComponents[book.id]?.coverSprite = sprite;
        } catch (_) {
          // Loading failed — stop shimmer, keep placeholder.
          _bookComponents[book.id]?.isCoverLoading = false;
        }
      }();
    }
  }

  /// Update dimmed state on book components based on filtered IDs.
  void applyFilter(Set<String> visibleBookIds) {
    _visibleBookIds
      ..clear()
      ..addAll(visibleBookIds);
    for (final entry in _bookComponents.entries) {
      entry.value.isDimmed = !visibleBookIds.contains(entry.key);
    }
  }

  Book? bookById(String bookId) {
    for (final book in _books) {
      if (book.id == bookId) return book;
    }
    return null;
  }

  List<Book> broaderBrowseResults({
    required String searchQuery,
    required dynamic filter,
    required Set<String> visibleIds,
    int limit = 8,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final results = <Book>[];
    bool matchesShelfFilter(Book book) {
      switch (filter.toString()) {
        case '_ShelfFilter.quick':
          return book.pageCount <= 12;
        case '_ShelfFilter.longer':
          return book.pageCount > 12;
        default:
          return true;
      }
    }

    for (final book in _books) {
      final matchesSearch =
          normalizedQuery.isEmpty ||
          book.title.toLowerCase().contains(normalizedQuery) ||
          (book.author ?? '').toLowerCase().contains(normalizedQuery);
      final matchesFilter = matchesShelfFilter(book);
      if (!matchesSearch || !matchesFilter || visibleIds.contains(book.id)) {
        continue;
      }
      results.add(book);
      if (results.length >= limit) break;
    }
    return results;
  }

  /// Returns the world-space center X of a book node, or `null` if not found.
  double? nodeXForBook(String bookId) {
    final comp = _bookComponents[bookId];
    if (comp == null) return null;
    return comp.position.x + comp.size.x / 2;
  }

  /// Returns the screen-space position of a book component (for overlay positioning).
  ui.Offset? screenPositionOfBook(String bookId) {
    final comp = _bookComponents[bookId];
    if (comp == null) return null;
    return ui.Offset(comp.position.x - _cameraX, comp.position.y);
  }

  // ── Tap handling ─────────────────────────────────────────────────────

  /// Find the index of the route node nearest to a given position.
  int _findNearestNodeIndex(Vector2 pos) {
    if (_nodePositions.isEmpty) return 0;
    int nearest = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _nodePositions.length; i++) {
      final dist = _nodePositions[i].distanceTo(pos);
      if (dist < bestDist) {
        bestDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  /// Build a waypoint list from the player's current position through
  /// intermediate route nodes to the target node index.
  List<Vector2> _buildRouteWaypoints(int targetIndex) {
    final waypoints = <Vector2>[];
    final nearestIndex = _findNearestNodeIndex(_player.position);

    if (nearestIndex <= targetIndex) {
      for (int i = nearestIndex; i <= targetIndex; i++) {
        waypoints.add(_nodePositions[i].clone());
      }
    } else {
      for (int i = nearestIndex; i >= targetIndex; i--) {
        waypoints.add(_nodePositions[i].clone());
      }
    }
    return waypoints;
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    // Convert screen-space tap to world-space X.
    final worldX = event.localPosition.x + _cameraX;
    final clampedX = worldX.clamp(0.0, worldWidth);

    // Clear any pending book arrival.
    arrivedAtBook.value = null;
    _pendingBook = null;
    _pendingBookTargetX = null;

    if (_nodePositions.isEmpty) {
      _player.targetX = clampedX;
      return;
    }

    // Find nearest route node to the tapped X and walk there along the route.
    int targetIndex = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _nodePositions.length; i++) {
      final dist = (_nodePositions[i].x - clampedX).abs();
      if (dist < bestDist) {
        bestDist = dist;
        targetIndex = i;
      }
    }

    final waypoints = _buildRouteWaypoints(targetIndex);
    if (waypoints.isNotEmpty) {
      _player.setWaypoints(waypoints);
    }
  }

  /// Command the player to walk to a book's position.
  ///
  /// When the player arrives the [arrivedAtBook] notifier will fire with [book].
  void walkToBook(
    Book book,
    double targetX, {
    bool openPreviewOnArrival = true,
  }) {
    arrivedAtBook.value = null;
    _pendingBook = openPreviewOnArrival ? book : null;
    _pendingBookTargetX = targetX.clamp(0.0, worldWidth);

    if (_nodePositions.isEmpty) {
      _player.targetX = _pendingBookTargetX!;
      return;
    }

    // Find target node index by matching X position.
    final targetIndex = _nodePositions.indexWhere(
      (pos) => (pos.x - _pendingBookTargetX!).abs() < 50,
    );

    if (targetIndex < 0) {
      // Fallback: walk straight if no matching node found.
      _player.targetX = _pendingBookTargetX!;
      return;
    }

    _destinationNodeIndex = targetIndex;
    _routeComponent?.setHighlightToNodeIndex(targetIndex);

    final waypoints = _buildRouteWaypoints(targetIndex);
    if (waypoints.isNotEmpty) {
      _player.setWaypoints(waypoints);
    }
  }

  void navigateToBookNode(Book book) {
    arrivedAtBook.value = null;
    final centerX = _bookNodeCenterX[book.id];
    if (centerX != null) {
      walkToBook(book, centerX, openPreviewOnArrival: false);
    }
  }

  // ── Update ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    _updateCamera();
    _checkBookArrival();
  }

  void _updateCamera() {
    final screenW = size.x;
    final minCenterX = screenW / 2;
    final maxCenterX = (worldWidth - screenW / 2).clamp(
      minCenterX,
      double.infinity,
    );

    final direction = _player.isMoving ? _player.horizontalDirection : 0;
    final lookAheadX = switch (direction) {
      > 0 => screenW * _lookAheadFraction,
      < 0 => -screenW * _lookAheadFraction,
      _ => 0.0,
    };

    final targetCenterX = (_player.position.x + lookAheadX).clamp(
      minCenterX,
      maxCenterX,
    );
    final currentCenterX = camera.viewfinder.position.x.clamp(
      minCenterX,
      maxCenterX,
    );
    final lerpT = (_player.isMoving ? 0.12 : 0.08).clamp(0.0, 1.0);
    final nextCenterX =
        ui.lerpDouble(currentCenterX, targetCenterX, lerpT) ?? targetCenterX;
    final clampedCenterX = nextCenterX.clamp(minCenterX, maxCenterX);

    camera.viewfinder.position = Vector2(clampedCenterX, size.y / 2);

    final nextCameraX = (clampedCenterX - screenW / 2).clamp(
      0.0,
      (worldWidth - screenW).clamp(0.0, double.infinity),
    );
    _cameraX = nextCameraX;

    if ((cameraXNotifier.value - _cameraX).abs() > 0.01) {
      cameraXNotifier.value = _cameraX;
    }
  }

  void _checkBookArrival() {
    if (_pendingBookTargetX == null) return;

    if (_player.hasArrived) {
      final arrivedIndex = _nodePositions.indexWhere(
        (pos) => (pos.x - _pendingBookTargetX!).abs() < 50,
      );
      if (arrivedIndex >= 0) {
        _currentNodeIndex = arrivedIndex;
        _destinationNodeIndex = arrivedIndex;
        for (final entry in _bookComponents.entries) {
          entry.value.isSelected = _bookIndexes[entry.key] == arrivedIndex;
        }
        final currentBook = _books[arrivedIndex];
        _bookComponents[currentBook.id]?.triggerArrivalFocus();
        _routeComponent?.setHighlightToNodeIndex(arrivedIndex);
      }

      if (_pendingBook != null) {
        arrivedAtBook.value = _pendingBook;
      }
      _pendingBook = null;
      _pendingBookTargetX = null;
    } else if (_destinationNodeIndex != null) {
      final destination = _destinationNodeIndex!;
      final progressNode = _findNearestNodeIndex(_player.position);
      final highlightedIndex = _currentNodeIndex == null
          ? progressNode
          : (_currentNodeIndex! <= destination
                ? progressNode.clamp(_currentNodeIndex!, destination)
                : progressNode.clamp(destination, _currentNodeIndex!));
      _routeComponent?.setHighlightToNodeIndex(highlightedIndex);
    }
  }
}
