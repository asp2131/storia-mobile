import 'dart:math' as math;

import 'package:flutter/material.dart';

class ReaderVerticalGooClipper extends CustomClipper<Path> {
  const ReaderVerticalGooClipper({
    required this.progress,
    required this.revealFromTop,
    required this.edgeTension,
  });

  final double progress;
  final bool revealFromTop;
  final double edgeTension;

  @override
  Path getClip(Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return Path();
    }
    if (clampedProgress >= 1) {
      return Path()..addRect(Offset.zero & size);
    }

    final amplitude = _gooAmplitude(size, clampedProgress, edgeTension);
    return revealFromTop
        ? _buildRevealFromTop(size, clampedProgress, amplitude)
        : _buildRevealFromBottom(size, clampedProgress, amplitude);
  }

  double _gooAmplitude(Size size, double progress, double tension) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final sine = math.sin(eased * math.pi);
    final baseAmplitude = size.height * 0.16;
    final widthContribution = size.width * 0.065;
    final amplitude =
        (baseAmplitude + widthContribution) * (0.52 + (sine * 0.6)) * tension;
    return amplitude.clamp(20.0, size.height * 0.26);
  }

  Path _buildRevealFromTop(Size size, double progress, double amplitude) {
    final waveY = size.height * progress;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, waveY)
      ..cubicTo(
        size.width * 0.88,
        waveY + amplitude,
        size.width * 0.12,
        waveY + amplitude,
        0,
        waveY,
      )
      ..close();
  }

  Path _buildRevealFromBottom(Size size, double progress, double amplitude) {
    final waveY = size.height * (1 - progress);

    return Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, waveY)
      ..cubicTo(
        size.width * 0.88,
        waveY - amplitude,
        size.width * 0.12,
        waveY - amplitude,
        0,
        waveY,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant ReaderVerticalGooClipper oldClipper) {
    return progress != oldClipper.progress ||
        revealFromTop != oldClipper.revealFromTop ||
        edgeTension != oldClipper.edgeTension;
  }
}

class ReaderGooEdgeHighlight extends StatelessWidget {
  const ReaderGooEdgeHighlight({
    super.key,
    required this.progress,
    required this.revealFromTop,
  });

  final double progress;
  final bool revealFromTop;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final opacity = 0.1 + (eased * 0.24);
    final thickness = 0.14 + (eased * 0.1);

    final alignment = revealFromTop ? Alignment.bottomCenter : Alignment.topCenter;
    final begin = revealFromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final end = revealFromTop ? Alignment.bottomCenter : Alignment.topCenter;

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: [
                  Colors.white.withValues(alpha: opacity),
                  Colors.white.withValues(alpha: opacity * 0.52),
                  Colors.white.withValues(alpha: opacity * 0.16),
                  Colors.transparent,
                ],
                stops: const [0, 0.18, 0.54, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderGooEdgeShadow extends StatelessWidget {
  const ReaderGooEdgeShadow({
    super.key,
    required this.progress,
    required this.revealFromTop,
  });

  final double progress;
  final bool revealFromTop;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final opacity = 0.08 + (eased * 0.18);
    final thickness = 0.16 + (eased * 0.1);
    final alignment = revealFromTop ? Alignment.bottomCenter : Alignment.topCenter;
    final begin = revealFromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final end = revealFromTop ? Alignment.bottomCenter : Alignment.topCenter;

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: thickness,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: [
                  Colors.black.withValues(alpha: opacity),
                  Colors.black.withValues(alpha: opacity * 0.44),
                  Colors.transparent,
                ],
                stops: const [0, 0.34, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
