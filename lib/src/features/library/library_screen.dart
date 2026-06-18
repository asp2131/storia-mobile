import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cue/cue.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:gooey/gooey.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/resilient_cache_manager.dart';
import '../../core/theme/storia_colors.dart';
import '../../core/theme/storia_motion.dart';
import '../../core/theme/storia_spacing.dart';
import '../../core/widgets/parental_gate.dart';
import '../../core/widgets/sketch_border.dart';
import '../../core/widgets/sketch_card.dart';
import '../../core/widgets/sketch_icon_button.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../character/data/character_selection_store.dart';
import 'adapters/flame_library_map_engine_adapter.dart';
import 'game/book_preview_overlay.dart';
import 'ports/library_map_event.dart';
import 'ports/library_map_types.dart';
import 'services/library_map_session_impl.dart';

// ── Shelf filter ────────────────────────────────────────────────────────
enum _ShelfFilter { all, quick, longer }

// ── Layout constants ────────────────────────────────────────────────────
const double _kNodeWidth = 80;

// ── Main screen ─────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, @visibleForTesting this.skyNow});

  @visibleForTesting
  final DateTime? skyNow;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  static const _searchDebounceDuration = Duration(milliseconds: 220);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  _ShelfFilter _activeFilter = _ShelfFilter.all;
  bool? _nightSkyOverride;

  late final FlameLibraryMapEngineAdapter _engineAdapter;
  late final LibraryMapSessionImpl _session;
  String? _loadedSignature;
  bool _isLoadingSession = false;

  @override
  void initState() {
    super.initState();
    // Own a per-screen Flame adapter so the game lifecycle is scoped to this
    // screen mount. Sharing a process-wide game left the Flame layer blank
    // (no character/book nodes) after returning to the app.
    _engineAdapter = FlameLibraryMapEngineAdapter.create();
    _session = LibraryMapSessionImpl(enginePort: _engineAdapter)
      ..setEventCallback(_handleSessionEvent);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // A FlameGame's render surface can be torn down while the app is
    // backgrounded; reusing the same game on resume re-attaches with an empty
    // world (sky/clouds still paint, but no ground/character/book nodes).
    // Force a fresh game on resume so the map is always rebuilt correctly.
    if (state == AppLifecycleState.resumed && mounted) {
      _loadedSignature = null;
      setState(() {});
    }
  }

  void _handleSessionEvent(LibraryMapEvent event) {
    if (!mounted || _isLoadingSession || event is LibraryMapCameraChanged) {
      return;
    }
    setState(() {});
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchQuery = '');
      _applyFilter();
      return;
    }
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
      _applyFilter();
    });
  }

  void _applyFilter() {
    _session.applyQuery(
      LibraryMapQuery(
        searchText: _searchQuery,
        lengthFilter: _activeFilter.toLibraryMapLengthFilter(),
      ),
    );
  }

  bool get _hasActiveBrowseQuery =>
      _searchQuery.trim().isNotEmpty || _activeFilter != _ShelfFilter.all;

  bool get _showBrowsePanel =>
      _hasActiveBrowseQuery && _broaderBrowseResults.isNotEmpty;

  List<Book> get _broaderBrowseResults => _session
      .getBrowseResults()
      .map((book) => book.toBook())
      .toList(growable: false);

  void _dismissPreview() {
    setState(_session.dismissPreview);
    _engineAdapter.game?.arrivedAtBook.value = null;
  }

  DateTime get _skyClock => widget.skyNow ?? DateTime.now();

  _SkyPalette get _skyPalette {
    final override = _nightSkyOverride;
    final clock = override == null ? _skyClock : _clockForSkyMode(override);
    return _SkyPalette.fromDateTime(clock);
  }

  DateTime _clockForSkyMode(bool night) {
    final now = _skyClock;
    return DateTime(now.year, now.month, now.day, night ? 22 : 12);
  }

  void _toggleSkyMode() {
    final currentlyNight = _skyPalette.isNight;
    setState(() => _nightSkyOverride = !currentlyNight);
  }

  void _onBrowsePanelBookTap(Book book) {
    final mapBook = _mapBookFor(book);
    if (mapBook == null) return;

    _session.dismissPreview();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _activeFilter = _ShelfFilter.all;
    });
    _applyFilter();
    _session.selectBrowseResult(mapBook);
  }

  LibraryMapBook? _mapBookFor(Book book) {
    for (final mapBook in _session.books) {
      if (mapBook.id == book.id) return mapBook;
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookLibraryProvider);

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: booksAsync.when(
        data: (books) => _buildGameView(context, books),
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          error: '$error',
          onRetry: () => ref.invalidate(bookLibraryProvider),
        ),
      ),
    );
  }

  Widget _buildGameView(BuildContext context, List<Book> books) {
    final screenSize = MediaQuery.sizeOf(context);
    final characterSelection =
        ref.watch(characterSelectionNotifierProvider).selection;
    _ensureSessionLoaded(
      books,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      characterSelectionHash: characterSelection.hashCode,
    );

    final game = _engineAdapter.game;
    if (game == null) {
      return const _LoadingState();
    }

    final worldWidth = _session.viewport.worldWidth;
    final skyPalette = _skyPalette;

    return Stack(
      children: [
        // Layer 1: Flutter-drawn room background (synced to camera).
        _RoomBackground(
          worldWidth: worldWidth,
          cameraNotifier: _engineAdapter.cameraXNotifier,
          palette: skyPalette,
        ),

        // Layer 1.5: Celestial body + drifting clouds in dead sky space.
        Positioned.fill(child: _SkyDecorations(palette: skyPalette)),

        // Layer 2: Flame game (transparent, character + book tap targets).
        Positioned.fill(child: GameWidget(game: game)),

        // Layer 3: Floating search + filter UI.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _FloatingControls(
            searchController: _searchController,
            activeFilter: _activeFilter,
            onSearchChanged: _handleSearchChanged,
            onFilterChanged: (filter) {
              setState(() => _activeFilter = filter);
              _applyFilter();
            },
            isNightSky: skyPalette.isNight,
            onSkyToggle: _toggleSkyMode,
            onCustomizeTap: () => context.push('/character'),
            onSettingsTap: () async {
              final passed = await ParentalGate.verify(context);
              if (!context.mounted || !passed) return;
              context.push('/settings');
            },
          ),
        ),

        // Layer 4: Browse panel for search/filter results.
        _BrowsePanel(
          show: _showBrowsePanel,
          books: _broaderBrowseResults,
          searchQuery: _searchQuery,
          activeFilter: _activeFilter,
          onBookTap: _onBrowsePanelBookTap,
        ),

        // Layer 5: Book preview overlay (reactive to camera movement).
        if (_session.previewBook != null) ...[
          // Dismiss scrim.
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissPreview,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x22000000)),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _engineAdapter.cameraXNotifier,
            builder: (context, _, __) {
              final previewMapBook = _session.previewBook!;
              final previewBook = previewMapBook.toBook();
              return BookPreviewOverlay(
                book: previewBook,
                position: _overlayPosition(previewMapBook),
                onRead: () {
                  final bookId = previewMapBook.id;
                  _dismissPreview();
                  context.push('/reader/$bookId');
                },
                onDismiss: _dismissPreview,
              );
            },
          ),
        ],
      ],
    );
  }

  void _ensureSessionLoaded(
    List<Book> books, {
    required double screenWidth,
    required double screenHeight,
    required int characterSelectionHash,
  }) {
    final signature = Object.hash(
      screenWidth,
      screenHeight,
      characterSelectionHash,
      Object.hashAll(books.map((book) => book.id)),
    ).toString();
    if (_loadedSignature == signature && _engineAdapter.game != null) return;

    _isLoadingSession = true;
    try {
      _session.loadBooks(
        books,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
      _loadedSignature = signature;
      _applyFilter();
    } finally {
      _isLoadingSession = false;
    }
  }

  Offset _overlayPosition(LibraryMapBook book) {
    final screenPos = _session.screenPositionOfNode(book);
    final screenSize = MediaQuery.sizeOf(context);
    if (screenPos == null) {
      return Offset(screenSize.width / 2, 200);
    }
    // Center horizontally above the book/node.
    const cardHalfWidth = 280 / 2; // matches BookPreviewOverlay._cardWidth
    const edgePadding = 12.0;
    const minTop = 16.0;
    final rawX = screenPos.dx + _kNodeWidth / 2;
    // Clamp so card doesn't overflow left or right screen edges.
    final clampedX = rawX.clamp(
      cardHalfWidth + edgePadding,
      screenSize.width - cardHalfWidth - edgePadding,
    );
    final clampedY = (screenPos.dy - 160).clamp(minTop, double.infinity);
    return Offset(clampedX, clampedY);
  }
}

