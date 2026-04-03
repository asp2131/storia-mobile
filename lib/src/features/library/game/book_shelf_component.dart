import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../data/models.dart';

/// A Flame [PositionComponent] that renders a single book on a shelf.
///
/// Displays a colored placeholder rectangle with a book icon. When
/// [coverSprite] is set externally (e.g. after loading a network image),
/// the sprite is rendered instead of the placeholder.
///
/// While [isCoverLoading] is true and no cover sprite is set, the placeholder
/// gently pulses its opacity to indicate loading.
class BookShelfComponent extends PositionComponent with TapCallbacks {
  BookShelfComponent({
    required this.book,
    this.isDimmed = false,
    this.onBookTapped,
    super.position,
  }) : super(size: Vector2(70, 100));

  final Book book;
  bool isDimmed;
  void Function(Book book, double x)? onBookTapped;

  /// Whether the cover image is still loading.
  bool isCoverLoading = true;

  /// Elapsed time used to drive the shimmer pulse animation.
  double _elapsed = 0;

  /// Set externally to render a cover image instead of the placeholder.
  Sprite? _coverSprite;
  Sprite? get coverSprite => _coverSprite;
  set coverSprite(Sprite? value) {
    _coverSprite = value;
    isCoverLoading = false;
  }

  // ── Placeholder colors ──

  static const Color _placeholderFill = Color(0xFFF5E6D0); // warm beige
  static const Color _placeholderBorder = Color(0xFFD4C4A8); // slightly darker
  static const Color _iconColor = Color(0xFFA89070); // muted brown for icon
  static const Color _shelfColor = Color(0xFF8B6B47); // wood-brown shelf edge

  static const double _shelfHeight = 4;

  // ── Update ──

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  // ── Render ──

  @override
  void render(Canvas canvas) {
    final double baseOpacity = isDimmed ? 0.25 : 1.0;

    if (coverSprite != null) {
      _renderCoverSprite(canvas, baseOpacity);
    } else {
      // Pulse opacity between 0.5 and 1.0 when loading.
      final double opacity = isCoverLoading
          ? baseOpacity * (0.75 + 0.25 * math.sin(_elapsed * 3.0))
          : baseOpacity;
      _renderPlaceholder(canvas, opacity);
    }

    _renderShelf(canvas, baseOpacity);
  }

  void _renderCoverSprite(Canvas canvas, double opacity) {
    final paint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: opacity);
    coverSprite!.render(
      canvas,
      size: size,
      overridePaint: paint,
    );
  }

  void _renderPlaceholder(Canvas canvas, double opacity) {
    // Background fill
    final fillPaint = Paint()
      ..color = _placeholderFill.withValues(alpha: opacity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(3),
      ),
      fillPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = _placeholderBorder.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(3),
      ),
      borderPaint,
    );

    // Spine line (left edge detail)
    final spinePaint = Paint()
      ..color = _placeholderBorder.withValues(alpha: opacity)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(6, 4),
      Offset(6, size.y - 4),
      spinePaint,
    );

    // Simple book icon in center — two small rectangles
    final iconPaint = Paint()..color = _iconColor.withValues(alpha: opacity);
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Open book shape: left page
    canvas.drawRect(
      Rect.fromLTWH(cx - 12, cy - 8, 11, 16),
      iconPaint,
    );
    // Right page
    canvas.drawRect(
      Rect.fromLTWH(cx + 1, cy - 8, 11, 16),
      iconPaint,
    );
    // Spine
    final spineIconPaint = Paint()
      ..color = _placeholderFill.withValues(alpha: opacity)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx, cy - 8),
      Offset(cx, cy + 8),
      spineIconPaint,
    );
  }

  void _renderShelf(Canvas canvas, double opacity) {
    final shelfPaint = Paint()
      ..color = _shelfColor.withValues(alpha: opacity);
    canvas.drawRect(
      Rect.fromLTWH(-2, size.y, size.x + 4, _shelfHeight),
      shelfPaint,
    );
  }

  // ── Tap handling ──

  @override
  void onTapUp(TapUpEvent event) {
    if (!isDimmed) {
      onBookTapped?.call(book, position.x);
    }
  }
}
