import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models.dart';

/// A Flame [PositionComponent] that renders a book as a pedestal-style
/// adventure map destination marker.
///
/// Replaces the old shelf-based book display with a warm, map-node aesthetic:
/// ground shadow ellipse, cream pedestal with rounded corners, inset cover
/// image (or shimmer placeholder), single-line title, accent stripe, and
/// optional selected glow.
class MapBookNodeComponent extends PositionComponent with TapCallbacks {
  MapBookNodeComponent({
    required this.book,
    bool isVisible = true,
    this.onBookTapped,
    this.accentColor = const Color(0xFFFFB74D),
    super.position,
  }) : _isVisible = isVisible,
       _visibility = isVisible ? 1.0 : 0.0,
       super(size: Vector2(80, 110));

  static const double nodeWidth = 80;
  static const double nodeHeight = 110;

  /// Speed of the visibility fade/shrink, in units/second. 4.0 ≈ 250ms.
  static const double _visibilitySpeed = 4.0;

  /// Minimum scale a hidden node shrinks to (visible nodes render at 1.0).
  static const double _hiddenScale = 0.85;

  final Book book;

  /// Whether the node passes the active filter. Drives the fade/shrink toward
  /// fully shown (`true`) or fully hidden (`false`).
  ///
  /// Stored nullable so Flame components that survive a hot reload after this
  /// field was introduced do not crash with a null non-nullable field slot.
  bool? _isVisible;
  bool get isVisible => _isVisible ?? true;
  set isVisible(bool value) => _isVisible = value;

  /// Animated 0–1 visibility, lerped toward `isVisible` in [update]. Used as an
  /// opacity multiplier and to derive the node's render scale.
  ///
  /// Nullable for the same hot-reload safety reason as [_isVisible].
  double? _visibility;

  void Function(Book book, double x)? onBookTapped;

  /// Per-node accent color used for the stripe and selected glow.
  final Color accentColor;

  /// Whether the cover image is still loading.
  bool isCoverLoading = true;

  /// Whether the node is in the selected / focused state.
  bool isSelected = false;

  /// Temporary stronger focus state triggered when the avatar arrives.
  bool isArrivalFocused = false;

  /// Elapsed time used to drive animated effects.
  double _elapsed = 0;

  double _arrivalFocusRemaining = 0;

  /// Set externally to render a cover image instead of the placeholder.
  Sprite? _coverSprite;
  Sprite? get coverSprite => _coverSprite;
  set coverSprite(Sprite? value) {
    _coverSprite = value;
    isCoverLoading = false;
  }

  // ── Layout constants ──────────────────────────────────────────────────

  // Destination pad (ground shadow)
  static const double _padWidth = 90;
  static const double _padHeight = 24;

  // Pedestal
  static const double _pedestalWidth = 70;
  static const double _pedestalHeight = 90;
  static const double _pedestalCorner = 10;
  static const Color _pedestalFill = Color(0xFFFFF8E1);
  static const Color _pedestalBorder = Color(0xFFD7CCC8);

  // Cover inset
  static const double _coverSize = 54;
  static const double _coverCorner = 6;
  static const double _coverTopInset = 8;

  // Title
  static const double _titleFontSize = 9;
  static const double _titleMaxWidth = 58;
  static const Color _titleColor = Color(0xFF5D4037);

  // Accent stripe
  static const double _stripeWidth = 54;
  static const double _stripeHeight = 3;

  // Placeholder icon colors
  static const Color _placeholderFill = Color(0xFFF5E6D0);
  static const Color _iconColor = Color(0xFFA89070);

