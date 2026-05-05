import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cue/cue.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/resilient_cache_manager.dart';
import '../../core/theme/storia_colors.dart';
import '../../core/widgets/parental_gate.dart';
import '../../core/widgets/sketch_border.dart';
import '../../core/widgets/sketch_card.dart';
import '../../core/widgets/sketch_icon_button.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'game/book_preview_overlay.dart';
import 'game/library_game.dart';

// ── Shelf filter ────────────────────────────────────────────────────────
enum _ShelfFilter { all, quick, longer }

// ── Layout constants ────────────────────────────────────────────────────
const double _kNodeWidth = 80;
const double _kMinWorldWidth = 600;

/// Adventure-map world width: enough room for nodes to spread with generous
/// spacing (~160px per node), ensuring 4-5 nodes visible per viewport.
double _worldWidthForBooks(int count, double screenWidth) {
  final needed = (count + 1) * 160.0;
  return needed.clamp(
    screenWidth.clamp(_kMinWorldWidth, double.infinity),
    double.infinity,
  );
}

// ── Main screen ─────────────────────────────────────────────────────────

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 220);
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  _ShelfFilter _activeFilter = _ShelfFilter.all;
  Set<String> _visibleBookIds = const <String>{};

  LibraryGame? _game;
  Book? _previewBook;

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
    final books = ref.read(bookLibraryProvider).valueOrNull ?? [];
    final filtered = _filterBooks(books, _searchQuery, _activeFilter);
    final visibleIds = filtered.map((b) => b.id).toSet();
    _visibleBookIds = visibleIds;
    _game?.applyFilter(visibleIds);
  }

  bool get _hasActiveBrowseQuery =>
      _searchQuery.trim().isNotEmpty || _activeFilter != _ShelfFilter.all;

  bool get _showBrowsePanel =>
      _hasActiveBrowseQuery && _broaderBrowseResults.isNotEmpty;

  List<Book> get _broaderBrowseResults =>
      _game?.broaderBrowseResults(
        searchQuery: _searchQuery,
        filter: _activeFilter,
        visibleIds: _visibleBookIds,
      ) ??
      const [];

  void _onArrivedAtBook() {
    final book = _game?.arrivedAtBook.value;
    if (book != null && mounted) {
      setState(() => _previewBook = book);
    }
  }

  void _dismissPreview() {
    setState(() => _previewBook = null);
    _game?.arrivedAtBook.value = null;
  }

  void _onBrowsePanelBookTap(Book book) {
    _dismissPreview();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _activeFilter = _ShelfFilter.all;
    });
    _applyFilter();
    _game?.navigateToBookNode(book);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _game?.arrivedAtBook.removeListener(_onArrivedAtBook);
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
    final screenW = MediaQuery.sizeOf(context).width;
    final worldWidth = _worldWidthForBooks(books.length, screenW);

    // Create game once, reload books when list changes.
    if (_game == null || _game!.worldWidth != worldWidth) {
      _game?.arrivedAtBook.removeListener(_onArrivedAtBook);
      _game = LibraryGame(worldWidth: worldWidth);
      _game!.arrivedAtBook.addListener(_onArrivedAtBook);

      // Schedule book placement after game is loaded.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final screenH = MediaQuery.sizeOf(context).height;
        _game!.loadBooks(books, screenHeight: screenH);
        _applyFilter();
      });
    }

    return Stack(
      children: [
        // Layer 1: Flutter-drawn room background (synced to camera).
        _RoomBackground(
          worldWidth: worldWidth,
          cameraNotifier: _game!.cameraXNotifier,
        ),

        // Layer 1.5: Sun + drifting clouds in dead sky space.
        const Positioned.fill(child: _SkyDecorations()),

        // Layer 2: Flame game (transparent, character + book tap targets).
        Positioned.fill(child: GameWidget(game: _game!)),

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
        if (_previewBook != null) ...[
          // Dismiss scrim.
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissPreview,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x22000000)),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _game!.cameraXNotifier,
            builder: (context, _, __) {
              final previewBook = _previewBook!;
              return Cue.onToggle(
                toggled: _previewBook != null,
                motion: .smooth(),
                reverseMotion: .snappy(),
                child: Actor(
                  acts: const [
                    ScaleAct(from: 0.9),
                    OpacityAct.fadeIn(),
                    SlideAct.y(from: 0.05),
                  ],
                  child: BookPreviewOverlay(
                    book: previewBook,
                    position: _overlayPosition(previewBook),
                    onRead: () {
                      final bookId = previewBook.id;
                      _dismissPreview();
                      context.push('/reader/$bookId');
                    },
                    onDismiss: _dismissPreview,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Offset _overlayPosition(Book book) {
    final screenPos = _game?.screenPositionOfBook(book.id);
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

// ── Room background ─────────────────────────────────────────────────────

class _RoomBackground extends StatelessWidget {
  const _RoomBackground({
    required this.worldWidth,
    required this.cameraNotifier,
  });

  final double worldWidth;
  final ValueNotifier<double> cameraNotifier;

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
  });

  final double worldWidth;
  final double cameraX;

  static const _skyTop = Color(0xFFB3E5FC);
  static const _skyHorizon = Color(0xFFFFE0B2);
  static const _hillBack = Color(0xFFA5D6A7);
  static const _hillFront = Color(0xFFC8E6C9);

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
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_skyTop, _skyHorizon],
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
      Paint()..color = _hillBack.withValues(alpha: 0.6),
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
      Paint()..color = _hillFront.withValues(alpha: 0.8),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyHillsPainter oldDelegate) =>
      worldWidth != oldDelegate.worldWidth ||
      cameraX != oldDelegate.cameraX;
}

// ── Floating controls ───────────────────────────────────────────────────

class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.searchController,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSettingsTap,
  });

  final TextEditingController searchController;
  final _ShelfFilter activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ShelfFilter> onFilterChanged;
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
              const SizedBox(width: 8),
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

