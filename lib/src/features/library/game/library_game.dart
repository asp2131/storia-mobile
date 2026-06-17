import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../data/models.dart';
import 'ambient_particles.dart';
import 'character/character_types.dart';
import 'isometric_ground_component.dart';
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

    // Add isometric TMX ground map behind everything else.
    final groundBaseline = worldHeight * 0.72;
    _world.add(
      IsometricGroundComponent(
        groundBaselineY: groundBaseline,
        worldWidth: worldWidth,
        screenHeight: worldHeight,
      )..priority = -1,
    );

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

    _setRouteHighlightForNodeIndex(_currentNodeIndex);

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
          final file = await ResilientCacheManager.instance.getSingleFile(url);
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

  /// Update map-node visibility based on the active filter.
  void applyFilter(Set<String> visibleBookIds) {
    _visibleBookIds
      ..clear()
      ..addAll(visibleBookIds);

    for (final entry in _bookComponents.entries) {
      entry.value.isVisible = visibleBookIds.contains(entry.key);
    }

    _routeComponent?.setVisibleNodePositions(_visibleNodePositions());
    _setRouteHighlightForNodeIndex(_currentNodeIndex);
  }

  List<int> _visibleNodeIndexes() {
    final indexes = <int>[];
    for (var i = 0; i < _books.length; i++) {
      if (_visibleBookIds.contains(_books[i].id)) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  List<Vector2> _visibleNodePositions() => _visibleNodeIndexes()
      .map((index) => _nodePositions[index].clone())
      .toList(growable: false);

  bool _isNodeIndexVisible(int index) {
    if (index < 0 || index >= _books.length) return false;
    return _visibleBookIds.contains(_books[index].id);
  }

  int? _visibleRouteIndexForNodeIndex(int? nodeIndex) {
    if (nodeIndex == null || !_isNodeIndexVisible(nodeIndex)) return null;
    final visibleIndexes = _visibleNodeIndexes();
    final routeIndex = visibleIndexes.indexOf(nodeIndex);
    return routeIndex < 0 ? null : routeIndex;
  }

  void _setRouteHighlightForNodeIndex(int? nodeIndex) {
    _routeComponent?.setHighlightToNodeIndex(
      _visibleRouteIndexForNodeIndex(nodeIndex),
    );
  }

  @visibleForTesting
  Map<String, bool> get debugNodeVisibilityByBookId => {
    for (final entry in _bookComponents.entries)
      entry.key: entry.value.isVisible,
  };

  @visibleForTesting
  List<String> get debugVisibleRouteBookIds => _visibleNodeIndexes()
      .map((index) => _books[index].id)
      .toList(growable: false);

  @visibleForTesting
  List<Vector2> get debugVisibleRouteNodePositions =>
      _routeComponent?.visibleNodePositions ?? const <Vector2>[];

  @visibleForTesting
  List<String> debugRouteWaypointBookIdsForTap({
    required double worldX,
    required Vector2 fromPosition,
  }) {
    if (_nodePositions.isEmpty) return const [];

    final visibleIndexes = _visibleNodeIndexes();
    if (visibleIndexes.isEmpty) return const [];

    final targetIndex = _findNearestNodeIndexByX(
      worldX.clamp(0.0, worldWidth),
      candidateIndexes: visibleIndexes,
    );
    return _buildRouteWaypoints(
      targetIndex,
      fromPosition: fromPosition,
    ).map(_bookIdForNodePosition).whereType<String>().toList(growable: false);
  }

  String? _bookIdForNodePosition(Vector2 position) {
    for (var i = 0; i < _nodePositions.length; i++) {
      if (_nodePositions[i].distanceTo(position) < 0.001) {
        return _books[i].id;
      }
    }
    return null;
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
  int _findNearestNodeIndex(Vector2 pos, {List<int>? candidateIndexes}) {
    if (_nodePositions.isEmpty) return 0;
    final candidates =
        candidateIndexes ??
        List<int>.generate(_nodePositions.length, (index) => index);
    if (candidates.isEmpty) return 0;

    var nearest = candidates.first;
    double bestDist = double.infinity;
    for (final index in candidates) {
      final dist = _nodePositions[index].distanceTo(pos);
      if (dist < bestDist) {
        bestDist = dist;
        nearest = index;
      }
    }
    return nearest;
  }

  /// Find the index of the route node nearest to a world-space X coordinate.
  int _findNearestNodeIndexByX(double worldX, {List<int>? candidateIndexes}) {
    if (_nodePositions.isEmpty) return 0;
    final candidates =
        candidateIndexes ??
        List<int>.generate(_nodePositions.length, (index) => index);
    if (candidates.isEmpty) return 0;

    var nearest = candidates.first;
    double bestDist = double.infinity;
    for (final index in candidates) {
      final dist = (_nodePositions[index].x - worldX).abs();
      if (dist < bestDist) {
        bestDist = dist;
        nearest = index;
      }
    }
    return nearest;
  }

  /// Build a waypoint list from the player's current position through the
  /// visible route nodes to the target node index. If the target is hidden
  /// (possible only through programmatic navigation), fall back to the full
  /// route so existing non-filter entry points still work.
  List<Vector2> _buildRouteWaypoints(int targetIndex, {Vector2? fromPosition}) {
    final candidates = _isNodeIndexVisible(targetIndex)
        ? _visibleNodeIndexes()
        : List<int>.generate(_nodePositions.length, (index) => index);
    if (candidates.isEmpty) return const [];

    final nearestIndex = _findNearestNodeIndex(
      fromPosition ?? _player.position,
      candidateIndexes: candidates,
    );
    final nearestRouteIndex = candidates.indexOf(nearestIndex);
    final targetRouteIndex = candidates.indexOf(targetIndex);
    if (nearestRouteIndex < 0 || targetRouteIndex < 0) return const [];

    final waypoints = <Vector2>[];
    if (nearestRouteIndex <= targetRouteIndex) {
      for (var i = nearestRouteIndex; i <= targetRouteIndex; i++) {
        waypoints.add(_nodePositions[candidates[i]].clone());
      }
    } else {
      for (var i = nearestRouteIndex; i >= targetRouteIndex; i--) {
        waypoints.add(_nodePositions[candidates[i]].clone());
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

    // Find the nearest visible route node to the tapped X and walk there along
    // the filtered route. Hidden nodes are visually gone and should not act as
    // invisible destinations.
    final visibleIndexes = _visibleNodeIndexes();
    if (visibleIndexes.isEmpty) {
      _setRouteHighlightForNodeIndex(null);
      return;
    }

    final targetIndex = _findNearestNodeIndexByX(
      clampedX,
      candidateIndexes: visibleIndexes,
    );

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
    _setRouteHighlightForNodeIndex(targetIndex);

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
      final newX = _cameraX;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        cameraXNotifier.value = newX;
      });
    }
  }

  void _checkBookArrival() {
    if (_pendingBookTargetX == null) return;

    if (_player.hasArrived) {
      _player.playOneShot(CharacterAnimation.interact);
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
        _setRouteHighlightForNodeIndex(arrivedIndex);
      }

      if (_pendingBook != null) {
        arrivedAtBook.value = _pendingBook;
      }
      _pendingBook = null;
      _pendingBookTargetX = null;
    } else if (_destinationNodeIndex != null) {
      final destination = _destinationNodeIndex!;
      if (!_isNodeIndexVisible(destination)) {
        _setRouteHighlightForNodeIndex(null);
        return;
      }

      final visibleIndexes = _visibleNodeIndexes();
      final progressNode = _findNearestNodeIndex(
        _player.position,
        candidateIndexes: visibleIndexes.isEmpty ? null : visibleIndexes,
      );
      _setRouteHighlightForNodeIndex(progressNode);
    }
  }
}