// ── Living sky palette ─────────────────────────────────────────────────

class _SkyPalette {
  const _SkyPalette({
    required this.skyTop,
    required this.skyHorizon,
    required this.hillBack,
    required this.hillFront,
    required this.sunColor,
    required this.moonColor,
    required this.moonShadow,
    required this.cloudOpacity,
    required this.starOpacity,
    required this.isNight,
  });

  final Color skyTop;
  final Color skyHorizon;
  final Color hillBack;
  final Color hillFront;
  final Color sunColor;
  final Color moonColor;
  final Color moonShadow;
  final double cloudOpacity;
  final double starOpacity;
  final bool isNight;

  static const _night = _SkyPalette(
    skyTop: Color(0xFF101633),
    skyHorizon: Color(0xFF263455),
    hillBack: Color(0xFF34415B),
    hillFront: Color(0xFF3F4D66),
    sunColor: StoriaColors.mustard,
    moonColor: Color(0xFFFFF2C8),
    moonShadow: Color(0xFF17203E),
    cloudOpacity: 0.24,
    starOpacity: 1,
    isNight: true,
  );

  static const _sunrise = _SkyPalette(
    skyTop: Color(0xFF91C9E8),
    skyHorizon: Color(0xFFFFC58F),
    hillBack: Color(0xFF8FBE86),
    hillFront: Color(0xFFB4D79A),
    sunColor: Color(0xFFFFC857),
    moonColor: Color(0xFFFFF2C8),
    moonShadow: Color(0xFF91C9E8),
    cloudOpacity: 0.7,
    starOpacity: 0,
    isNight: false,
  );

