import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/widgets/sketch_border.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_card.dart';
import '../../../core/widgets/sketch_text_field.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../auth/presentation/widgets/auth_screen_shell.dart';
import '../data/app_review_flow_providers.dart';
import '../domain/review_onboarding_profile.dart';

class ReviewOnboardingScreen extends ConsumerStatefulWidget {
  const ReviewOnboardingScreen({super.key});

  @override
  ConsumerState<ReviewOnboardingScreen> createState() =>
      _ReviewOnboardingScreenState();
}

class _ReviewOnboardingScreenState
    extends ConsumerState<ReviewOnboardingScreen> {
  final _nicknameController = TextEditingController();
  ChildAgeRange? _selectedAgeRange;
  ParentGoal? _selectedGoal;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<ChildAgeRange> get _ageOptions => ChildAgeRange.values;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appReviewFlowProvider);

    return AuthScreenShell(
      title: 'A Quick Family Setup',
      subtitle:
          'Now add the child details and what the parent hopes Loratone will help with.',
      onBack: _startOver,
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SketchTextField(
                controller: _nicknameController,
                label: "Child's Nickname",
                hintText: 'Milo',
                textInputAction: TextInputAction.next,
                leading: const Icon(Icons.face_rounded),
              ),
              const SizedBox(height: 20),
              Text(
                "Child's Age Range",
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: StoriaColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final ageRange in _ageOptions)
                    ChoiceChip(
                      label: Text(ageRange.label),
                      selected: _selectedAgeRange == ageRange,
                      labelStyle: textTheme.bodyMedium?.copyWith(
                        color: _selectedAgeRange == ageRange
                            ? StoriaColors.paper
                            : StoriaColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: StoriaColors.ink,
                      backgroundColor: StoriaColors.paperAlt,
                      side: BorderSide(
                        color: _selectedAgeRange == ageRange
                            ? StoriaColors.ink
                            : StoriaColors.lineStrong,
                      ),
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _selectedAgeRange = ageRange),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'What are they hoping to get from Loratone?',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: StoriaColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              for (final goal in ParentGoal.values) ...[
                _GoalCard(
                  goal: goal,
                  isSelected: _selectedGoal == goal,
                  onTap: () => setState(() => _selectedGoal = goal),
                ),
                const SizedBox(height: 10),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: StoriaColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SketchButton(
                label: 'Continue to Library',
                trailing: const Icon(Icons.auto_stories_rounded, size: 18),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    final ageRange = _selectedAgeRange;
    final birthYear = ref.read(appReviewFlowProvider).parentBirthYear;
    final goal = _selectedGoal;

    if (nickname.isEmpty ||
        ageRange == null ||
        birthYear == null ||
        goal == null) {
      setState(() {
        _errorMessage = 'Complete every field before continuing.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(appReviewFlowNotifierProvider)
          .completeOnboarding(
            ReviewOnboardingProfile(
              childNickname: nickname,
              childAgeRange: ageRange,
              parentBirthYear: birthYear,
              parentGoal: goal,
            ),
          );

      if (!mounted) {
        return;
      }
      continueJourney(ref, context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Could not save this setup right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _startOver() => restartJourney(ref, context);
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.isSelected,
    required this.onTap,
  });

  final ParentGoal goal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: sketchBorderRadius(0.82).resolve(TextDirection.ltr),
        child: SketchCard(
          color: isSelected ? StoriaColors.paper : StoriaColors.paperRaised,
          borderColor: isSelected
              ? StoriaColors.dustyPinkStrong
              : StoriaColors.line,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? StoriaColors.dustyPinkStrong
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? StoriaColors.dustyPinkStrong
                        : StoriaColors.lineStrong,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal.description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: StoriaColors.ink.withValues(alpha: 0.72),
                      ),
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
