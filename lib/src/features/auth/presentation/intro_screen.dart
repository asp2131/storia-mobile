import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  static const _heroSize = 256.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFAF3E8);
    const primary = Color(0xFF2C3358);
    const fg = Color(0xFF4A5568);
    const btn = Color(0xFFBBDF83);

    return Scaffold(
      backgroundColor: bg,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: bg)),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.45),
                        radius: 0.45,
                        colors: [Colors.white.withValues(alpha: 0.62), bg],
                      ),
                    ),
                  ),
                ),
              ),

              _floating(
                top: 62,
                right: -36,
                width: 128,
                height: 128,
                phase: 0.1,
                amplitude: 6,
                child: SvgPicture.asset('assets/svgs/sun.svg'),
              ),
              _floating(
                top: 120,
                left: -48,
                width: 160,
                height: 76,
                phase: 0.0,
                amplitude: 12,
                child: SvgPicture.asset('assets/svgs/book.svg'),
              ),
              _floating(
                top: 58,
                left: 64,
                width: 96,
                height: 44,
                phase: 0.4,
                amplitude: 10,
                child: Opacity(
                  opacity: 0.72,
                  child: Transform.scale(
                    scale: 0.75,
                    child: SvgPicture.asset('assets/svgs/book.svg'),
                  ),
                ),
              ),
              _floating(
                top: MediaQuery.sizeOf(context).height * 0.45,
                right: -40,
                width: 144,
                height: 66,
                phase: 0.75,
                amplitude: 14,
                child: Opacity(
                  opacity: 0.9,
                  child: SvgPicture.asset('assets/svgs/book.svg'),
                ),
              ),

              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 34),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: _heroSize,
                                height: _heroSize,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    math.sin(_controller.value * math.pi * 2) *
                                        -6,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: btn.withValues(alpha: 0.30),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: btn.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 40,
                                                spreadRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(32),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.asset(
                                              'assets/gifs/landing.gif',
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              top: 18,
                                              right: 18,
                                              child: Icon(
                                                Icons.auto_awesome,
                                                color: const Color(
                                                  0xFFFFD644,
                                                ).withValues(alpha: 0.82),
                                                size: 22,
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 22,
                                              left: 20,
                                              child: Icon(
                                                Icons.auto_awesome,
                                                color: const Color(
                                                  0xFFFFD644,
                                                ).withValues(alpha: 0.68),
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                          const SizedBox(height: 30),
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
            ],
          );
        },
      ),
    );
  }

  Widget _floating({
    required double? top,
    double? right,
    double? left,
    required double width,
    required double height,
    required double phase,
    required double amplitude,
    required Widget child,
  }) {
    final dy = math.sin((_controller.value + phase) * math.pi * 2) * amplitude;
    return Positioned(
      top: top != null ? top + dy : null,
      right: right,
      left: left,
      width: width,
      height: height,
      child: IgnorePointer(child: child),
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
