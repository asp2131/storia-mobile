import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders a dirt-road route connecting all book node positions on the
/// adventure map. The visual is a warm-brown base stroke overlaid with a
/// dashed lighter-tan line, creating a dotted-trail-over-dirt-road look.
class MapRouteComponent extends PositionComponent {
  MapRouteComponent({required List<Vector2> nodePositions})
    : _nodePositions = nodePositions;

  final List<Vector2> _nodePositions;

  double _highlightProgress = -1;
  double _highlightTargetProgress = -1;

  // -- Route base style --
  static const Color _baseBrown = Color(0xFF8D6E63);
  static const double _baseWidth = 6.0;

  // -- Dash overlay style --
  static const Color _dashTan = Color(0xB3D7CCC8); // #D7CCC8 at 70% opacity
  static const double _dashWidth = 3.0;
  static const double _dashLength = 12.0;
  static const double _gapLength = 8.0;

  late final Paint _basePaint;
  late final Paint _dashPaint;
  late final Paint _highlightPaint;
  late final Path _routePath;

  @override
  Future<void> onLoad() async {
    _basePaint = Paint()
      ..color = _baseBrown
      ..strokeWidth = _baseWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    _dashPaint = Paint()
      ..color = _dashTan
      ..strokeWidth = _dashWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    _highlightPaint = Paint()
      ..color = const Color(0xFFFFE082)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    _routePath = _buildPath();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_highlightProgress == _highlightTargetProgress) {
      return;
    }
    const speed = 2.8;
    final delta = (_highlightTargetProgress - _highlightProgress);
    final step = dt * speed;
    if (delta.abs() <= step) {
      _highlightProgress = _highlightTargetProgress;
    } else {
      _highlightProgress += delta.sign * step;
    }
  }

  void setHighlightToNodeIndex(int? index) {
    if (index == null || _nodePositions.length < 2) {
      _highlightTargetProgress = -1;
      return;
    }
    final maxSegmentIndex = (_nodePositions.length - 1).clamp(1, 1 << 20);
    _highlightTargetProgress = (index / maxSegmentIndex).clamp(0.0, 1.0);
    if (_highlightProgress < 0) {
      _highlightProgress = _highlightTargetProgress;
    }
  }

  Path _buildPath() {
    final path = Path();
    if (_nodePositions.isEmpty) return path;

    path.moveTo(_nodePositions.first.x, _nodePositions.first.y);
    for (var i = 1; i < _nodePositions.length; i++) {
      path.lineTo(_nodePositions[i].x, _nodePositions[i].y);
    }
    return path;
  }

  @override
  void render(Canvas canvas) {
    if (_nodePositions.length < 2) return;

    // Draw the solid brown base road.
    canvas.drawPath(_routePath, _basePaint);

    if (_highlightProgress >= 0) {
      for (final metric in _routePath.computeMetrics()) {
        final highlightLength =
            metric.length * _highlightProgress.clamp(0.0, 1.0);
        if (highlightLength > 0) {
          canvas.drawPath(
            metric.extractPath(0, highlightLength),
            _highlightPaint,
          );
        }
      }
    }

    // Draw the dashed tan overlay using PathMetrics.
    final pathMetrics = _routePath.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), _dashPaint);
        distance += _dashLength + _gapLength;
      }
    }
  }
}