  static const _day = _SkyPalette(
    skyTop: Color(0xFFB3E5FC),
    skyHorizon: Color(0xFFFFE0B2),
    hillBack: Color(0xFFA5D6A7),
    hillFront: Color(0xFFC8E6C9),
    sunColor: StoriaColors.mustard,
    moonColor: Color(0xFFFFF2C8),
    moonShadow: Color(0xFFB3E5FC),
    cloudOpacity: 0.82,
    starOpacity: 0,
    isNight: false,
  );

  static const _golden = _SkyPalette(
    skyTop: Color(0xFF77B7E5),
    skyHorizon: Color(0xFFFFAE69),
    hillBack: Color(0xFF91B875),
    hillFront: Color(0xFFC8C681),
    sunColor: Color(0xFFFFB347),
    moonColor: Color(0xFFFFF2C8),
    moonShadow: Color(0xFF77B7E5),
    cloudOpacity: 0.78,
    starOpacity: 0,
    isNight: false,
  );

  static _SkyPalette fromDateTime(DateTime time) {
    final minute = time.hour * 60 + time.minute + time.second / 60;
    const stops = <_SkyStop>[
      _SkyStop(0, _night),
      _SkyStop(300, _night),
      _SkyStop(420, _sunrise),
      _SkyStop(540, _day),
      _SkyStop(990, _day),
      _SkyStop(1110, _golden),
      _SkyStop(1200, _night),
      _SkyStop(1440, _night),
    ];

    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (minute >= a.minute && minute <= b.minute) {
        final span = b.minute - a.minute;
        final t = span == 0 ? 0.0 : (minute - a.minute) / span;
        return _lerp(
          a.palette,
          b.palette,
          _smoothstep(t),
        )._copyWith(isNight: minute >= 1200 || minute < 300);
      }
    }
    return _night;
  }

  static double _smoothstep(double t) => t * t * (3 - 2 * t);

  static _SkyPalette _lerp(_SkyPalette a, _SkyPalette b, double t) {
    return _SkyPalette(
      skyTop: Color.lerp(a.skyTop, b.skyTop, t)!,
      skyHorizon: Color.lerp(a.skyHorizon, b.skyHorizon, t)!,
      hillBack: Color.lerp(a.hillBack, b.hillBack, t)!,
      hillFront: Color.lerp(a.hillFront, b.hillFront, t)!,
      sunColor: Color.lerp(a.sunColor, b.sunColor, t)!,
      moonColor: Color.lerp(a.moonColor, b.moonColor, t)!,
      moonShadow: Color.lerp(a.moonShadow, b.moonShadow, t)!,
      cloudOpacity: _doubleLerp(a.cloudOpacity, b.cloudOpacity, t),
      starOpacity: _doubleLerp(a.starOpacity, b.starOpacity, t),
      isNight: t < 0.5 ? a.isNight : b.isNight,
    );
  }

  _SkyPalette _copyWith({bool? isNight}) {
    return _SkyPalette(
      skyTop: skyTop,
      skyHorizon: skyHorizon,
      hillBack: hillBack,
      hillFront: hillFront,
      sunColor: sunColor,
      moonColor: moonColor,
      moonShadow: moonShadow,
      cloudOpacity: cloudOpacity,
      starOpacity: starOpacity,
      isNight: isNight ?? this.isNight,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _SkyPalette &&
        other.skyTop == skyTop &&
        other.skyHorizon == skyHorizon &&
        other.hillBack == hillBack &&
        other.hillFront == hillFront &&
        other.sunColor == sunColor &&
        other.moonColor == moonColor &&
        other.moonShadow == moonShadow &&
        other.cloudOpacity == cloudOpacity &&
        other.starOpacity == starOpacity &&
        other.isNight == isNight;
  }

  @override
  int get hashCode => Object.hash(
    skyTop,
    skyHorizon,
    hillBack,
    hillFront,
    sunColor,
    moonColor,
    moonShadow,
    cloudOpacity,
    starOpacity,
    isNight,
  );
}

