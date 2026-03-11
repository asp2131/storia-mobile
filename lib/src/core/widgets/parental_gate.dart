import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/storia_colors.dart';
import 'sketch_button.dart';
import 'sketch_card.dart';

/// Converts an integer 0-99 to its English word form.
///
/// Shared by [ParentalGate] and any screen that embeds an inline gate
/// challenge so the same word-form barrier is used consistently.
String numberToWords(int n) {
  const ones = [
    'zero', 'one', 'two', 'three', 'four', 'five',
    'six', 'seven', 'eight', 'nine', 'ten', 'eleven',
    'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
    'seventeen', 'eighteen', 'nineteen',
  ];
  const tens = [
    '', '', 'twenty', 'thirty', 'forty',
    'fifty', 'sixty', 'seventy', 'eighty', 'ninety',
  ];

  assert(n >= 0 && n < 100, 'numberToWords only handles 0-99');

  if (n < 20) return ones[n];
  if (n % 10 == 0) return tens[n ~/ 10];
  return '${tens[n ~/ 10]}-${ones[n % 10]}';
}

/// Generates a random addition challenge with two-digit operands and returns
/// `(a, b, answer, questionText)`.
({int a, int b, int answer, String question}) generateGateChallenge(
  Random random,
) {
  final a = 11 + random.nextInt(25);
  final b = 10 + random.nextInt(20);
  final answer = a + b;
  final question =
      'What is ${numberToWords(a)} plus ${numberToWords(b)}?';
  return (a: a, b: b, answer: answer, question: question);
}

/// A non-disableable parental gate that presents a random arithmetic challenge
/// written entirely in words (e.g. "What is twenty-three plus fourteen?") with
/// numeric-only open text entry. Designed for Apple Kids category compliance:
/// stacks reading comprehension and arithmetic -- trivial for adults, hard for
/// children ages 4-12.
class ParentalGate {
  ParentalGate._();

  /// Shows the parental gate challenge and returns `true` only when the
  /// correct answer is provided. Returns `false` if the user cancels.
  static Future<bool> verify(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ParentalGateSheet(),
    );
    return result ?? false;
  }
}

class _ParentalGateSheet extends StatefulWidget {
  const _ParentalGateSheet();

  @override
  State<_ParentalGateSheet> createState() => _ParentalGateSheetState();
}

class _ParentalGateSheetState extends State<_ParentalGateSheet> {
  static final _random = Random();

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late int _answer;
  late String _question;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    final challenge = generateGateChallenge(_random);
    _answer = challenge.answer;
    _question = challenge.question;
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final input = int.tryParse(_controller.text.trim());
    if (input == null) {
      setState(() => _errorMessage = 'Please enter a number.');
      return;
    }

    if (input == _answer) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _errorMessage = "That's not right. Try this one instead.";
      _regenerate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: SketchCard(
        color: const Color(0xFF4A5BE7),
        borderColor: const Color(0xFF3544C4),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF8F5ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                color: StoriaColors.ink,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Grown-ups only',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: StoriaColors.paper,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _question,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: StoriaColors.paper.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: StoriaColors.ink,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: '???',
                  hintStyle: textTheme.headlineSmall?.copyWith(
                    color: StoriaColors.ink.withValues(alpha: 0.3),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFFFD4D4),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: textTheme.bodyLarge?.copyWith(
                      color: StoriaColors.paper.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SketchButton(
                  label: 'Continue',
                  expand: false,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