class _ShelfFilters extends StatelessWidget {
  const _ShelfFilters({required this.activeFilter, required this.onSelected});

  final _ShelfFilter activeFilter;
  final ValueChanged<_ShelfFilter> onSelected;

  Alignment _pillAlignment(_ShelfFilter filter) {
    return switch (filter) {
      _ShelfFilter.all => Alignment.centerLeft,
      _ShelfFilter.quick => Alignment.center,
      _ShelfFilter.longer => Alignment.centerRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          // Track background.
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StoriaColors.line, width: 1.1),
            ),
          ),
          // Sliding dark pill with cue pop.
          Cue.onChange(
            value: activeFilter,
            motion: .spatial(),
            child: Actor(
              acts: const [ScaleAct(from: 0.92)],
              child: AnimatedAlign(
                alignment: _pillAlignment(activeFilter),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: StoriaColors.ink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Chip labels (tappable, transparent background).
          Row(
            children: [
              Expanded(
                child: _FilterChip(
                  label: 'All Tales',
                  isActive: activeFilter == _ShelfFilter.all,
                  onTap: () => onSelected(_ShelfFilter.all),
                ),
              ),
              Expanded(
                child: _FilterChip(
                  label: 'Quick Reads',
                  isActive: activeFilter == _ShelfFilter.quick,
                  onTap: () => onSelected(_ShelfFilter.quick),
                ),
              ),
              Expanded(
                child: _FilterChip(
                  label: 'Longer Reads',
                  isActive: activeFilter == _ShelfFilter.longer,
                  onTap: () => onSelected(_ShelfFilter.longer),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? StoriaColors.paper : StoriaColors.ink,
                fontWeight: FontWeight.w700,
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
      child: AnimatedSlide(
        offset: show ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 180),
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
                          separatorBuilder: (_, __) =>
                              const Divider(height: 12),
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

// ── Sky decorations: sun + drifting clouds ──────────────────────────────

class _SkyDecorations extends StatefulWidget {
  const _SkyDecorations();

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
              _sun(t),
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
      child: Opacity(opacity: spec.opacity, child: cloud),
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
                  const Color(0xFFFFD644).withValues(alpha: glowOpacity),
                  const Color(0xFFFFD644).withValues(alpha: 0),
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

List<Book> _filterBooks(
  List<Book> books,
  String searchQuery,
  _ShelfFilter filter,
) {
  final normalizedQuery = searchQuery.trim().toLowerCase();
  return books
      .where((book) {
        final matchesSearch =
            normalizedQuery.isEmpty ||
            book.title.toLowerCase().contains(normalizedQuery) ||
            (book.author ?? '').toLowerCase().contains(normalizedQuery);
        final matchesFilter = switch (filter) {
          _ShelfFilter.all => true,
          _ShelfFilter.quick => book.pageCount <= 12,
          _ShelfFilter.longer => book.pageCount > 12,
        };
        return matchesSearch && matchesFilter;
      })
      .toList(growable: false);
}
