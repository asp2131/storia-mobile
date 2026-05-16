import 'package:flutter/material.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_card.dart';
import '../domain/gen_ui_activity.dart';
import '../domain/gen_ui_card_schema.dart';

class ParentInsightCards extends StatelessWidget {
  const ParentInsightCards({super.key, required this.log, required this.profileName});

  final GenUiActivityLog log;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = log.events
        .where((event) => event.action == GenUiActivityAction.answered)
        .length;
    final skipped = log.events
        .where((event) => event.action == GenUiActivityAction.skipped)
        .length;
    final hasHarderFeelings = log.events.any(
      (event) => event.emotionTone == GenUiEmotionTone.harder,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        container: true,
        label: 'Parent insights from story activities',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$profileName’s reading reflections',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: StoriaColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Supportive, aggregate insights from story cards.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoriaColors.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: StoriaSpacing.md),
            SketchCard(
              padding: const EdgeInsets.all(14),
              color: StoriaColors.paperRaised,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: StoriaSpacing.md),
                  Expanded(
                    child: Text(
                      answered == 0
                          ? 'Story reflections will appear here after reading.'
                          : '$profileName shared $answered reflections during reading.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasHarderFeelings) ...[
              const SizedBox(height: StoriaSpacing.sm),
              SketchCard(
                padding: const EdgeInsets.all(14),
                color: StoriaColors.paperRaised,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💛', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: StoriaSpacing.md),
                    Expanded(
                      child: Text(
                        '$profileName noticed some bigger feelings in the story.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: StoriaColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (skipped > 0) ...[
              const SizedBox(height: StoriaSpacing.sm),
              Text(
                '$skipped prompt${skipped == 1 ? '' : 's'} skipped neutrally.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StoriaColors.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: StoriaSpacing.sm),
            Text(
              'No diagnosis or alarm: these cards are conversation starters, not labels.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: StoriaColors.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
