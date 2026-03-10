import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/storia_colors.dart';
import 'sketch_button.dart';
import 'sketch_card.dart';

/// A non-disableable parental gate that presents a random multiplication
/// challenge each time it is shown. Designed for Apple Kids category
/// compliance: the product of two multi-digit numbers is trivial for adults
/// but difficult for children ages 4-12.
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

  late int _a;
  late int _b;
  late int _answer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateChallenge();
  }

  void _generateChallenge() {
    _a = 12 + _random.nextInt(19);
    _b = 7 + _random.nextInt(13);
    _answer = _a * _b;
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
      _generateChallenge();
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
            const SizedBox(height: 8),
            Text(
              'Please solve this to continue:',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: StoriaColors.paper.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$_a  ×  $_b  =  ?',
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                color: StoriaColors.paper,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
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
                  LengthLimitingTextInputFormatter(4),
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
