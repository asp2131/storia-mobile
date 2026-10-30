import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/loratone_library_colors.dart';
import '../../core/theme/storia_spacing.dart';
import '../../core/widgets/parental_gate.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../child/data/child_profile_providers.dart';
import '../reader/data/reading_checkpoint_provider.dart';
import '../reader/domain/reading_checkpoint.dart';
import 'library_providers.dart';

const _kLoraHead = 'assets/images/library/lora_head.png';
const _kCloudReader = 'assets/images/library/cloud_reader.png';
const _kDuo = 'assets/images/library/duo.png';

/// Room under the floating tab bar so the last row is never covered.
const double _kTabBarClearance = 110;

enum _LibraryTab { library, shelf }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibraryTab _tab = _LibraryTab.library;

  Future<void> _openBook(String bookId) async {
    await context.push('/reader/$bookId');
    // Progress changed while reading; reload the hero and shelf.
    ref
      ..invalidate(readingContinuationProvider)
      ..invalidate(libraryShelfProvider);
  }

  Future<void> _openParents() async {
    final passed = await ParentalGate.verify(context);
    if (!mounted || !passed) return;
    context.push('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookLibraryProvider);

    return Scaffold(
      backgroundColor: LoratoneLibraryColors.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: booksAsync.when(
                data: (books) => switch (_tab) {
                  _LibraryTab.library => _LibraryHome(
                    books: books,
                    onOpenBook: _openBook,
                  ),
                  _LibraryTab.shelf => _ShelfView(
                    books: books,
                    onOpenBook: _openBook,
                  ),
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: LoratoneLibraryColors.orange,
                  ),
                ),
                error: (_, __) => _LibraryMessage(
                  title: 'Our books could not load',
                  body: 'Check your connection and try again.',
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(bookLibraryProvider),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _TabBar(
                active: _tab,
                onLibrary: () => setState(() => _tab = _LibraryTab.library),
                onShelf: () => setState(() => _tab = _LibraryTab.shelf),
                onParents: _openParents,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Library tab ─────────────────────────────────────────────────────────

class _LibraryHome extends ConsumerStatefulWidget {
  const _LibraryHome({required this.books, required this.onOpenBook});

  final List<Book> books;
  final ValueChanged<String> onOpenBook;

  @override
  ConsumerState<_LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<_LibraryHome> {
  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    final childName = ref
        .watch(activeChildProfileProvider)
        .valueOrNull
        ?.displayName;
    final continuation = ref.watch(readingContinuationProvider).valueOrNull;
    final query = _query.trim().toLowerCase();
    final results = query.isEmpty
        ? books
        : books
              .where(
                (b) =>
                    b.title.toLowerCase().contains(query) ||
                    (b.author ?? '').toLowerCase().contains(query),
              )
              .toList();
    // The repository orders by inserted_at, so the newest books are last.
    final newest = books.reversed.take(8).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: _kTabBarClearance),
      children: [
        _Header(
          childName: childName,
          searching: _searching,
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _query = value),
          onSearchToggle: _toggleSearch,
        ),
        if (books.isEmpty)
          const _LibraryMessage(
            title: 'New books are on the way',
            body: 'Check back soon.',
          )
        else if (_searching) ...[
          if (results.isEmpty)
            _LibraryMessage(
              title: 'No books match "${_query.trim()}"',
              body: 'Try another word.',
            )
          else
            _BookGrid(books: results, onOpenBook: widget.onOpenBook),
        ] else ...[
          _Hero(
            books: books,
            continuation: continuation,
            onOpenBook: widget.onOpenBook,
          ),
          const _SectionTitle('New books'),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              itemCount: newest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) => SizedBox(
                width: 128,
                child: _BookTile(
                  book: newest[i],
                  coverHeight: 170,
                  onTap: () => widget.onOpenBook(newest[i].id),
                ),
              ),
            ),
          ),
          const _ComicsBanner(),
          const _SectionTitle('All books'),
          _BookGrid(books: books, onOpenBook: widget.onOpenBook),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.childName,
    required this.searching,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchToggle,
  });

  final String? childName;
  final bool searching;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchToggle;

  @override
  Widget build(BuildContext context) {
    final name = childName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Row(
        children: [
          const _LoraAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: searching
                ? TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: onSearchChanged,
                    style: libraryBody(size: 16, weight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Find a book',
                      hintStyle: libraryBody(
                        size: 16,
                        color: LoratoneLibraryColors.inkMuted,
                      ),
                      filled: true,
                      fillColor: LoratoneLibraryColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Hi there!' : 'Hi, $name!',
                        style: libraryDisplay(
                          size: 22,
                          weight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Headphones on? Let's go.",
                        style: libraryBody(
                          size: 13,
                          color: LoratoneLibraryColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          _RoundButton(
            tooltip: searching ? 'Close search' : 'Search books',
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            onPressed: onSearchToggle,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.books,
    required this.continuation,
    required this.onOpenBook,
  });

  final List<Book> books;
  final ReadingCheckpoint? continuation;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    final checkpoint = continuation;
    final resumed = checkpoint == null
        ? null
        : books.where((b) => b.id == checkpoint.bookId).firstOrNull;
    final book = resumed ?? books.last;
    final isResume = resumed != null && !checkpoint!.completed;
    final progress = isResume && book.pageCount > 0
        ? ((checkpoint.pageIndex + 1) / book.pageCount).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        button: true,
        label:
            '${isResume ? 'Keep listening' : 'Start listening'}: '
            '${book.title}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onOpenBook(book.id),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: LoratoneLibraryColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: LoratoneLibraryColors.cardShadow,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CoverArt(
                        book: book,
                        tint: LoratoneLibraryColors.yellow,
                        fallbackAsset: _kCloudReader,
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _Pill(
                          label: isResume
                              ? 'Keep listening'
                              : 'Start listening',
                          leading: const _EqBars(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: libraryDisplay(size: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isResume
                                  ? 'Page ${checkpoint.pageIndex + 1} of '
                                        '${book.pageCount}'
                                  : 'Read aloud with music',
                              style: libraryBody(
                                size: 12,
                                color: LoratoneLibraryColors.inkMuted,
                              ),
                            ),
                            if (isResume) ...[
                              const SizedBox(height: 8),
                              _ProgressBar(value: progress),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: LoratoneLibraryColors.orange,
                          shape: BoxShape.circle,
                          boxShadow: LoratoneLibraryColors.cardShadow,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: LoratoneLibraryColors.ink,
                        ),
                      ),
                    ],
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

/// Comics aren't tagged in the catalog yet, so this teases the first one
/// with the duo art and a countdown to its launch.
class _ComicsBanner extends ConsumerStatefulWidget {
  const _ComicsBanner();

  @override
  ConsumerState<_ComicsBanner> createState() => _ComicsBannerState();
}

class _ComicsBannerState extends ConsumerState<_ComicsBanner> {
  // Local midnight, so the countdown hits zero on the kid's own Nov 8.
  static final _launch = DateTime(2026, 11, 8);
  static final _learnMoreUri = Uri.parse('https://loratone.com/hat-trickster');

  // Minutes are the smallest unit shown, so a 30 s tick is plenty.
  late final Timer _ticker = Timer.periodic(
    const Duration(seconds: 30),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _ticker;
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _learnMore() async {
    final launched = await launchUrl(
      _learnMoreUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }

  @override
  Widget build(BuildContext context) {
    final left = _launch.difference(ref.watch(libraryClockProvider)());
    final launched = left <= Duration.zero;
    final muted = LoratoneLibraryColors.paper.withValues(alpha: 0.85);

    return Container(
      margin: const EdgeInsets.only(top: 26),
      color: LoratoneLibraryColors.navy,
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pill(
                    label: launched ? 'Out now' : 'Coming Nov 8',
                    background: LoratoneLibraryColors.yellow,
                    foreground: LoratoneLibraryColors.ink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    launched ? 'Comics are here' : 'Comics are coming',
                    style: libraryDisplay(color: LoratoneLibraryColors.paper),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loratone Originals with their own soundtracks.',
                    style: libraryBody(size: 13, color: muted),
                  ),
                  if (!launched) ...[
                    const SizedBox(height: 14),
                    _Countdown(left: left),
                  ],
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _learnMore,
                    style: TextButton.styleFrom(
                      foregroundColor: LoratoneLibraryColors.yellow,
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Learn more',
                          style: libraryDisplay(
                            size: 16,
                            weight: FontWeight.w800,
                            color: LoratoneLibraryColors.yellow,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ExcludeSemantics(
            child: Image.asset(_kDuo, height: 170, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final units = [
      (left.inDays, 'days'),
      (left.inHours % 24, 'hrs'),
      (left.inMinutes % 60, 'min'),
    ];
    return Semantics(
      container: true,
      label:
          '${units[0].$1} days, ${units[1].$1} hours, '
          '${units[2].$1} minutes to go',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (value, unit) in units) ...[
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: LoratoneLibraryColors.paper.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: libraryDisplay(
                      size: 22,
                      color: LoratoneLibraryColors.paper,
                    ),
                  ),
                  Text(
                    unit,
                    style: libraryBody(
                      size: 11,
                      weight: FontWeight.w700,
                      color: LoratoneLibraryColors.paper.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── My shelf tab ────────────────────────────────────────────────────────

class _ShelfView extends ConsumerWidget {
  const _ShelfView({required this.books, required this.onOpenBook});

  final List<Book> books;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkpoints = ref.watch(libraryShelfProvider).valueOrNull ?? const [];
    final byId = {for (final b in books) b.id: b};
    final entries = [
      for (final c in checkpoints)
        if (byId[c.bookId] case final book?) (book: book, checkpoint: c),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, _kTabBarClearance),
      children: [
        Text('My shelf', style: libraryDisplay(size: 30)),
        const SizedBox(height: 4),
        Text(
          'Books you started wait for you here.',
          style: libraryBody(color: LoratoneLibraryColors.inkMuted),
        ),
        const SizedBox(height: 18),
        if (entries.isEmpty)
          const _LibraryMessage(
            title: 'Your shelf is empty',
            body: 'Start any book and it will show up here.',
          )
        else
          _Grid(
            children: [
              for (final e in entries)
                _BookTile(
                  book: e.book,
                  subtitle: e.checkpoint.completed
                      ? 'Finished'
                      : 'Page ${e.checkpoint.pageIndex + 1} of '
                            '${e.book.pageCount}',
                  onTap: () => onOpenBook(e.book.id),
                ),
            ],
          ),
      ],
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Semantics(
        header: true,
        child: Text(text, style: libraryDisplay()),
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.onOpenBook});

  final List<Book> books;
  final ValueChanged<String> onOpenBook;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _Grid(
        children: [
          for (final book in books)
            _BookTile(book: book, onTap: () => onOpenBook(book.id)),
        ],
      ),
    );
  }
}

/// Two-column grid that lives inside a parent scroll view.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.6,
      children: children,
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.onTap,
    this.subtitle,
    this.coverHeight,
  });

  final Book book;
  final VoidCallback onTap;
  final String? subtitle;

  /// Fixed height for horizontal rows; grids let the cover fill the cell.
  final double? coverHeight;

  @override
  Widget build(BuildContext context) {
    final cover = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: LoratoneLibraryColors.cardShadow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CoverArt(book: book),
          const Positioned(top: 7, left: 7, child: _Pill(label: '♪ Book')),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: book.title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverHeight != null)
              SizedBox(height: coverHeight, child: cover)
            else
              Expanded(child: cover),
            const SizedBox(height: 8),
            Text(
              book.title,
              style: libraryDisplay(size: 15, weight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: libraryBody(
                  size: 12,
                  color: LoratoneLibraryColors.inkMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A book's cover on a tinted backdrop. Missing or broken covers fall back
/// to [fallbackAsset], or to a quiet book glyph (the title sits below).
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.book, this.tint, this.fallbackAsset});

  final Book book;
  final Color? tint;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final tints = LoratoneLibraryColors.coverTints;
    final color = tint ?? tints[book.id.hashCode.abs() % tints.length];
    final asset = fallbackAsset;
    // Zoomed toward the art's upper left, where the characters sit.
    const focus = Alignment(-0.45, -0.5);
    final Widget fallback = asset != null
        ? Transform.scale(
            scale: 1.35,
            alignment: focus,
            child: Image.asset(asset, fit: BoxFit.cover, alignment: focus),
          )
        : Icon(
            Icons.auto_stories_rounded,
            size: 44,
            color: LoratoneLibraryColors.ink.withValues(alpha: 0.25),
          );
    final url = book.coverUrl;

    return ColoredBox(
      color: color,
      // Image.network, not CachedNetworkImage: the latter paints black on web
      // after a route return (see .wolf/cerebrum.md).
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

class _LoraAvatar extends StatelessWidget {
  const _LoraAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: LoratoneLibraryColors.blue,
        shape: BoxShape.circle,
      ),
      child: ExcludeSemantics(
        child: Transform.scale(
          scale: 1.5,
          child: Image.asset(_kLoraHead, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.leading,
    this.background = LoratoneLibraryColors.ink,
    this.foreground = Colors.white,
  });

  final String label;
  final Widget? leading;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: libraryBody(
              size: 11,
              weight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Little animated equalizer: sound is the product, so it shows on the hero.
class _EqBars extends StatefulWidget {
  const _EqBars();

  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 3,
              height: 12 * (0.3 + 0.7 * ((_controller.value + i * 0.27) % 1)),
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: LoratoneLibraryColors.yellow,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: LoratoneLibraryColors.track,
        color: LoratoneLibraryColors.orange,
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: LoratoneLibraryColors.cardShadow,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: LoratoneLibraryColors.ink),
        style: IconButton.styleFrom(
          backgroundColor: LoratoneLibraryColors.surface,
          fixedSize: const Size(44, 44),
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(StoriaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Image.asset(_kCloudReader, height: 180)),
          const SizedBox(height: StoriaSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: libraryDisplay(size: 20),
          ),
          const SizedBox(height: StoriaSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: libraryBody(color: LoratoneLibraryColors.inkMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: StoriaSpacing.lg),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: LoratoneLibraryColors.orange,
                foregroundColor: LoratoneLibraryColors.ink,
                minimumSize: const Size(160, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                actionLabel!,
                style: libraryDisplay(size: 17, weight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.active,
    required this.onLibrary,
    required this.onShelf,
    required this.onParents,
  });

  final _LibraryTab active;
  final VoidCallback onLibrary;
  final VoidCallback onShelf;
  final VoidCallback onParents;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LoratoneLibraryColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Library',
            icon: Icons.auto_stories_rounded,
            selected: active == _LibraryTab.library,
            onTap: onLibrary,
          ),
          _TabButton(
            label: 'My shelf',
            icon: Icons.favorite_rounded,
            selected: active == _LibraryTab.shelf,
            onTap: onShelf,
          ),
          // Parents is never "selected": it leaves via the parental gate.
          _TabButton(
            label: 'Parents',
            icon: Icons.lock_rounded,
            selected: false,
            onTap: onParents,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? LoratoneLibraryColors.ink
        : LoratoneLibraryColors.paper;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? LoratoneLibraryColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: fg),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: libraryDisplay(
                      size: 12,
                      weight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
