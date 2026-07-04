import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../routing/journey/journey_policy.dart';
import 'book_celebration_summary.dart';

/// Full-screen book-finished celebration. Reached by swiping up past the last
/// page of a book (see ReaderScreen). Session-scoped v1: hero Lottie, "You
/// finished!", the book, and two stat tiles (pages + minutes). Single action:
/// back to the library.
class BookCelebrationScreen extends StatefulWidget {
  const BookCelebrationScreen({super.key, required this.summary});

  final BookCelebrationSummary summary;

  @override
  State<BookCelebrationScreen> createState() => _BookCelebrationScreenState();
}

class _BookCelebrationScreenState extends State<BookCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _sunburst;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _sunburst = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) return;
      _sunburst.repeat();
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _sunburst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    final summary = widget.summary;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: Stack(
        children: [
          // Sunburst behind everything.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sunburst,
                builder: (context, _) => CustomPaint(
                  painter: _SunburstPainter(
                    rotation: reduce ? 0 : _sunburst.value * 2 * math.pi,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: StoriaSpacing.xl),
              child: Column(
                children: [
                  const SizedBox(height: StoriaSpacing.xl),
                  SizedBox(
                    height: 200,
                    child: Lottie.asset(
                      'assets/lottie/book_celebration.json',
                      repeat: !reduce,
                      animate: !reduce,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: StoriaSpacing.sm),
                  _animate(
                    reduce,
                    Text(
                      'You finished!',
                      textAlign: TextAlign.center,
                      style: tt.displayMedium?.copyWith(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    (w) => w
                        .animate()
                        .fadeIn(delay: 260.ms, duration: 300.ms)
                        .scaleXY(
                          begin: 0.6,
                          end: 1,
                          delay: 260.ms,
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ),
                  const SizedBox(height: StoriaSpacing.xs),
                  _animate(
                    reduce,
                    _TitleRow(summary: summary),
                    (w) => w.animate().fadeIn(delay: 420.ms, duration: 400.ms),
                  ),
                  const Spacer(),
                  _StatTiles(summary: summary, reduce: reduce),
                  const SizedBox(height: StoriaSpacing.xl),
                  _animate(
                    reduce,
                    SketchButton(
                      label: 'Back to Library',
                      leading: const Icon(Icons.home_rounded, size: 22),
                      onPressed: () => context.go(JourneyRoutes.library),
                    ),
                    (w) => w
                        .animate()
                        .fadeIn(delay: 860.ms, duration: 400.ms)
                        .slideY(begin: 0.4, end: 0, delay: 860.ms),
                  ),
                  const SizedBox(height: StoriaSpacing.lg),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              gravity: 0.12,
              emissionFrequency: 0.05,
              colors: const [
                StoriaColors.mustard,
                StoriaColors.sage,
                StoriaColors.dustyPink,
                StoriaColors.ink,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Applies [effects] unless the platform requests reduced motion, in which
  /// case the settled widget is returned unanimated.
  Widget _animate(bool reduce, Widget child, Widget Function(Widget) effects) {
    return reduce ? child : effects(child);
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.summary});

  final BookCelebrationSummary summary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoverChip(coverUrl: summary.coverUrl),
        const SizedBox(width: StoriaSpacing.sm),
        Flexible(
          child: Text(
            summary.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.titleMedium?.copyWith(color: StoriaColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _CoverChip extends StatelessWidget {
  const _CoverChip({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: StoriaColors.ink, width: 1.5);
    final radius = BorderRadius.circular(4);
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return Container(
        width: 22,
        height: 28,
        decoration: BoxDecoration(border: border, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: coverUrl!,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              const ColoredBox(color: StoriaColors.sage),
        ),
      );
    }
    // Stylized placeholder cover.
    return Container(
      width: 22,
      height: 28,
      decoration: BoxDecoration(
        border: border,
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [StoriaColors.sage, StoriaColors.sageDeep],
        ),
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.summary, required this.reduce});

  final BookCelebrationSummary summary;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    // v1: pages + minutes only (Story Sparks tile intentionally omitted).
    final tiles = <Widget>[
      _StatTile(
        icon: Icons.auto_stories_rounded,
        value: '${summary.pagesRead}',
        label: 'pages',
        rotation: -0.028,
      ),
      _StatTile(
        icon: Icons.schedule_rounded,
        value: '${summary.minutesRead}',
        label: 'min read',
        rotation: 0.018,
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: StoriaSpacing.md),
          reduce
              ? tiles[i]
              : tiles[i]
                    .animate()
                    .fadeIn(delay: (500 + i * 100).ms, duration: 350.ms)
                    .scaleXY(
                      begin: 0.6,
                      end: 1,
                      delay: (500 + i * 100).ms,
                      duration: 420.ms,
                      curve: Curves.easeOutBack,
                    ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.rotation,
  });

  final IconData icon;
  final String value;
  final String label;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(
          vertical: StoriaSpacing.md,
          horizontal: StoriaSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: StoriaColors.paperRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StoriaColors.lineStrong, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(44, 51, 88, 0.10),
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: StoriaColors.ink),
            const SizedBox(height: StoriaSpacing.xs),
            Text(
              value,
              style: tt.displaySmall?.copyWith(
                color: StoriaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: tt.labelLarge?.copyWith(color: StoriaColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter({required this.rotation});

  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.30);
    final radius = size.longestSide;

    // Warm glow behind the hero.
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [
              Color.fromRGBO(255, 214, 68, 0.30),
              Color.fromRGBO(255, 214, 68, 0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.42),
          );
    canvas.drawCircle(center, size.width * 0.42, glow);

    // Radiating wedges.
    final ray = Paint()..color = const Color.fromRGBO(255, 214, 68, 0.14);
    const rays = 24;
    const step = 2 * math.pi / rays;
    const half = step * 0.28;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    for (var i = 0; i < rays; i++) {
      final a = i * step;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - half) * radius, math.sin(a - half) * radius)
        ..lineTo(math.cos(a + half) * radius, math.sin(a + half) * radius)
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunburstPainter old) => old.rotation != rotation;
}
