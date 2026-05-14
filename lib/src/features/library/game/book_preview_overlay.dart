import 'package:cached_network_image/cached_network_image.dart';
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_motion.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../data/models.dart';

/// A Flutter overlay widget that shows a popup preview card for a book.
///
/// Designed to float above a book in the gamified library shelf.
/// Position it inside a [Stack] using the [position] offset.
class BookPreviewOverlay extends StatelessWidget {
  const BookPreviewOverlay({
    super.key,
    required this.book,
    required this.onRead,
    required this.onDismiss,
    required this.position,
  });

  final Book book;
  final VoidCallback onRead;
  final VoidCallback onDismiss;

  /// Screen-space offset where the card should appear (above the book).
  final Offset position;

  Color get _accentColor {
    final colors = [
      StoriaColors.dustyPink,
      StoriaColors.mustard,
      StoriaColors.sage,
    ];
    return colors[book.pageCount % 3];
  }

  String get _readingBand {
    if (book.pageCount <= 8) return 'SOFT STARTER';
    if (book.pageCount <= 12) return 'BEDTIME FAVORITE';
    return 'LONGER ADVENTURE';
  }

  static const double _cardWidth = 280;
  static const double _arrowSize = 8;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _cardWidth / 2,
      top: position.dy,
      child: Cue.onMount(
        debugLabel: 'library-book-preview',
        motion: const CueMotion.easeOutBack(StoriaMotion.medium),
        acts: const [
          .fadeIn(motion: CueMotion.easeOut(StoriaMotion.medium)),
          .scale(from: 0, to: 1, alignment: Alignment.bottomCenter),
        ],
        child: GestureDetector(
          // Prevent taps on the card from dismissing
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _cardWidth,
                child: SketchCard(
                  padding: const EdgeInsets.all(14),
                  child: _buildContent(context),
                ),
              ),
              // Downward-pointing triangle arrow
              CustomPaint(
                size: const Size(_arrowSize * 2, _arrowSize),
                painter: _ArrowPainter(color: StoriaColors.paperRaised),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Book cover thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 60,
            height: 90,
            child: book.coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: book.coverUrl!,
                    cacheManager: ResilientCacheManager.instance,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: StoriaColors.paperAlt),
                    errorWidget: (_, __, ___) => _coverPlaceholder(),
                  )
                : _coverPlaceholder(),
          ),
        ),
        const SizedBox(width: 12),

        // Book details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reading band label
              Text(
                _readingBand,
                style: textTheme.labelSmall?.copyWith(
                  color: _accentColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),

              // Title
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  color: StoriaColors.ink,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),

              // Author
              if (book.author != null)
                Text(
                  book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: StoriaColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 6),

              // Page count pill + Read button row
              Row(
                children: [
                  // Page count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${book.pageCount} pages',
                      style: textTheme.labelSmall?.copyWith(
                        color: StoriaColors.ink,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Play button
                  GestureDetector(
                    onTap: onRead,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90D9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 3),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: StoriaColors.paperAlt,
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: StoriaColors.inkMuted,
          size: 24,
        ),
      ),
    );
  }
}

/// Paints a small downward-pointing triangle below the card.
class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => color != oldDelegate.color;
}
