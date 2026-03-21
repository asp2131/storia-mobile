import 'dart:math' as math;
import 'package:flutter/material.dart';

class VerticalLiquidClipper extends CustomClipper<Path> {
  final double progress;
  final bool revealFromTop;

  const VerticalLiquidClipper({
    required this.progress,
    this.revealFromTop = false,
  });

  @override
  Path getClip(Size size) {
    if (revealFromTop) {
      if (progress <= 0.0) return Path();
      if (progress >= 1.0) {
        return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      }

      final double waveY = size.height * progress;
      final double bulge = 72.0 * math.sin(progress * math.pi);

      final path = Path();
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, waveY);
      path.cubicTo(
        size.width * 0.75, waveY + bulge,
        size.width * 0.25, waveY + bulge,
        0, waveY,
      );
      path.close();
      return path;
    } else {
      if (progress <= 0.0) return Path();
      if (progress >= 1.0) {
        return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      }

      final double waveY = size.height * (1.0 - progress);
      final double bulge = 72.0 * math.sin(progress * math.pi);

      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, waveY);
      path.cubicTo(
        size.width * 0.75, waveY - bulge,
        size.width * 0.25, waveY - bulge,
        0, waveY,
      );
      path.close();
      return path;
    }
  }

  @override
  bool shouldReclip(VerticalLiquidClipper oldClipper) {
    return progress != oldClipper.progress ||
        revealFromTop != oldClipper.revealFromTop;
  }
}
