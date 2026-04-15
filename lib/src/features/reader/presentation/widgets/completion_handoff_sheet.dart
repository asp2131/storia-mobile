import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/storia_colors.dart';

class CompletionHandoffSheet extends StatelessWidget {
  const CompletionHandoffSheet({
    super.key,
    required this.bookTitle,
    required this.hasQuestions,
    required this.onPlayAgain,
    required this.onReadAgain,
    required this.onQuickQuestions,
    required this.onBackToLibrary,
  });

  final String bookTitle;
  final bool hasQuestions;
  final VoidCallback onPlayAgain;
  final VoidCallback onReadAgain;
  final VoidCallback onQuickQuestions;
  final VoidCallback onBackToLibrary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD7D7D2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Great job finishing the story!',
              style: GoogleFonts.quicksand(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: StoriaColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              bookTitle,
              style: GoogleFonts.quicksand(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: StoriaColors.inkMuted,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            if (hasQuestions) ...[
              _HandoffAction(
                icon: Icons.quiz_rounded,
                label: 'Quick questions',
                subtitle: 'Answer a few fun questions',
                color: StoriaColors.sage,
                onTap: onQuickQuestions,
              ),
              const SizedBox(height: 12),
            ],
            _HandoffAction(
              icon: Icons.play_arrow_rounded,
              label: 'Play again',
              subtitle: 'Listen to the story again',
              color: StoriaColors.mustard,
              onTap: onPlayAgain,
            ),
            const SizedBox(height: 12),
            _HandoffAction(
              icon: Icons.menu_book_rounded,
              label: 'Read again',
              subtitle: 'Read it one more time',
              color: StoriaColors.dustyPink,
              onTap: onReadAgain,
            ),
            const SizedBox(height: 12),
            _HandoffAction(
              icon: Icons.explore_rounded,
              label: 'Back to library',
              subtitle: 'Find another book',
              color: StoriaColors.inkMuted,
              onTap: onBackToLibrary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoffAction extends StatelessWidget {
  const _HandoffAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: true,
          label: label,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.quicksand(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: StoriaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.quicksand(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: StoriaColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: StoriaColors.inkMuted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
