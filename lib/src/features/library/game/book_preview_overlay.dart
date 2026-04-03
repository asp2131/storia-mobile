import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../data/models.dart';

/// A Flutter overlay widget that shows a popup preview card for a book.
///
/// Designed to float above a book in the gamified library shelf.
/// Position it inside a [Stack] using the [position] offset.
class BookPreviewOverlay extends StatefulWidget {
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

  @override
  State<BookPreviewOverlay> createState() => _BookPreviewOverlayState();
}

class _BookPreviewOverlayState extends State<BookPreviewOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    final colors = [
      StoriaColors.dustyPink,
      StoriaColors.mustard,
      StoriaColors.sage,
    ];
    return colors[widget.book.pageCount % 3];
  }

  String get _readingBand {
    if (widget.book.pageCount <= 8) return 'SOFT STARTER';
    if (widget.book.pageCount <= 12) return 'BEDTIME FAVORITE';
    return 'LONGER ADVENTURE';
  }

  static const double _cardWidth = 280;
  static const double _arrowSize = 8;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - _cardWidth / 2,
      top: widget.position.dy,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          alignment: Alignment.bottomCenter,
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
            child: widget.book.coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.book.coverUrl!,
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
                widget.book.title,
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
              if (widget.book.author != null)
                Text(
                  widget.book.author!,
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
                      '${widget.book.pageCount} pages',
                      style: textTheme.labelSmall?.copyWith(
                        color: StoriaColors.ink,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Read button
                  SizedBox(
                    height: 30,
                    child: FilledButton.icon(
                      onPressed: widget.onRead,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: StoriaColors.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.auto_stories, size: 14),
                      label: const Text('Read'),
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
