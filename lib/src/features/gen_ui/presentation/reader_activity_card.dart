import 'package:cue/cue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_motion.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../data/models.dart';
import '../../reader/overlay/text_overlay_utils.dart';
import '../data/gen_ui_providers.dart';
import '../domain/gen_ui_card_schema.dart';
import '../domain/reader_activity_trigger.dart';

class ReaderActivityPromptOverlay extends ConsumerStatefulWidget {
  const ReaderActivityPromptOverlay({
    super.key,
    required this.bookId,
    required this.pageIndex,
    required this.isNarrationPlaying,
    required this.narrationPositionListenable,
    required this.narrationTimestamps,
    required this.onActivityShown,
    required this.onActivityDismissed,
  });

  final String bookId;
  final int pageIndex;
  final bool isNarrationPlaying;
  final ValueListenable<Duration> narrationPositionListenable;
  final List<WordTimestamp>? narrationTimestamps;
  final VoidCallback onActivityShown;
  final VoidCallback onActivityDismissed;

  @override
  ConsumerState<ReaderActivityPromptOverlay> createState() =>
      _ReaderActivityPromptOverlayState();
}

class _ReaderActivityPromptOverlayState
    extends ConsumerState<ReaderActivityPromptOverlay> {
  bool _shown = false;

  @override
  void didUpdateWidget(covariant ReaderActivityPromptOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pageChanged = oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.bookId != widget.bookId;
    if (pageChanged && _shown) {
      // Left the page while the takeover was still up: treat as dismissal so
      // narration resumes, and re-arm so the next page's activity can show.
      _shown = false;
      widget.onActivityDismissed();
    }
  }

  void _handleLive(bool live) {
    if (live && !_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onActivityShown();
      });
    }
  }

  void _dismiss(VoidCallback action) {
    if (_shown) {
      _shown = false;
      widget.onActivityDismissed();
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(
      readerGenUiCardProvider(
        ReaderGenUiPromptRequest(
          bookId: widget.bookId,
          pageIndex: widget.pageIndex,
        ),
      ),
    );

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.narrationPositionListenable,
      builder: (context, position, _) {
        final activeWordIndex = computeActiveWordIndex(
          widget.narrationTimestamps,
          position,
        );
        final live = isActivityLive(
          card: card,
          isNarrationPlaying: widget.isNarrationPlaying,
          activeNarratedWordIndex: activeWordIndex,
        );
        _handleLive(live);

        if (!live || card == null) return const SizedBox.shrink();

        return _ActivityTakeover(
          card: card,
          onChoiceSelected: (choice) {
            _dismiss(() {
              ref
                  .read(genUiActivityControllerProvider.notifier)
                  .answer(card, choice);
            });
          },
          onSkip: () {
            _dismiss(() {
              ref.read(genUiActivityControllerProvider.notifier).skip(card);
            });
          },
        );
      },
    );
  }
}

class _ActivityTakeover extends StatelessWidget {
  const _ActivityTakeover({
    required this.card,
    required this.onChoiceSelected,
    required this.onSkip,
  });

