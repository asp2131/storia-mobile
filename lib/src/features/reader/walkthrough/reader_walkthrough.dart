import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_motion.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../child/data/child_profile_providers.dart';

// ---------------------------------------------------------------------------
// Persistence — "has this child seen the reader walkthrough?"
// ---------------------------------------------------------------------------

final readerWalkthroughSeenProvider =
    StateNotifierProvider<ReaderWalkthroughSeenNotifier, AsyncValue<bool>>((
      ref,
    ) {
      final childId = ref.watch(activeChildProfileIdProvider);
      return ReaderWalkthroughSeenNotifier(childId: childId)
        ..load();
    });

class ReaderWalkthroughSeenNotifier extends StateNotifier<AsyncValue<bool>> {
  ReaderWalkthroughSeenNotifier({required this.childId})
    : super(const AsyncValue.loading());

  final String? childId;

  static const _keyPrefix = 'reader_walkthrough_seen.';

  String get _key {
    final id = childId?.trim();
    if (id == null || id.isEmpty) return 'reader_walkthrough_seen';
    return '$_keyPrefix$id';
  }

  Future<void> load() async {
    if (childId == null || childId!.isEmpty) {
      state = const AsyncValue.data(false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = AsyncValue.data(prefs.getBool(_key) ?? false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    if (!mounted) return;
    state = const AsyncValue.data(true);
  }
}

// ---------------------------------------------------------------------------
// Walkthrough overlay
// ---------------------------------------------------------------------------

/// A 4-step first-run tutorial overlay for the reader screen.
///
/// Shows animated speech bubbles pointing at the key controls (narration,
/// soundscape, word tap, word long-press). Each step uses [Cue.onMount] with
/// a [ValueKey] so the bubble re-animates when the step changes.
///
/// Persisted per child profile via [readerWalkthroughSeenProvider].
class ReaderWalkthrough extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const ReaderWalkthrough({super.key, required this.onComplete});

  @override
  ConsumerState<ReaderWalkthrough> createState() => _ReaderWalkthroughState();
}

class _ReaderWalkthroughState extends ConsumerState<ReaderWalkthrough> {
  int _step = 0;

  static const _steps = <_WalkthroughStep>[
    _WalkthroughStep(
      title: 'Listen to the Story',
      message: 'Tap here to hear the words read out loud.',
      icon: Icons.play_arrow_rounded,
      color: Color(0xFFF59E0B), // amber — narration
      bubbleAlignment: Alignment(
        -0.65,
        0.15,
      ), // left of center, above the pill
      arrowAlignment: Alignment.bottomLeft,
    ),
    _WalkthroughStep(
      title: 'Story Sounds',
      message: 'Tap here for gentle background sounds.',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF14B8A6), // teal — soundscape
      bubbleAlignment: Alignment(0.65, 0.15), // right of center
      arrowAlignment: Alignment.bottomRight,
    ),
    _WalkthroughStep(
      title: 'Hear a Word Again',
      message: 'Tap any word to hear it one more time.',
      icon: Icons.touch_app_rounded,
      color: StoriaColors.ink,
      bubbleAlignment: Alignment(0.0, -0.25), // center-upper, text area
      arrowAlignment: Alignment.bottomCenter,
    ),
    _WalkthroughStep(
      title: 'Break It Down',
      message: 'Hold a word to hear it in small pieces.',
      icon: Icons.front_hand_rounded,
      color: StoriaColors.ink,
      bubbleAlignment: Alignment(0.0, -0.35), // center-upper, text area
      arrowAlignment: Alignment.bottomCenter,
    ),
  ];

  void _advance() async {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      await ref.read(readerWalkthroughSeenProvider.notifier).markSeen();
      widget.onComplete();
    }
  }

  void _skip() async {
    await ref.read(readerWalkthroughSeenProvider.notifier).markSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Stack(
      children: [
        // Dimmed backdrop — taps on it do nothing (force button interaction)
        Positioned.fill(
          child: ColoredBox(
            color: StoriaColors.readerBackground.withValues(alpha: 0.72),
          ),
        ),

        // Spotlight glow on the target area (simple circle, no clipping math)
        Align(
          alignment: step.bubbleAlignment,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step.color.withValues(alpha: 0.06),
              border: Border.all(
                color: step.color.withValues(alpha: 0.3),
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
          ),
        ),

        // Animated bubble — re-mounts on step change via ValueKey
        Align(
          alignment: step.bubbleAlignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Cue.onMount(
              key: ValueKey(_step),
              motion: const CueMotion.curved(
                StoriaMotion.medium,
                curve: StoriaMotion.emphasized,
              ),
              acts: const [
                .fadeIn(),
                .slideY(from: 0.3),
                .scale(from: 0.9),
              ],
              child: _WalkthroughBubble(
                step: step,
                stepNumber: _step + 1,
                totalSteps: _steps.length,
                isLast: isLast,
                onNext: _advance,
                onSkip: _skip,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step data
// ---------------------------------------------------------------------------

class _WalkthroughStep {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Alignment bubbleAlignment;
  final Alignment arrowAlignment;

  const _WalkthroughStep({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.bubbleAlignment,
    required this.arrowAlignment,
  });
}

// ---------------------------------------------------------------------------
// Bubble widget
// ---------------------------------------------------------------------------

class _WalkthroughBubble extends StatelessWidget {
  final _WalkthroughStep step;
  final int stepNumber;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _WalkthroughBubble({
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SketchCard(
      color: StoriaColors.paperRaised,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + step counter
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.color.withValues(alpha: 0.15),
                ),
                child: Icon(step.icon, color: step.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: GoogleFonts.baloo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: StoriaColors.ink,
                  ),
                ),
              ),
              Text(
                '$stepNumber / $totalSteps',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  color: StoriaColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Message
          Text(
            step.message,
            style: GoogleFonts.baloo2(
              fontSize: 15,
              color: StoriaColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: StoriaColors.inkMuted,
                ),
                child: Text(
                  'Skip',
                  style: GoogleFonts.baloo2(fontSize: 14),
                ),
              ),
              SketchButton(
                label: isLast ? 'Let\u2019s Read!' : 'Next',
                onPressed: onNext,
                expand: false,
                trailing: Icon(
                  isLast
                      ? Icons.auto_stories_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
