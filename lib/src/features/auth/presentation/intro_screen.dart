import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' as rive;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/storia_colors.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const _heroSize = 320.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  late final rive.FileLoader _landingRiveLoader = rive.FileLoader.fromAsset(
    'assets/gifs/landing_anim.riv',
    riveFactory: rive.Factory.rive,
  );

  @override
  void dispose() {
    _controller.dispose();
    // Do not dispose _landingRiveLoader here: on web, rive's FileLoader can
    // complete asynchronously after this screen is redirected away. Disposing
    // while that load is still in flight clears its completer and throws
    // "Unexpected null value" from package:rive/src/file_loader.dart.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = StoriaColors.ink;
    const fg = StoriaColors.inkMuted;
    const btn = StoriaColors.sage;

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: SvgPicture.asset(
                    'assets/svgs/landing_bg.svg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.45),
                        radius: 0.45,
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sun with warm radial glow pulse
              _floatingSunWithGlow(
                top: 32,
                right: 12,
                width: 118,
                height: 118,
                phase: 0.1,
                amplitude: 2,
              ),

              // --- Far layer clouds (behind content) ---
              _driftingCloud(
                top: 56,
                width: 104,
                height: 48,
                phase: 0.15,
                speed: 0.40,
                yAmplitude: 3,
                opacity: 0.45,
                scale: 0.60,
                blurSigma: 1.8,
                flipX: false,
              ),
              _driftingCloud(
                top: 88,
                width: 96,
                height: 44,
                phase: 0.65,
                speed: 0.38,
                yAmplitude: 2.5,
                opacity: 0.42,
                scale: 0.58,
                blurSigma: 1.6,
                flipX: true,
              ),

              // --- Mid layer clouds (behind content) ---
              _driftingCloud(
                top: 80,
                width: 148,
                height: 68,
                phase: 0.02,
                speed: 0.70,
                yAmplitude: 5,
                opacity: 0.80,
                scale: 0.90,
                flipX: false,
              ),
              _driftingCloud(
                top: 200,
                width: 130,
                height: 60,
                phase: 0.43,
                speed: 0.65,
                yAmplitude: 4,
                opacity: 0.75,
                scale: 0.85,
                flipX: true,
              ),
              _driftingCloud(
                top: screenHeight * 0.44,
                width: 160,
                height: 76,
                phase: 0.68,
                speed: 0.78,
                yAmplitude: 6,
                opacity: 0.88,
                scale: 0.95,
                flipX: false,
              ),

              // --- Main content (SafeArea) ---
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 34),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          SizedBox(
                            width: _heroSize,
                            height: _heroSize,
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                math.sin(_controller.value * math.pi * 12) *
                                    -4.2,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            btn.withValues(alpha: 0.48),
                                            btn.withValues(alpha: 0.28),
                                            btn.withValues(alpha: 0.10),
                                          ],
                                          stops: const [0.0, 0.66, 1.0],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: btn.withValues(alpha: 0.38),
                                            blurRadius: 44,
                                            spreadRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: rive.RiveWidgetBuilder(
                                      fileLoader: _landingRiveLoader,
                                      // Some .riv files have an invalid "default" state machine index.
                                      // Select the first state machine explicitly to avoid runtime RangeError.
                                      controller: (file) => rive.RiveWidgetController(
                                        file,
                                        stateMachineSelector:
                                            rive.StateMachineSelector.byIndex(0),
                                      ),
                                      onFailed: (error, stackTrace) {
                                        debugPrint(
                                          'Failed to load landing Rive: $error',
                                        );
                                      },
                                      builder: (context, state) => switch (state) {
                                        rive.RiveLoading() => const SizedBox.expand(),
                                        rive.RiveFailed() => const SizedBox.expand(),
                                        rive.RiveLoaded() => rive.RiveWidget(
                                          controller: state.controller,
                                          fit: rive.Fit.cover,
                                        ),
                                      },
                                    ),
                                  ),
                                  _sparkle(
                                    top: 20,
                                    right: 16,
                                    size: 22,
                                    phase: 0.08,
                                  ),
                                  _sparkle(
                                    bottom: 26,
                                    left: 18,
                                    size: 18,
                                    phase: 0.44,
                                  ),
                                  _sparkle(
                                    top: 84,
                                    left: -8,
                                    size: 14,
                                    phase: 0.72,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Column(
                            children: [
                              Text(
                                'Storia Kids',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  color: primary,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'We are redefining reading experiences for children through adaptive sounds and multi-sensory literary engagement.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.baloo2(
                                  color: fg,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.38,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(flex: 3),
                          _TactileButton(
                            label: 'Start your journey',
                            background: btn,
                            foreground: primary,
                            borderColor: primary,
                            trailing: const Icon(Icons.arrow_forward, size: 20),
                            onPressed: () => context.go('/sign-up'),
                          ),
                          const SizedBox(height: 14),
                          _TactileButton(
                            label: 'Already have a bookmark? Sign in',
                            background: Colors.white,
                            foreground: primary,
                            borderColor: primary,
                            onPressed: () => context.go('/sign-in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- Near layer cloud (ABOVE content, peeking from right) ---
              _driftingCloudNear(
                top: screenHeight * 0.55,
                width: 200,
                height: 92,
                phase: 0.30,
                speed: 1.30,
                yAmplitude: 4,
                opacity: 0.90,
                scale: 1.40,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sun with a warm radial glow pulse behind it.
  Widget _floatingSunWithGlow({
    required double top,
    required double right,
    required double width,
    required double height,
    required double phase,
    required double amplitude,
  }) {
    final dy = math.sin((_controller.value + phase) * math.pi * 2) * amplitude;
    final glowOpacity =
        0.15 + 0.1 * math.sin(_controller.value * math.pi * 2);

    return Positioned(
      top: top + dy,
      right: right,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Warm radial glow behind the sun
            Container(
              width: width + 32,
              height: height + 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD644).withValues(alpha: glowOpacity),
                    const Color(0xFFFFD644).withValues(alpha: 0.0),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
            SvgPicture.asset('assets/svgs/sun.svg', width: width, height: height),
          ],
        ),
      ),
    );
  }

  /// Standard drifting cloud with optional blur and horizontal flip.
  Widget _driftingCloud({
    required double top,
    required double width,
    required double height,
    required double phase,
    required double speed,
    required double yAmplitude,
    required double opacity,
    double scale = 1,
    double blurSigma = 0,
    bool flipX = false,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final loopDistance = screenWidth + width + 120;
    final progress = ((_controller.value * speed) + phase) % 1;
    final left = screenWidth + 40 - (progress * loopDistance);
    final dy =
        math.sin((_controller.value + phase) * math.pi * 2) * yAmplitude;

    Widget cloud = SvgPicture.asset('assets/svgs/cloud.svg');

    if (flipX) {
      cloud = Transform.flip(flipX: true, child: cloud);
    }

    if (blurSigma > 0) {
      cloud = ImageFiltered(
        imageFilter:
            ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: cloud,
      );
    }

    return Positioned(
      top: top + dy,
      left: left,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: cloud,
          ),
        ),
      ),
    );
  }

  /// Near-layer cloud that peeks from the right edge only.
  /// Oscillates horizontally so it slides in/out from the right margin.
  Widget _driftingCloudNear({
    required double top,
    required double width,
    required double height,
    required double phase,
    required double speed,
    required double yAmplitude,
    required double opacity,
    double scale = 1,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Horizontal drift: oscillates from mostly off-screen right to partially visible
    final driftX = math.sin((_controller.value * speed + phase) * math.pi * 2);
    // Range: right edge minus a portion of the cloud width
    // At driftX = -1 => more visible; driftX = 1 => less visible
    final rightOffset = screenWidth - width * 0.35 + driftX * (width * 0.25);
    final dy =
        math.sin((_controller.value + phase) * math.pi * 2) * yAmplitude;

    Widget cloud = Transform.flip(
      flipX: true,
      child: SvgPicture.asset('assets/svgs/cloud.svg'),
    );

    return Positioned(
      top: top + dy,
      left: rightOffset,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerRight,
            child: cloud,
          ),
        ),
      ),
    );
  }

  Widget _sparkle({
    double? top,
    double? right,
    double? left,
    double? bottom,
    required double size,
    required double phase,
  }) {
    final pulse =
        0.5 + (0.5 * math.sin((_controller.value * math.pi * 2 * 3) + phase));
    final opacity = 0.28 + (pulse * 0.7);
    final scale = 0.85 + (pulse * 0.3);

    return Positioned(
      top: top,
      right: right,
      left: left,
      bottom: bottom,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.auto_awesome,
              color: const Color(0xFFFFD644).withValues(alpha: 0.95),
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

class _TactileButton extends StatelessWidget {
  const _TactileButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.onPressed,
    this.trailing,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color borderColor;
  final VoidCallback onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: borderColor,
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 3),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.baloo2(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(color: foreground),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
