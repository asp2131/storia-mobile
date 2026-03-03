import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/resilient_cache_manager.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final booksAsync = ref.watch(bookLibraryProvider);

    return Scaffold(
      backgroundColor: theme.brightness == .dark
          ? theme.colorScheme.surface
          : const Color(0xFFF5F4EF),
      body: booksAsync.when(
        data: (books) {
          final normalizedQuery = _searchQuery.trim().toLowerCase();
          final filteredBooks = normalizedQuery.isEmpty
              ? books
              : books.where((book) {
                  final title = book.title.toLowerCase();
                  final author = (book.author ?? '').toLowerCase();
                  return title.contains(normalizedQuery) ||
                      author.contains(normalizedQuery);
                }).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _LibraryHeader(
                  searchController: _searchController,
                  onSearchChanged: (value) =>
                      setState(() => _searchQuery = value),
                  onSettingsTap: () => context.push('/settings'),
                  totalBooks: books.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Row(
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          normalizedQuery.isEmpty
                              ? 'All Books'
                              : 'Search Results',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: .w800,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${filteredBooks.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: .w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (filteredBooks.isEmpty)
                const SliverToBoxAdapter(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                  sliver: SliverGrid.builder(
                    itemCount: filteredBooks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.67,
                        ),
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return _BookCard(book: book, index: index);
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          error: '$error',
          onRetry: () => ref.invalidate(bookLibraryProvider),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSettingsTap;
  final int totalBooks;

  const _LibraryHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSettingsTap,
    required this.totalBooks,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final isDark = theme.brightness == .dark;
    final searchBackground = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : const Color(0xFFFFFFFF);
    final searchBorder = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.35)
        : const Color(0xFFDCCFF3);
    final searchTextColor = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF2F2C42);
    final searchHintColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF9A91B0);
    final searchIconColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF8D82A7);

    return Padding(
      padding: EdgeInsets.fromLTRB(18, topPadding + 12, 18, 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: .topLeft,
            end: .bottomRight,
            colors: [Color(0xFFDCEBFF), Color(0xFFEDE4FF), Color(0xFFFFF5DD)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(68, 59, 130, 0.14),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Storia',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 34,
                        height: 1,
                        fontWeight: .w700,
                        color: const Color(0xFF41315D),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open settings',
                    onPressed: onSettingsTap,
                    icon: const Icon(Icons.settings_outlined),
                    color: const Color(0xFF51456E),
                  ),
                ],
              ),
              Semantics(
                label: '$totalBooks books ready for story time',
                child: Text(
                  '$totalBooks books ready for story time',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: .w500,
                    color: const Color(0xFF51456E),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: searchBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: searchBorder),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: .w500,
                    color: searchTextColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    labelText: 'Search books',
                    hintText: 'Search by title or author',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: searchHintColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: searchIconColor,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Clear search text',
                            color: searchIconColor,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final int index;

  const _BookCard({required this.book, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == .dark;
    final cardBackground = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.white;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF1F2937);
    final authorColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF6B7280);
    final cardShadow = isDark
        ? const Color.fromRGBO(0, 0, 0, 0.45)
        : const Color.fromRGBO(49, 43, 74, 0.12);
    final accent = index.isEven
        ? const Color(0xFF6F61C7)
        : const Color(0xFF2C7C9D);

    return Semantics(
          button: true,
          label:
              '${book.title}, by ${book.author ?? 'Unknown author'}, ${book.pages.length} pages',
          hint: 'Double tap to open this book in the reader',
          child: GestureDetector(
            onTap: () => context.push('/reader/${book.id}'),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cardShadow,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: .expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: book.coverUrl ?? '',
                              cacheManager: ResilientCacheManager.instance,
                              fit: .cover,
                              placeholder: (_, __) => const _CoverPlaceholder(),
                              errorWidget: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFE5E5DE)),
                            ),
                            Align(
                              alignment: .bottomCenter,
                              child: Container(
                                height: 64,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: .topCenter,
                                    end: .bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color.fromRGBO(0, 0, 0, 0.72),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: GoogleFonts.lora(
                        fontSize: 14,
                        height: 1.18,
                        fontWeight: .w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author ?? 'Unknown',
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: .w500,
                        color: authorColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${book.pages.length} pages',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: .w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: 45 * index))
        .fadeIn(duration: 360.ms)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
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
              begin: .topLeft,
              end: .bottomRight,
              colors: [Color(0xFFD6DAD3), Color(0xFFC6CDC4), Color(0xFFB8BEB6)],
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1400.ms);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 38,
                color: Color(0xFF8A8FA3),
              ),
              const SizedBox(height: 10),
              Text(
                'No books matched your search',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: .w700,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Try a different title or author.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: .w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
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
              18,
              MediaQuery.paddingOf(context).top + 12,
              18,
              16,
            ),
            child:
                Container(
                      height: 190,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1400.ms),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
          sliver: SliverGrid.builder(
            itemCount: 8,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.67,
            ),
            itemBuilder: (_, __) =>
                Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E2DB),
                        borderRadius: BorderRadius.circular(16),
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
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: Color(0xFF8A8FA3),
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load the library',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: .w700),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: .center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