  // ── Update ──────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_arrivalFocusRemaining > 0) {
      _arrivalFocusRemaining = math.max(0, _arrivalFocusRemaining - dt);
      if (_arrivalFocusRemaining == 0) {
        isArrivalFocused = false;
      }
    }

    // Lerp visibility toward the filter target for a fade + shrink transition.
    final target = isVisible ? 1.0 : 0.0;
    final current = _visibilityValue;
    if (current != target) {
      final step = dt * _visibilitySpeed;
      if ((target - current).abs() <= step) {
        _visibility = target;
      } else {
        _visibility = current + (target - current).sign * step;
      }
    }
  }

  double get _visibilityValue {
    final value = _visibility;
    if (value != null) return value;

    final fallback = isVisible ? 1.0 : 0.0;
    _visibility = fallback;
    return fallback;
  }

  /// Whether the node is still part of the active map and shown enough to tap.
  bool get _isInteractable => isVisible && _visibilityValue >= 0.5;

  @visibleForTesting
  double get debugVisibility => _visibilityValue;

  @visibleForTesting
  bool get debugIsInteractable => _isInteractable;

  void triggerArrivalFocus({double duration = 1.2}) {
    isArrivalFocused = true;
    _arrivalFocusRemaining = duration;
  }

  Vector2 get centerPosition =>
      Vector2(position.x + size.x / 2, position.y + size.y);

  // ── Render ──────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Fully hidden nodes paint nothing (and are non-interactable).
    final visibility = _visibilityValue;
    if (visibility <= 0.001) {
      return;
    }

    // Smoothstep-eased visibility drives opacity and scale together so the
    // fade and shrink share one curve.
    final double eased = visibility * visibility * (3 - 2 * visibility);
    final double baseOpacity = eased;
    final double scale = _hiddenScale + (1 - _hiddenScale) * eased;

    // Center the pedestal horizontally within the 80px-wide component.
    final double offsetX = (size.x - _pedestalWidth) / 2;

    final bool scaled = scale != 1.0;
    if (scaled) {
      // Shrink toward the node's bottom-center so it sinks into its pad.
      final pivot = Offset(size.x / 2, size.y);
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(scale);
      canvas.translate(-pivot.dx, -pivot.dy);
    }

    // 1. Destination pad (ground shadow ellipse)
    _renderDestinationPad(canvas, baseOpacity);

    // 2. Selected / arrival glow (behind pedestal)
    if ((isSelected || isArrivalFocused) && _isInteractable) {
      _renderSelectedGlow(canvas, offsetX, baseOpacity);
    }

    // 3. Drop shadow
    _renderDropShadow(canvas, offsetX, baseOpacity);

    // 4. Pedestal base
    _renderPedestal(canvas, offsetX, baseOpacity);

    // 5. Cover inset
    _renderCover(canvas, offsetX, baseOpacity);

    // 6. Title bar
    _renderTitle(canvas, offsetX, baseOpacity);

    // 7. Accent stripe
    _renderAccentStripe(canvas, offsetX, baseOpacity);

    if (scaled) {
      canvas.restore();
    }
  }

  void _renderDestinationPad(Canvas canvas, double opacity) {
    final cx = size.x / 2;
    // Place the pad at the very bottom of the component.
    final cy = size.y - _padHeight / 2 + 2;

    final paint = Paint()
      ..shader = Gradient.radial(Offset(cx, cy), _padWidth / 2, [
        const Color(0xFF8D6E63).withValues(alpha: 0.30 * opacity),
        const Color(0xFF8D6E63).withValues(alpha: 0.0),
      ]);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: _padWidth,
        height: _padHeight,
      ),
      paint,
    );
  }

  void _renderSelectedGlow(Canvas canvas, double offsetX, double opacity) {
    final focusIntensity = isArrivalFocused
        ? 0.6 + 0.4 * math.sin(_elapsed * 10)
        : 1.0;
    final glowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offsetX - 6, -6, _pedestalWidth + 12, _pedestalHeight + 12),
      const Radius.circular(_pedestalCorner + 6),
    );
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.22 * opacity * focusIntensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        isArrivalFocused ? 12 : 8,
      );
    canvas.drawRRect(glowRect, glowPaint);
  }

  void _renderDropShadow(Canvas canvas, double offsetX, double opacity) {
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offsetX, 2, _pedestalWidth, _pedestalHeight),
      const Radius.circular(_pedestalCorner),
    );
    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.15 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(shadowRect, shadowPaint);
  }

  void _renderPedestal(Canvas canvas, double offsetX, double opacity) {
    final pedestalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offsetX, 0, _pedestalWidth, _pedestalHeight),
      const Radius.circular(_pedestalCorner),
    );

    // Fill
    final fillPaint = Paint()..color = _pedestalFill.withValues(alpha: opacity);
    canvas.drawRRect(pedestalRect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = _pedestalBorder.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(pedestalRect, borderPaint);
  }

  void _renderCover(Canvas canvas, double offsetX, double baseOpacity) {
    final coverLeft = offsetX + (_pedestalWidth - _coverSize) / 2;
    const coverTop = _coverTopInset;
    final coverRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(coverLeft, coverTop, _coverSize, _coverSize),
      const Radius.circular(_coverCorner),
    );

    if (coverSprite != null) {
      // Clip the sprite to the rounded cover rect.
      canvas.save();
      canvas.clipRRect(coverRect);
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: baseOpacity);
      coverSprite!.render(
        canvas,
        position: Vector2(coverLeft, coverTop),
        size: Vector2(_coverSize, _coverSize),
        overridePaint: paint,
      );
      canvas.restore();
    } else if (isCoverLoading) {
      // Shimmer pulse on cream fill.
      final pulseOpacity =
          baseOpacity * (0.75 + 0.25 * math.sin(_elapsed * 3.0));
      final shimmerPaint = Paint()
        ..color = _placeholderFill.withValues(alpha: pulseOpacity);
      canvas.drawRRect(coverRect, shimmerPaint);
    } else {
      // Static placeholder with book icon.
      final placeholderPaint = Paint()
        ..color = _placeholderFill.withValues(alpha: baseOpacity);
      canvas.drawRRect(coverRect, placeholderPaint);

      _renderPlaceholderIcon(
        canvas,
        coverLeft + _coverSize / 2,
        coverTop + _coverSize / 2,
        baseOpacity,
      );
    }
  }

  void _renderPlaceholderIcon(
    Canvas canvas,
    double cx,
    double cy,
    double opacity,
  ) {
    final iconPaint = Paint()..color = _iconColor.withValues(alpha: opacity);

    // Left page
    canvas.drawRect(Rect.fromLTWH(cx - 12, cy - 8, 11, 16), iconPaint);
    // Right page
    canvas.drawRect(Rect.fromLTWH(cx + 1, cy - 8, 11, 16), iconPaint);
    // Spine
    final spinePaint = Paint()
      ..color = _placeholderFill.withValues(alpha: opacity)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), spinePaint);
  }

  void _renderTitle(Canvas canvas, double offsetX, double opacity) {
    final titleTop = _coverTopInset + _coverSize + 4;
    final titleLeft = offsetX + (_pedestalWidth - _titleMaxWidth) / 2;

    final paragraphBuilder =
        ParagraphBuilder(
            ParagraphStyle(
              textAlign: TextAlign.center,
              maxLines: 1,
              ellipsis: '\u2026',
              fontSize: _titleFontSize,
            ),
          )
          ..pushStyle(
            TextStyle(
              color: _titleColor.withValues(alpha: opacity),
              fontSize: _titleFontSize,
            ),
          )
          ..addText(book.title);

    final paragraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: _titleMaxWidth));

    canvas.drawParagraph(paragraph, Offset(titleLeft, titleTop));
  }

  void _renderAccentStripe(Canvas canvas, double offsetX, double opacity) {
    final stripeLeft = offsetX + (_pedestalWidth - _stripeWidth) / 2;
    final stripeTop = _pedestalHeight - 6 - _stripeHeight;

    final stripePaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..strokeWidth = _stripeHeight
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(stripeLeft, stripeTop + _stripeHeight / 2),
      Offset(stripeLeft + _stripeWidth, stripeTop + _stripeHeight / 2),
      stripePaint,
    );
  }

  // ── Tap handling ──────────────────────────────────────────────────────

  @override
  void onTapUp(TapUpEvent event) {
    // Hidden / fading-out nodes are filtered off the map and ignore taps.
    if (_isInteractable) {
      onBookTapped?.call(book, position.x);
    }
  }
}
