import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../data/gen_ui_providers.dart';
import '../domain/gen_ui_card_schema.dart';

class ReaderActivityPromptOverlay extends ConsumerWidget {
  const ReaderActivityPromptOverlay({
    super.key,
    required this.bookId,
    required this.pageIndex,
    this.bottomInset = 0,
  });

  final String bookId;
  final int pageIndex;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(
      readerGenUiCardProvider(
        ReaderGenUiPromptRequest(bookId: bookId, pageIndex: pageIndex),
      ),
    );
    if (card == null) return const SizedBox.shrink();

    return Positioned(
      left: StoriaSpacing.lg,
      right: StoriaSpacing.lg,
      bottom: bottomInset + StoriaSpacing.lg,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ReaderActivityCard(
              card: card,
              onChoiceSelected: (choice) {
                ref.read(genUiActivityControllerProvider.notifier).answer(
                  card,
                  choice,
                );
              },
              onSkip: () {
                ref.read(genUiActivityControllerProvider.notifier).skip(card);
              },
            ),
          ),
        ),
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
        color: StoriaColors.paperRaised.withValues(alpha: 0.96),
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
            Wrap(
              spacing: StoriaSpacing.sm,
              runSpacing: StoriaSpacing.sm,
              children: [
                for (final choice in card.choices)
                  Semantics(
                    button: true,
                    label: choice.accessibilityLabel,
                    child: SketchButton(
                      label: choice.emoji == null
                          ? choice.label
                          : '${choice.emoji} ${choice.label}',
                      expand: false,
                      tone: SketchButtonTone.secondary,
                      onPressed: () => onChoiceSelected(choice),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
