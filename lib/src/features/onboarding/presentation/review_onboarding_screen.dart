import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/analytics_repository.dart';
import '../../../data/providers.dart';
import '../../../routing/journey/journey_actions.dart';
import '../data/app_review_flow_providers.dart';
import '../domain/review_onboarding_profile.dart';
import 'onboarding_flow_screen.dart';

/// App Review bypass onboarding: no backend account, so answers stay local.
/// Only the fields [ReviewOnboardingProfile] knows about are kept.
class ReviewOnboardingScreen extends ConsumerWidget {
  const ReviewOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingFlowScreen(
    onExit: () => restartJourney(ref, context),
    onFinish: (answers) async {
      await ref
          .read(appReviewFlowNotifierProvider)
          .completeOnboarding(
            ReviewOnboardingProfile(
              childNickname: answers.nickname,
              childAgeRange: answers.ageRange,
              parentBirthYear: ref.read(appReviewFlowProvider).parentBirthYear!,
              parentGoal: answers.goal,
            ),
          );
      unawaited(
        ref
            .read(analyticsRepositoryProvider)
            .track(AnalyticsEventType.onboardingCompleted),
      );
      if (context.mounted) continueJourney(ref, context);
    },
  );
}
