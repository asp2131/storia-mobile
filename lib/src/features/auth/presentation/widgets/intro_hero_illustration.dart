import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/storia_colors.dart';

class IntroHeroIllustration extends StatefulWidget {
  const IntroHeroIllustration({super.key});

  @override
  State<IntroHeroIllustration> createState() => _IntroHeroIllustrationState();
}

class _IntroHeroIllustrationState extends State<IntroHeroIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dy = math.sin(_controller.value * math.pi) * 6;
        return Transform.translate(
          offset: Offset(0, -dy),
          child: CustomPaint(
            size: const Size(310, 310),
            painter: _IntroHeroPainter(),
          ),
        );
      },
    );
  }
}

class _IntroHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final glow = Paint()
      ..color = StoriaColors.mustard.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center.translate(0, 8), 54, glow);

    final branch = Paint()
      ..color = const Color(0xFF9C8472).withValues(alpha: 0.75)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 18;
    canvas.drawLine(
      Offset(26, size.height * 0.76),
      Offset(size.width - 20, size.height * 0.7),
      branch,
    );

    final owlBody = Paint()
      ..color = StoriaColors.dustyPink.withValues(alpha: 0.74);
    final owlBelly = Paint()
      ..color = StoriaColors.paper.withValues(alpha: 0.92);
    final outline = Paint()
      ..color = StoriaColors.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3;

    final bodyRect = Rect.fromCenter(
      center: center.translate(0, 10),
      width: 126,
      height: 150,
    );
    canvas.drawOval(bodyRect, owlBody);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 28), width: 84, height: 102),
      owlBelly,
    );
    canvas.drawOval(bodyRect, outline);

    final earPath = Path()
      ..moveTo(center.dx - 46, center.dy - 74)
      ..lineTo(center.dx - 62, center.dy - 112)
      ..lineTo(center.dx - 24, center.dy - 84)
      ..moveTo(center.dx + 46, center.dy - 74)
      ..lineTo(center.dx + 62, center.dy - 112)
      ..lineTo(center.dx + 24, center.dy - 84);
    canvas.drawPath(earPath, outline);

    final eyeFill = Paint()..color = Colors.white;
    canvas.drawCircle(center.translate(-26, -26), 16, eyeFill);
    canvas.drawCircle(center.translate(26, -26), 16, eyeFill);
    canvas.drawCircle(
      center.translate(-22, -24),
      4,
      Paint()..color = StoriaColors.ink,
    );
    canvas.drawCircle(
      center.translate(22, -24),
      4,
      Paint()..color = StoriaColors.ink,
    );

    final beak = Path()
      ..moveTo(center.dx - 8, center.dy - 6)
      ..lineTo(center.dx + 8, center.dy - 6)
      ..lineTo(center.dx, center.dy + 10)
      ..close();
    canvas.drawPath(beak, Paint()..color = StoriaColors.mustard);
    canvas.drawPath(beak, outline..strokeWidth = 2);

    final bookRect = Rect.fromCenter(
      center: center.translate(0, 82),
      width: 150,
      height: 74,
    );
    final leftPage = Path()
      ..moveTo(bookRect.center.dx, bookRect.bottom)
      ..lineTo(bookRect.left, bookRect.center.dy + 12)
      ..lineTo(bookRect.left, bookRect.top)
      ..quadraticBezierTo(
        bookRect.center.dx - 46,
        bookRect.top + 8,
        bookRect.center.dx,
        bookRect.top + 18,
      )
      ..close();
    final rightPage = Path()
      ..moveTo(bookRect.center.dx, bookRect.bottom)
      ..lineTo(bookRect.right, bookRect.center.dy + 12)
      ..lineTo(bookRect.right, bookRect.top)
      ..quadraticBezierTo(
        bookRect.center.dx + 46,
        bookRect.top + 8,
        bookRect.center.dx,
        bookRect.top + 18,
      )
      ..close();
    canvas.drawPath(leftPage, Paint()..color = StoriaColors.mustard);
    canvas.drawPath(rightPage, Paint()..color = StoriaColors.mustardDeep);
    canvas.drawPath(leftPage, outline);
    canvas.drawPath(rightPage, outline);

    final sparklePaint = Paint()
      ..color = StoriaColors.mustardDeep
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final point in [
      center.translate(-60, -54),
      center.translate(0, -80),
      center.translate(68, -40),
    ]) {
      canvas.drawLine(
        point.translate(-4, 0),
        point.translate(4, 0),
        sparklePaint,
      );
      canvas.drawLine(
        point.translate(0, -4),
        point.translate(0, 4),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
