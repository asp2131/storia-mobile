import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';

class PaperTextureOverlay extends StatelessWidget {
  const PaperTextureOverlay({super.key, this.opacity = 0.18});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PaperTexturePainter(opacity),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = StoriaColors.ink.withValues(alpha: opacity * 0.14)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = StoriaColors.paperAlt.withValues(alpha: opacity * 0.6)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 18) {
      final wave = (x % 36) / 36;
      canvas.drawLine(
        Offset(x, size.height * 0.16 + wave * 6),
        Offset(x + 8, size.height * 0.16 + 2 + wave * 6),
        linePaint,
      );
    }

    for (var row = 0; row < 42; row++) {
      final y = (size.height / 42) * row;
      for (var col = 0; col < 18; col++) {
        final x = (size.width / 18) * col + ((row.isEven ? 1 : -1) * 3);
        final radius = 0.6 + ((row + col) % 3) * 0.22;
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
