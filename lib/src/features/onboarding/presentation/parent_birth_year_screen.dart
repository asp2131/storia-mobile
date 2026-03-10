import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/sketch_icon_button.dart';
import '../../../core/widgets/watercolor_scaffold.dart';
import '../data/app_review_flow_providers.dart';

class ParentBirthYearScreen extends ConsumerStatefulWidget {
  const ParentBirthYearScreen({super.key});

  @override
  ConsumerState<ParentBirthYearScreen> createState() =>
      _ParentBirthYearScreenState();
}

class _ParentBirthYearScreenState extends ConsumerState<ParentBirthYearScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final digits = _controller.text;

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      body: WatercolorScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    SketchIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: _startOver,
                      tooltip: 'Go back',
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SketchCard(
                        color: const Color(0xFF4A5BE7),
                        borderColor: const Color(0xFF3544C4),
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _ParentsOnlyArt(),
                            const SizedBox(height: 18),
                            Text(
                              'Parents only',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                color: StoriaColors.paper,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Please enter your year of birth.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: StoriaColors.paper.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 44,
                              child: Stack(
                                children: [
                                  Align(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: List<Widget>.generate(4, (
                                        index,
                                      ) {
                                        final char = index < digits.length
                                            ? digits[index]
                                            : '';
                                        return _YearDigitSlot(value: char);
                                      }),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      maxLength: 4,
                                      style: const TextStyle(
                                        color: Colors.transparent,
                                        fontSize: 1,
                                      ),
                                      cursorColor: Colors.transparent,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        counterText: '',
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      onChanged: (_) => setState(() {
                                        _errorMessage = null;
                                      }),
                                      onSubmitted: (_) => _submit(),
                                    ),
                                  ),
                                ],
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
                            SketchButton(
                              label: 'Continue',
                              expand: false,
                              isLoading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final rawYear = _controller.text.trim();
    final year = int.tryParse(rawYear);
    final latestAllowedYear = DateTime.now().year - 18;

    if (rawYear.length != 4 || year == null) {
      setState(() {
        _errorMessage = 'Enter all 4 digits of your birth year.';
      });
      return;
    }

    if (year < 1930 || year > latestAllowedYear) {
      setState(() {
        _errorMessage = 'Enter a valid parent birth year.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(appReviewFlowNotifierProvider).saveParentBirthYear(year);
      if (!mounted) {
        return;
      }
      context.go('/onboarding');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Could not save your birth year right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _startOver() async {
    await ref.read(appReviewFlowNotifierProvider).clearReviewFlow();
    if (!mounted) {
      return;
    }
    context.go('/sign-in');
  }
}

class _ParentsOnlyArt extends StatelessWidget {
  const _ParentsOnlyArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            top: 12,
            child: Container(
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
          ),
          Positioned(
            left: 44,
            top: 0,
            child: Container(
              width: 24,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFBFF4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2B9BB2), width: 1.4),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF2B9BB2),
                size: 14,
              ),
            ),
          ),
          Positioned(
            right: 18,
            top: 6,
            child: Container(
              width: 56,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B57),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 2,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7D5F4E),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 18),
                Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7D5F4E),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 12,
            child: Container(
              width: 64,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF65A6FF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearDigitSlot extends StatelessWidget {
  const _YearDigitSlot({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 44,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Center(
              child: Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  color: StoriaColors.paper,
                ),
              ),
            ),
          ),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: StoriaColors.paper.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}
