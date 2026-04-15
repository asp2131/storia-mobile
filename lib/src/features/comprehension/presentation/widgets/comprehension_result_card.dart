import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/storia_colors.dart';
import '../../domain/comprehension_result.dart';

class ComprehensionResultCard extends StatelessWidget {
  const ComprehensionResultCard({
    super.key,
    required this.result,
    required this.onBackToLibrary,
    required this.onReadAgain,
  });

  final ComprehensionResult result;
  final VoidCallback onBackToLibrary;
  final VoidCallback onReadAgain;

  @override
  Widget build(BuildContext context) {
    final allCorrect = result.correctCount == result.totalQuestions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allCorrect ? Icons.star_rounded : Icons.thumb_up_rounded,
            size: 72,
            color: allCorrect ? StoriaColors.mustard : StoriaColors.sage,
          ),
          const SizedBox(height: 24),
          Text(
            allCorrect ? 'Amazing!' : 'Nice work!',
            style: GoogleFonts.quicksand(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: StoriaColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You got ${result.correctCount} out of ${result.totalQuestions}!',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: StoriaColors.inkMuted,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onBackToLibrary,
              style: FilledButton.styleFrom(
                backgroundColor: StoriaColors.sage,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Back to library'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: onReadAgain,
              style: OutlinedButton.styleFrom(
                foregroundColor: StoriaColors.ink,
                side: const BorderSide(color: StoriaColors.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Read another book'),
            ),
          ),
        ],
      ),
    );
  }
}
