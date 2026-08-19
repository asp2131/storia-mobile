import 'package:flutter/material.dart';


import '../../../../core/theme/storia_colors.dart';
import '../../../../core/widgets/sketch_button.dart';
import '../../../../core/widgets/sketch_text_field.dart';

/// Code-entry fallback shown once a magic link has been emailed.
///
/// The same email carries a 6-digit code. Typing it finishes sign-in without
/// relying on the link opening this app — which is what fails when an inbox
/// scanner consumes the link first, or when the mail is read on another device.
class MagicCodeField extends StatelessWidget {
  const MagicCodeField({
    super.key,
    required this.controller,
    required this.isVerifying,
    required this.isBusy,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool isVerifying;
  final bool isBusy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          "Didn't get the link, or opened it somewhere else? Enter the 6-digit "
          'code from the same email.',
          style: textTheme.bodyMedium?.copyWith(
            color: StoriaColors.ink.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 12),
        SketchTextField(
          controller: controller,
          label: 'Code from email',
          hintText: '123456',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          leading: const Icon(Icons.pin_outlined),
          onSubmitted: (_) => onVerify(),
        ),
        const SizedBox(height: 12),
        SketchButton(
          label: 'Verify Code',
          tone: SketchButtonTone.secondary,
          isLoading: isVerifying,
          onPressed: isBusy ? null : onVerify,
        ),
      ],
    );
  }
}

/// Keeps only digits and caps length, so a code pasted with spaces or a stray
/// character still verifies.
String normalizeMagicCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length > 6 ? digits.substring(0, 6) : digits;
}
