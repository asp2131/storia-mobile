import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';

class LeafAccent extends StatelessWidget {
  const LeafAccent({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LeafAccentPainter()),
    );
  }
}

class _LeafAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = StoriaColors.ink.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final leftLeaf = Paint()
      ..color = StoriaColors.sage.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final rightLeaf = Paint()
      ..color = StoriaColors.dustyPink.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final stemPath = Path()
      ..moveTo(size.width * 0.3, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.56,
        size.width * 0.58,
        size.height * 0.16,
      );
    canvas.drawPath(stemPath, stem);

    final left = Path()
      ..moveTo(size.width * 0.24, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.02,
        size.height * 0.42,
        size.width * 0.22,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.45,
        size.width * 0.24,
        size.height * 0.62,
      );
    final right = Path()
      ..moveTo(size.width * 0.54, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.1,
        size.width * 0.84,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.6,
        size.width * 0.54,
        size.height * 0.42,
      );

    canvas.drawPath(left, leftLeaf);
    canvas.drawPath(right, rightLeaf);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
