import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/resilient_cache_manager.dart';
import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../data/models.dart';
import '../../progress/domain/book_progress.dart';

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
    required this.onPlay,
    this.progress,
    this.showPlay = true,
  });

  final Book book;
  final VoidCallback onRead;
  final VoidCallback? onPlay;
  final VoidCallback onDismiss;
  final BookProgress? progress;
  final bool showPlay;

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

  String get _statusLabel {
    final progress = widget.progress;
    if (progress == null) return 'New';
    return switch (progress.status) {
      BookProgressStatus.completed => 'Completed',
      BookProgressStatus.inProgress => 'Continue · Page ${progress.currentPage}',
      BookProgressStatus.newBook => 'New',
    };
  }

  static const double _cardWidth = 300;
  static const double _arrowSize = 8;

  String get _primaryActionLabel {
    final progress = widget.progress;
    if (progress == null) return 'Read';
    return switch (progress.status) {
      BookProgressStatus.inProgress => 'Resume',
      BookProgressStatus.completed => 'Read Again',
      BookProgressStatus.newBook => 'Read',
    };
  }

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
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 68,
            height: 96,
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if ((widget.book.author ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: StoriaColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaPill(
                    label: _statusLabel,
                    background: _accentColor.withValues(alpha: 0.16),
                  ),
                  _MetaPill(label: '${widget.book.pageCount} pages'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.showPlay && widget.onPlay != null) ...[
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: IconButton.filled(
                        onPressed: widget.onPlay,
                        tooltip: 'Play',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onRead,
                      style: FilledButton.styleFrom(
                        backgroundColor: StoriaColors.ink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(_primaryActionLabel),
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

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.background});

  final String label;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? StoriaColors.paperAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: StoriaColors.ink,
          fontWeight: FontWeight.w700,
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
