import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';

class WatercolorBlobs extends StatelessWidget {
  const WatercolorBlobs({
    super.key,
    this.dark = false,
    this.showCenterGlow = true,
  });

  final bool dark;
  final bool showCenterGlow;

  @override
  Widget build(BuildContext context) {
    final glowColor = dark ? StoriaColors.mustard : StoriaColors.mustard;
    // Static backdrop: its own layer, so screen content repainting above it
    // doesn't re-run the blurs.
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -30,
              left: -36,
              child: _Blob(
                width: 220,
                height: 220,
                color: dark
                    ? StoriaColors.sage.withValues(alpha: 0.18)
                    : StoriaColors.sage.withValues(alpha: 0.42),
              ),
            ),
            Positioned(
              top: 70,
              right: -60,
              child: _Blob(
                width: 250,
                height: 250,
                color: dark
                    ? StoriaColors.dustyPink.withValues(alpha: 0.16)
                    : StoriaColors.dustyPink.withValues(alpha: 0.36),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -20,
              child: _Blob(
                width: 260,
                height: 240,
                color: dark
                    ? StoriaColors.sage.withValues(alpha: 0.12)
                    : StoriaColors.sage.withValues(alpha: 0.22),
              ),
            ),
            if (showCenterGlow)
              Align(
                alignment: const Alignment(0, -0.08),
                // Blurs only the glow. The old unclipped BackdropFilter re-blurred
                // everything behind it, up to the whole screen, on every repaint.
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: dark ? 0.12 : 0.22),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(width * 0.42),
        ),
      ),
    );
  }
}