class _SkyStop {
  const _SkyStop(this.minute, this.palette);

  final double minute;
  final _SkyPalette palette;
}

double _doubleLerp(double a, double b, double t) => a + (b - a) * t;

// ── Room background ─────────────────────────────────────────────────────

class _RoomBackground extends StatelessWidget {
  const _RoomBackground({
    required this.worldWidth,
    required this.cameraNotifier,
    required this.palette,
  });

  final double worldWidth;
  final ValueListenable<double> cameraNotifier;
  final _SkyPalette palette;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: cameraNotifier,
      builder: (context, cameraX, _) {
        return RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _SkyHillsPainter(
              worldWidth: worldWidth,
              cameraX: cameraX,
              palette: palette,
            ),
          ),
        );
      },
    );
  }
}

/// [CustomPainter] that draws sky (0.2x parallax) and hills (0.5x parallax).
/// Ground rendering is handled by the isometric TMX map inside the Flame world.
class _SkyHillsPainter extends CustomPainter {
  _SkyHillsPainter({
    required this.worldWidth,
    required this.cameraX,
    required this.palette,
  });

  final double worldWidth;
  final double cameraX;
  final _SkyPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    _paintHills(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final horizonY = size.height * 0.6;
    final skyOffset = -cameraX * 0.2;

    canvas.save();
    canvas.translate(skyOffset, 0);

    final skyRect = Rect.fromLTWH(0, 0, size.width - skyOffset, horizonY);
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.skyTop, palette.skyHorizon],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizonY));
    canvas.drawRect(skyRect, skyPaint);

    canvas.restore();
  }

  void _paintHills(Canvas canvas, Size size) {
    final hillsOffset = -cameraX * 0.5;
    final spanWidth = worldWidth * 1.5;
    final groundTop = size.height * 0.70;

    canvas.save();
    canvas.translate(hillsOffset, 0);

    final backPath = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(
        spanWidth * 0.15,
        groundTop - 120,
        spanWidth * 0.30,
        groundTop - 40,
      )
      ..quadraticBezierTo(
        spanWidth * 0.45,
        groundTop - 100,
        spanWidth * 0.60,
        groundTop - 30,
      )
      ..quadraticBezierTo(
        spanWidth * 0.80,
        groundTop - 90,
        spanWidth,
        groundTop,
      )
      ..lineTo(spanWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      backPath,
      Paint()..color = palette.hillBack.withValues(alpha: 0.6),
    );

    final frontPath = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(
        spanWidth * 0.10,
        groundTop - 50,
        spanWidth * 0.25,
        groundTop - 15,
      )
      ..quadraticBezierTo(
        spanWidth * 0.40,
        groundTop - 60,
        spanWidth * 0.55,
        groundTop - 10,
      )
      ..quadraticBezierTo(
        spanWidth * 0.70,
        groundTop - 45,
        spanWidth * 0.90,
        groundTop,
      )
      ..lineTo(spanWidth, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      frontPath,
      Paint()..color = palette.hillFront.withValues(alpha: 0.8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyHillsPainter oldDelegate) =>
      worldWidth != oldDelegate.worldWidth ||
      cameraX != oldDelegate.cameraX ||
      palette != oldDelegate.palette;
}

// ── Floating controls ───────────────────────────────────────────────────

class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.searchController,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.isNightSky,
    required this.onSkyToggle,
    required this.onCustomizeTap,
    required this.onSettingsTap,
  });

  final TextEditingController searchController;
  final _ShelfFilter activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ShelfFilter> onFilterChanged;
  final bool isNightSky;
  final VoidCallback onSkyToggle;
  final VoidCallback onCustomizeTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StoriaColors.paper.withValues(alpha: 0.95),
            StoriaColors.paper.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: StoriaSpacing.sm),
              SketchIconButton(
                key: const ValueKey('library-sky-toggle'),
                icon: isNightSky
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round,
                onPressed: onSkyToggle,
                tooltip: isNightSky
                    ? 'Switch sky to day'
                    : 'Switch sky to night',
              ),
              const SizedBox(width: StoriaSpacing.sm),
              SketchIconButton(
                key: const ValueKey('library-customize-character'),
                icon: Icons.face_retouching_natural_outlined,
                onPressed: onCustomizeTap,
                tooltip: 'Customize character',
              ),
              const SizedBox(width: StoriaSpacing.sm),
              SketchIconButton(
                icon: Icons.settings_outlined,
                onPressed: onSettingsTap,
                tooltip: 'Open settings',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ShelfFilters(
            activeFilter: activeFilter,
            onSelected: onFilterChanged,
          ),
        ],
      ),
    );
  }
}