  final GenUiCardSchema card;
  final ValueChanged<GenUiChoiceSchema> onChoiceSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    // Reduced-motion: fade only, no slide (spec accessibility requirement).
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Positioned.fill(
      child: Stack(
        children: [
          // Dimmed scrim — tap to skip neutrally.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Skip activity',
              child: GestureDetector(
                onTap: onSkip,
                child: const ColoredBox(color: Color(0x8C080B11)),
              ),
            ),
          ),
          Center(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StoriaSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Cue.onMount(
                    debugLabel: 'story-spark-takeover',
                    motion: const CueMotion.curved(
                      StoriaMotion.medium,
                      curve: StoriaMotion.emphasized,
                    ),
                    acts: reduceMotion
                        ? const [.fadeIn()]
                        : const [.fadeIn(), .slideY(from: 0.12)],
                    child: ReaderActivityCard(
                      card: card,
                      onChoiceSelected: onChoiceSelected,
                      onSkip: onSkip,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderActivityCard extends StatelessWidget {
  const ReaderActivityCard({
    super.key,
    required this.card,
    required this.onChoiceSelected,
    required this.onSkip,
  });

  final GenUiCardSchema card;
  final ValueChanged<GenUiChoiceSchema> onChoiceSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    if (!card.validation.isValid) {
      return Semantics(
        label: 'Story activity unavailable',
        child: const SketchCard(
          child: Text('This story activity is unavailable right now.'),
        ),
      );
    }

    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Story activity. ${card.prompt}',
      child: SketchCard(
        color: StoriaColors.paperRaised,
        borderColor: StoriaColors.mustardDeep.withValues(alpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StoriaColors.mustard.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: StoriaColors.ink,
                  ),
                ),
                const SizedBox(width: StoriaSpacing.md),
                Expanded(
                  child: Text(
                    'Story Spark',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: StoriaColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (card.skippable)
                  Semantics(
                    button: true,
                    label: 'Skip story activity neutrally',
                    child: IconButton(
                      tooltip: 'Skip for now',
                      onPressed: onSkip,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: StoriaSpacing.md),
            Text(
              card.prompt,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: StoriaColors.ink,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            if (card.supportingText != null) ...[
              const SizedBox(height: StoriaSpacing.xs),
              Text(
                card.supportingText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StoriaColors.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: StoriaSpacing.md),
            _ActivityAnswers(
              choices: card.choices,
              onChoiceSelected: onChoiceSelected,
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks an answer layout by content: a 2-column emoji tile grid when every
/// choice has an emoji and all labels are short; otherwise full-width stacked
/// rows (handles reflection prompts and long true/false sentences).
class _ActivityAnswers extends StatelessWidget {
  const _ActivityAnswers({required this.choices, required this.onChoiceSelected});

  static const int _shortLabelMaxChars = 14;

  final List<GenUiChoiceSchema> choices;
  final ValueChanged<GenUiChoiceSchema> onChoiceSelected;

  bool get _useTiles =>
      choices.isNotEmpty &&
      choices.every(
        (c) => c.emoji != null && c.label.characters.length <= _shortLabelMaxChars,
      );

  @override
  Widget build(BuildContext context) {
    if (_useTiles) {
      final lastIndex = choices.length - 1;
      return Wrap(
        key: const ValueKey('activity-answers-tiles'),
        spacing: StoriaSpacing.sm,
        runSpacing: StoriaSpacing.sm,
        children: [
          for (var i = 0; i < choices.length; i++)
            _AnswerTile(
              choice: choices[i],
              // Odd count -> final tile spans the full row.
              fullWidth: choices.length.isOdd && i == lastIndex,
              onTap: () => onChoiceSelected(choices[i]),
            ),
        ],
      );
    }
    return Column(
      key: const ValueKey('activity-answers-stacked'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in choices) ...[
          _AnswerRow(choice: choice, onTap: () => onChoiceSelected(choice)),
          if (choice != choices.last) const SizedBox(height: StoriaSpacing.sm),
        ],
      ],
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.choice,
    required this.onTap,
    this.fullWidth = false,
  });

  final GenUiChoiceSchema choice;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width.clamp(0.0, 460.0)
        - StoriaSpacing.lg * 2;
    // Full-width tile (odd-count last item) spans the row; others are 2-col.
    final width = fullWidth ? available : (available - StoriaSpacing.sm) / 2;
    return Semantics(
      button: true,
      label: choice.accessibilityLabel,
      child: SizedBox(
        key: fullWidth ? const ValueKey('activity-tile-wide') : null,
        width: width,
        child: SketchButton(
          label: choice.label,
          leading: choice.emoji != null
              ? Text(choice.emoji!, style: const TextStyle(fontSize: 20))
              : null,
          tone: SketchButtonTone.secondary,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.choice, required this.onTap});

  final GenUiChoiceSchema choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: choice.accessibilityLabel,
      child: SketchButton(
        label: choice.label,
        leading: choice.emoji != null
            ? Text(choice.emoji!, style: const TextStyle(fontSize: 20))
            : null,
        tone: SketchButtonTone.secondary,
        onPressed: onTap,
      ),
    );
  }
}
