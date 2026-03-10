import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/resilient_cache_manager.dart';
import '../../core/theme/storia_colors.dart';
import '../../core/theme/storia_motion.dart';
import '../../core/widgets/leaf_accent.dart';
import '../../core/widgets/parental_gate.dart';
import '../../core/widgets/sketch_border.dart';
import '../../core/widgets/sketch_card.dart';
import '../../core/widgets/sketch_icon_button.dart';
import '../../core/widgets/watercolor_scaffold.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

enum _ShelfFilter { all, quick, longer }

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

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchQuery = '');
      return;
    }

    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookLibraryProvider);

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: WatercolorScaffold(
        child: booksAsync.when(
          data: (books) => _LibraryView(
            books: books,
            activeFilter: _activeFilter,
            searchController: _searchController,
            searchQuery: _searchQuery,
            onFilterChanged: (filter) => setState(() => _activeFilter = filter),
            onSearchChanged: _handleSearchChanged,
          ),
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            error: '$error',
            onRetry: () => ref.invalidate(bookLibraryProvider),
          ),
        ),
      ),
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView({
    required this.books,
    required this.activeFilter,
    required this.searchController,
    required this.searchQuery,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final List<Book> books;
  final _ShelfFilter activeFilter;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<_ShelfFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _filterBooks(books, searchQuery, activeFilter);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _LibraryHero(
            totalBooks: books.length,
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            onSettingsTap: () async {
              final passed = await ParentalGate.verify(context);
              if (!context.mounted || !passed) return;
              context.push('/settings');
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _ShelfFilters(
            activeFilter: activeFilter,
            onSelected: onFilterChanged,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    searchQuery.trim().isEmpty
                        ? _sectionLabel(activeFilter)
                        : 'Search Results',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                _CountBadge(count: filteredBooks.length),
              ],
            ),
          ),
        ),
        if (filteredBooks.isEmpty)
          const SliverToBoxAdapter(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = _gridColumnsForWidth(
                  constraints.crossAxisExtent,
                );
                return SliverGrid.builder(
                  itemCount: filteredBooks.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.62,
                  ),
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    return _BookCard(
                      key: ValueKey(book.id),
                      book: book,
                      index: index,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LibraryHero extends StatelessWidget {
  const _LibraryHero({
    required this.totalBooks,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSettingsTap,
  });

  final int totalBooks;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final titleStyle = Theme.of(context).textTheme.displayMedium;
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 12),
      child: SketchCard(
        color: StoriaColors.paperRaised.withValues(alpha: 0.92),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Stack(
          children: [
            Positioned(
              top: -4,
              right: 8,
              child: Opacity(
                opacity: 0.82,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: StoriaColors.dustyPink.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const LeafAccent(size: 44),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Story Library', style: titleStyle)),
                    SketchIconButton(
                      icon: Icons.settings_outlined,
                      onPressed: onSettingsTap,
                      tooltip: 'Open settings',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$totalBooks books ready for a gentle story time.',
                  style: bodyStyle?.copyWith(
                    color: StoriaColors.ink.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 18),
                _SearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: StoriaMotion.medium).slideY(begin: -0.04),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white,
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
                vertical: 14,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShelfFilters extends StatelessWidget {
  const _ShelfFilters({required this.activeFilter, required this.onSelected});

  final _ShelfFilter activeFilter;
  final ValueChanged<_ShelfFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _FilterChip(
            label: 'All Tales',
            isActive: activeFilter == _ShelfFilter.all,
            onTap: () => onSelected(_ShelfFilter.all),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Quick Reads',
            isActive: activeFilter == _ShelfFilter.quick,
            onTap: () => onSelected(_ShelfFilter.quick),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Longer Reads',
            isActive: activeFilter == _ShelfFilter.longer,
            onTap: () => onSelected(_ShelfFilter.longer),
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
        customBorder: const SketchBorderShape(
          side: BorderSide(color: StoriaColors.line, width: 1.1),
          radiusScale: 0.78,
        ),
        child: AnimatedContainer(
          duration: StoriaMotion.quick,
          curve: StoriaMotion.emphasized,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: ShapeDecoration(
            color: isActive ? StoriaColors.ink : StoriaColors.paperAlt,
            shape: SketchBorderShape(
              side: BorderSide(
                color: isActive ? StoriaColors.ink : StoriaColors.line,
                width: 1.1,
              ),
              radiusScale: 0.78,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isActive ? StoriaColors.paper : StoriaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.index, super.key});

  final Book book;
  final int index;

  @override
  Widget build(BuildContext context) {
    final coverRadius = sketchBorderRadius(
      0.72,
    ).resolve(Directionality.of(context));
    final accent = switch (index % 3) {
      0 => StoriaColors.dustyPink,
      1 => StoriaColors.mustard,
      _ => StoriaColors.sage,
    };
    final shadowColor = Colors.black.withValues(alpha: 0.08);

    final card = GestureDetector(
      onTap: () => context.push('/reader/${book.id}'),
      child: SketchCard(
        color: Colors.white.withValues(alpha: 0.92),
        elevation: 0.1,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: coverRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: StoriaColors.paperAlt,
                        borderRadius: coverRadius,
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -16,
                      left: -18,
                      child: _CoverBlob(
                        color: accent.withValues(alpha: 0.32),
                        width: 110,
                        height: 120,
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -18,
                      child: _CoverBlob(
                        color: StoriaColors.ink.withValues(alpha: 0.08),
                        width: 90,
                        height: 90,
                      ),
                    ),
                    if ((book.coverUrl ?? '').isNotEmpty)
                      Hero(
                        tag: 'book-cover-${book.id}',
                        child: CachedNetworkImage(
                          imageUrl: book.coverUrl!,
                          cacheManager: ResilientCacheManager.instance,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _CoverPlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: StoriaColors.paperAlt),
                        ),
                      )
                    else
                      const _LibraryCoverFallback(),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          shape: const CircleBorder(),
                          shadows: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 18,
                            color: accent.darken(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _readingBand(book.pageCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: accent.darken(),
                letterSpacing: 0.4,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 16, height: 1.18),
            ),
            const SizedBox(height: 4),
            Text(
              book.author ?? 'Unknown author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  '${book.pageCount} pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: accent.darken(),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return card
        .animate(delay: Duration(milliseconds: 40 * (index % 6)))
        .fadeIn(duration: StoriaMotion.medium)
        .slideY(begin: 0.05, curve: StoriaMotion.emphasized);
  }
}

class _CoverBlob extends StatelessWidget {
  const _CoverBlob({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(width * 0.44),
        ),
      ),
    );
  }
}

class _LibraryCoverFallback extends StatelessWidget {
  const _LibraryCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.auto_stories_rounded,
        size: 46,
        color: StoriaColors.ink.withValues(alpha: 0.22),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF1E4D9), Color(0xFFECD4D4), Color(0xFFDDE7D8)],
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1400.ms);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: StoriaColors.ink,
        shape: StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: StoriaColors.paper,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SketchCard(
        child: Column(
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 36,
              color: StoriaColors.ink.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 12),
            Text(
              'No books matched your shelf',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different title, author, or reading filter.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StoriaColors.ink.withValues(alpha: 0.66),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 12,
              20,
              18,
            ),
            child:
                Container(
                      height: 214,
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        shape: const SketchBorderShape(
                          side: BorderSide(
                            color: StoriaColors.line,
                            width: 1.2,
                          ),
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1450.ms),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverGrid.builder(
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (_, __) =>
                Container(
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        shape: const SketchBorderShape(
                          side: BorderSide(
                            color: StoriaColors.line,
                            width: 1.1,
                          ),
                        ),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1300.ms),
          ),
        ),
      ],
    );
  }
}

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

List<Book> _filterBooks(
  List<Book> books,
  String searchQuery,
  _ShelfFilter filter,
) {
  final normalizedQuery = searchQuery.trim().toLowerCase();

  return books
      .where((book) {
        final matchesSearch = normalizedQuery.isEmpty
            ? true
            : book.title.toLowerCase().contains(normalizedQuery) ||
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

String _sectionLabel(_ShelfFilter filter) {
  return switch (filter) {
    _ShelfFilter.all => 'All Tales',
    _ShelfFilter.quick => 'Quick Reads',
    _ShelfFilter.longer => 'Longer Reads',
  };
}

String _readingBand(int pageCount) {
  if (pageCount <= 8) {
    return 'SOFT STARTER';
  }
  if (pageCount <= 12) {
    return 'BEDTIME FAVORITE';
  }
  return 'LONGER ADVENTURE';
}

int _gridColumnsForWidth(double width) {
  if (width < 460) return 2;
  if (width < 780) return 3;
  return 4;
}

extension on Color {
  Color darken() {
    return Color.lerp(this, Colors.black, 0.28) ?? this;
  }
}
