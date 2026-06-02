import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/storia_colors.dart';
import '../../core/theme/storia_spacing.dart';
import '../../core/widgets/sketch_card.dart';

class AacMusicDemoScreen extends StatelessWidget {
  const AacMusicDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        backgroundColor: StoriaColors.paper,
        foregroundColor: StoriaColors.ink,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to library',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('AAC Music Demo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StoriaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SketchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Words as little melodies',
                      style: textTheme.headlineSmall?.copyWith(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: StoriaSpacing.sm),
                    Text(
                      'Prototype space for building “I want more” as a calm MIDI phrase, then resolving it with a soft bloom chord.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: StoriaColors.ink.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StoriaSpacing.lg),
              SketchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo sentence',
                      style: textTheme.titleMedium?.copyWith(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: StoriaSpacing.md),
                    Wrap(
                      spacing: StoriaSpacing.sm,
                      runSpacing: StoriaSpacing.sm,
                      children: const [
                        _WordChip(label: 'I'),
                        _WordChip(label: 'want'),
                        _WordChip(label: 'more'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: const Icon(Icons.music_note_rounded, size: 18),
      backgroundColor: StoriaColors.paperRaised,
      labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: StoriaColors.ink,
        fontWeight: FontWeight.w700,
      ),
      side: const BorderSide(color: StoriaColors.line, width: 1.2),
    );
  }
}