// ── Search field ────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const SketchBorderShape(
          side: BorderSide(color: StoriaColors.line, width: 1.2),
          radiusScale: 0.82,
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search by title or author',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.36),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: StoriaColors.inkMuted,
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                      color: StoriaColors.inkMuted,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              isDense: true,
            ),
          );
        },
      ),
    );
  }
}

// ── Shelf filters ───────────────────────────────────────────────────────

class _ShelfFilters extends StatefulWidget {
  const _ShelfFilters({required this.activeFilter, required this.onSelected});

  final _ShelfFilter activeFilter;
  final ValueChanged<_ShelfFilter> onSelected;

  @override
  State<_ShelfFilters> createState() => _ShelfFiltersState();
}

class _ShelfFiltersState extends State<_ShelfFilters> {
  static const _gap = 8.0;
  static const _options = [
    _FilterOption(_ShelfFilter.all, 'All Tales'),
    _FilterOption(_ShelfFilter.quick, 'Quick Reads'),
    _FilterOption(_ShelfFilter.longer, 'Longer Reads'),
  ];

  final _rowKey = GlobalKey();
  final _chipKeys = {for (final option in _options) option.filter: GlobalKey()};

  Map<_ShelfFilter, Rect> _chipRects = const {};
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _ShelfFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      _measureChipRects();
    });
  }

  void _measureChipRects() {
    final rowRenderObject = _rowKey.currentContext?.findRenderObject();
    if (rowRenderObject is! RenderBox || !rowRenderObject.hasSize) return;

    final nextRects = <_ShelfFilter, Rect>{};
    for (final option in _options) {
      final chipRenderObject = _chipKeys[option.filter]?.currentContext
          ?.findRenderObject();
      if (chipRenderObject is! RenderBox || !chipRenderObject.hasSize) {
        continue;
      }
      final topLeft = rowRenderObject.globalToLocal(
        chipRenderObject.localToGlobal(Offset.zero),
      );
      nextRects[option.filter] = topLeft & chipRenderObject.size;
    }

    if (nextRects.length != _options.length ||
        _rectMapsAreClose(nextRects, _chipRects)) {
      return;
    }

    setState(() => _chipRects = nextRects);
  }

  bool _rectMapsAreClose(Map<_ShelfFilter, Rect> a, Map<_ShelfFilter, Rect> b) {
    if (a.length != b.length) return false;
    for (final option in _options) {
      final first = a[option.filter];
      final second = b[option.filter];
      if (first == null || second == null) return first == second;
      if ((first.left - second.left).abs() > 0.5 ||
          (first.top - second.top).abs() > 0.5 ||
          (first.width - second.width).abs() > 0.5 ||
          (first.height - second.height).abs() > 0.5) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    final activeRect = _chipRects[widget.activeFilter];
    final indicatorReady = activeRect != null;

    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Stack(
          key: _rowKey,
          clipBehavior: Clip.none,
          children: [
            if (activeRect != null)
              _FilterGooeyIndicator(activeRect: activeRect),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _options.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  _FilterChip(
                    key: _chipKeys[_options[i].filter],
                    label: _options[i].label,
                    isActive: widget.activeFilter == _options[i].filter,
                    useActiveTextColor:
                        indicatorReady &&
                        widget.activeFilter == _options[i].filter,
                    onTap: () => widget.onSelected(_options[i].filter),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterGooeyIndicator extends StatelessWidget {
  const _FilterGooeyIndicator({required this.activeRect});

  final Rect activeRect;

  @override
  Widget build(BuildContext context) {
    final pillRect = Rect.fromLTWH(
      activeRect.left,
      activeRect.top + 2,
      activeRect.width,
      activeRect.height - 4,
    );
    final trailSize = math.min(36.0, pillRect.height);
    final trailLeft = pillRect.center.dx - trailSize / 2;
    final trailTop = pillRect.center.dy - trailSize / 2;

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: GooeyZone(
            key: const ValueKey('library-filter-gooey-indicator'),
            color: StoriaColors.ink,
            gooiness: 34,
            borderWidth: 1,
            borderColor: StoriaColors.paper.withValues(alpha: 0.16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedPositioned(
                  duration: StoriaMotion.slow,
                  curve: StoriaMotion.emphasized,
                  left: trailLeft,
                  top: trailTop,
                  width: trailSize,
                  height: trailSize,
                  child: const GooeyBlob(
                    key: ValueKey('library-filter-gooey-trail'),
                    shape: BlobShape.circle(),
                    child: SizedBox.expand(),
                  ),
                ),
                AnimatedPositioned(
                  duration: StoriaMotion.medium,
                  curve: StoriaMotion.emphasized,
                  left: pillRect.left,
                  top: pillRect.top,
                  width: pillRect.width,
                  height: pillRect.height,
                  child: const GooeyBlob(
                    key: ValueKey('library-filter-gooey-main'),
                    shape: BlobShape.rounded(16),
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption(this.filter, this.label);

  final _ShelfFilter filter;
  final String label;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.useActiveTextColor,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool useActiveTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final baseTextStyle =
        Theme.of(context).textTheme.bodySmall ??
        const TextStyle(fontWeight: FontWeight.w700);
    final textStyle = baseTextStyle.copyWith(
      color: useActiveTextColor ? StoriaColors.paper : StoriaColors.ink,
      fontWeight: FontWeight.w700,
    );

    return SizedBox(
      height: 38,
      child: Semantics(
        selected: isActive,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: AnimatedDefaultTextStyle(
                duration: StoriaMotion.quick,
                curve: StoriaMotion.emphasized,
                style: textStyle,
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading state ───────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: StoriaColors.ink),
          SizedBox(height: 16),
          Text('Loading your library...'),
        ],
      ),
    );
  }
}

// ── Error state ─────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SketchCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: StoriaColors.ink.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load the library',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: StoriaColors.ink.withValues(alpha: 0.66),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter logic ────────────────────────────────────────────────────────

class _BrowsePanel extends StatelessWidget {
  const _BrowsePanel({
    required this.show,
    required this.books,
    required this.searchQuery,
    required this.activeFilter,
    required this.onBookTap,
  });

  final bool show;
  final List<Book> books;
  final String searchQuery;
  final _ShelfFilter activeFilter;
  final ValueChanged<Book> onBookTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return IgnorePointer(
      ignoring: !show,
      child: Cue.onToggle(
        debugLabel: 'library-browse-panel',
        toggled: show,
        motion: const CueMotion.curved(
          StoriaMotion.medium,
          curve: StoriaMotion.emphasized,
        ),
        acts: const [
          .slideY(from: 1, to: 0),
          .fadeIn(motion: CueMotion.easeOut(StoriaMotion.quick)),
        ],
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 140, 12, 12 + bottomPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SketchCard(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.explore_rounded,
                          size: 18,
                          color: StoriaColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _browseTitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a result to guide your avatar there on the map.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StoriaColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: books.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return _BrowseResultTile(
                            book: book,
                            onTap: () => onBookTap(book),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _browseTitle {
    if (searchQuery.trim().isNotEmpty) {
      return 'More matches for “${searchQuery.trim()}”';
    }
    return switch (activeFilter) {
      _ShelfFilter.quick => 'More quick reads',
      _ShelfFilter.longer => 'More longer reads',
      _ShelfFilter.all => 'More books to browse',
    };
  }
}

class _BrowseResultTile extends StatelessWidget {
  const _BrowseResultTile({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 60,
                  child: book.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: book.coverUrl!,
                          cacheManager: ResilientCacheManager.instance,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _BrowseCoverPlaceholder(),
                          placeholder: (_, __) =>
                              Container(color: StoriaColors.paperAlt),
                        )
                      : const _BrowseCoverPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((book.author ?? '').isNotEmpty)
                      Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: StoriaColors.inkMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.pageCount} pages',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: StoriaColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.route_rounded, color: StoriaColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseCoverPlaceholder extends StatelessWidget {
  const _BrowseCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StoriaColors.paperAlt,
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: StoriaColors.inkMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ── Sky decorations: sun/moon + drifting clouds ─────────────────────────

class _SkyDecorations extends StatefulWidget {
  const _SkyDecorations({required this.palette});

  final _SkyPalette palette;

  @override
  State<_SkyDecorations> createState() => _SkyDecorationsState();
}

class _SkyDecorationsState extends State<_SkyDecorations>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;

  static const _clouds = <_CloudSpec>[
    _CloudSpec(top: 200, scale: 0.9, phase: 0.00, opacity: 0.85),
    _CloudSpec(top: 280, scale: 1.3, phase: 0.30, opacity: 0.80),
    _CloudSpec(top: 240, scale: 0.7, phase: 0.55, opacity: 0.75, flip: true),
    _CloudSpec(top: 340, scale: 1.0, phase: 0.80, opacity: 0.80),
  ];

  @override
  void initState() {
    super.initState();
    _t = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = _t.value;
          return Stack(
            children: [
              if (widget.palette.starOpacity > 0.01)
                _StarField(t: t, opacity: widget.palette.starOpacity),
              widget.palette.isNight ? _moon(t) : _sun(t),
              for (final spec in _clouds) _cloud(spec, t),
            ],
          );
        },
      ),
    );
  }

  Widget _cloud(_CloudSpec spec, double t) {
    final screenW = MediaQuery.sizeOf(context).width;
    const baseW = 140.0;
    final w = baseW * spec.scale;
    final loop = screenW + w + 80;
    final progress = (t + spec.phase) % 1;
    final left = screenW + 40 - progress * loop;
    final dy = math.sin((t + spec.phase) * math.pi * 2) * 4;

    Widget cloud = SvgPicture.asset('assets/svgs/cloud.svg', width: w);
    if (spec.flip) {
      cloud = Transform.flip(flipX: true, child: cloud);
    }

    return Positioned(
      top: spec.top + dy,
      left: left,
      child: Opacity(
        opacity: spec.opacity * widget.palette.cloudOpacity,
        child: cloud,
      ),
    );
  }

  Widget _sun(double t) {
    final glowOpacity = 0.18 + 0.10 * math.sin(t * math.pi * 2);
    const sunSize = 64.0;
    const boxSize = sunSize + 32;
    return Positioned(
      top: 170,
      right: 28,
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.palette.sunColor.withValues(alpha: glowOpacity),
                  widget.palette.sunColor.withValues(alpha: 0),
                ],
                stops: const [0.2, 1.0],
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/svgs/sun.svg',
            width: sunSize,
            height: sunSize,
          ),
        ],
      ),
    );
  }

  Widget _moon(double t) {
    final glowOpacity = 0.18 + 0.08 * math.sin(t * math.pi * 2);
    final bob = math.sin((t + 0.15) * math.pi * 2) * 3;
    const moonSize = 58.0;
    const boxSize = moonSize + 38;
    return Positioned(
      top: 164 + bob,
      right: 26,
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.palette.moonColor.withValues(alpha: glowOpacity),
                  widget.palette.moonColor.withValues(alpha: 0),
                ],
                stops: const [0.12, 1.0],
              ),
            ),
          ),
          CustomPaint(
            size: const Size.square(moonSize),
            painter: _MoonPainter(
              color: widget.palette.moonColor,
              shadowColor: widget.palette.moonShadow,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  const _StarField({required this.t, required this.opacity});

  final double t;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _StarsPainter(t: t, opacity: opacity),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter({required this.t, required this.opacity});

  final double t;
  final double opacity;

  static const _stars = <Offset>[
    Offset(0.08, 0.20),
    Offset(0.16, 0.34),
    Offset(0.24, 0.16),
    Offset(0.34, 0.30),
    Offset(0.45, 0.18),
    Offset(0.56, 0.36),
    Offset(0.66, 0.22),
    Offset(0.78, 0.32),
    Offset(0.88, 0.18),
    Offset(0.93, 0.42),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final skyHeight = size.height * 0.56;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final twinkle = 0.58 + 0.42 * math.sin(t * math.pi * 2 + i * 1.7);
      paint.color = Colors.white.withValues(alpha: opacity * twinkle * 0.82);
      final radius = i.isEven ? 1.8 : 1.25;
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * skyHeight + 24),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      t != oldDelegate.t || opacity != oldDelegate.opacity;
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.color, required this.shadowColor});

  final Color color;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(radius * 0.34, -radius * 0.10),
      radius * 0.92,
      Paint()..color = shadowColor,
    );
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) =>
      color != oldDelegate.color || shadowColor != oldDelegate.shadowColor;
}

class _CloudSpec {
  const _CloudSpec({
    required this.top,
    required this.scale,
    required this.phase,
    required this.opacity,
    this.flip = false,
  });

  final double top;
  final double scale;
  final double phase;
  final double opacity;
  final bool flip;
}

extension on _ShelfFilter {
  LibraryMapLengthFilter toLibraryMapLengthFilter() {
    return switch (this) {
      _ShelfFilter.all => LibraryMapLengthFilter.all,
      _ShelfFilter.quick => LibraryMapLengthFilter.quickReads,
      _ShelfFilter.longer => LibraryMapLengthFilter.longerReads,
    };
  }
}
