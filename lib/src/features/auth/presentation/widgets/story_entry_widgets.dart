import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/loratone_entry_colors.dart';
import '../../../../core/theme/storia_spacing.dart';
import '../../../../routing/journey/journey_actions.dart';

TextStyle storyEntryText({
  double size = 16,
  FontWeight weight = FontWeight.w600,
  Color color = LoratoneEntryColors.ink,
  double height = 1.35,
}) => GoogleFonts.nunito(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

class StoryEntryButton extends StatelessWidget {
  const StoryEntryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style:
          FilledButton.styleFrom(
            backgroundColor: LoratoneEntryColors.blue,
            foregroundColor: LoratoneEntryColors.surface,
            disabledBackgroundColor: LoratoneEntryColors.line,
            disabledForegroundColor: LoratoneEntryColors.inkMuted,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(
              horizontal: StoriaSpacing.xl,
              vertical: StoriaSpacing.lg,
            ),
            shape: const StadiumBorder(),
            textStyle: storyEntryText(size: 20, weight: FontWeight.w800),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return LoratoneEntryColors.line;
              }
              return states.contains(WidgetState.pressed)
                  ? LoratoneEntryColors.bluePressed
                  : LoratoneEntryColors.blue;
            }),
          ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class GrownUpsButton extends StatelessWidget {
  const GrownUpsButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed ?? () => enterAuth(context, AuthEntry.signUp),
    style: TextButton.styleFrom(
      foregroundColor: LoratoneEntryColors.ink,
      backgroundColor: LoratoneEntryColors.surface,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: StoriaSpacing.lg),
      shape: const StadiumBorder(
        side: BorderSide(color: LoratoneEntryColors.line),
      ),
      textStyle: storyEntryText(size: 14, weight: FontWeight.w800),
    ),
    child: const Text('Grown-ups'),
  );
}

class StoryEntryMessage extends StatelessWidget {
  const StoryEntryMessage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(StoriaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: storyEntryText()),
          const SizedBox(height: StoriaSpacing.lg),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
