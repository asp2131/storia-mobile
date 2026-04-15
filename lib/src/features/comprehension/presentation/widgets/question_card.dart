import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/storia_colors.dart';
import '../../domain/book_question.dart';

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.onAnswerSelected,
  });

  final BookQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final void Function(String optionKey) onAnswerSelected;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${widget.questionNumber} of ${widget.totalQuestions}',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: StoriaColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: widget.questionNumber / widget.totalQuestions,
                  backgroundColor: StoriaColors.line,
                  valueColor: const AlwaysStoppedAnimation(StoriaColors.sage),
                  minHeight: 6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            widget.question.questionText,
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: StoriaColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...widget.question.options.map((option) {
            final isSelected = _selectedKey == option.optionKey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionButton(
                option: option,
                isSelected: isSelected,
                isDisabled: _selectedKey != null,
                onTap: () => _handleTap(option.optionKey),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _handleTap(String optionKey) {
    if (_selectedKey != null) return;

    setState(() => _selectedKey = optionKey);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        widget.onAnswerSelected(optionKey);
      }
    });
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final BookQuestionOption option;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? StoriaColors.sage.withValues(alpha: 0.2)
        : StoriaColors.paper;
    final borderColor = isSelected
        ? StoriaColors.sageDeep
        : StoriaColors.line;

    return Semantics(
      button: true,
      label: '${option.optionKey}: ${option.optionText}',
      selected: isSelected,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? StoriaColors.sageDeep
                        : StoriaColors.paperAlt,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option.optionKey,
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : StoriaColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option.optionText,
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: StoriaColors.ink,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: StoriaColors.sageDeep,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
