import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../routing/journey/journey_actions.dart';
import '../../onboarding/domain/review_onboarding_profile.dart';
import '../../onboarding/presentation/onboarding_flow_screen.dart';
import '../data/child_profile_providers.dart';
import '../domain/child_profile.dart';

/// Backend-account onboarding: saves the answers as a child profile.
class AddChildScreen extends ConsumerWidget {
  const AddChildScreen({super.key, this.isFirstReader = false});

  /// First-run has no reader chooser to go back to.
  final bool isFirstReader;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingFlowScreen(
    onExit: isFirstReader ? null : () => backOutOfJourneyStep(context),
    onFinish: (answers) async {
      await ref
          .read(childProfileActionsProvider)
          .createAndSelect(
            CreateChildProfileInput(
              displayName: answers.nickname,
              ageBand: answers.ageRange.label,
              readingLevel: answers.readingStyle?.name,
              isDefault: true,
              parentGoal: answers.goal.name,
              interests: [for (final i in answers.interests) i.name],
              readingTime: answers.readingTime?.name,
            ),
          );
      if (context.mounted) continueJourney(ref, context);
    },
  );
}
