import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/features/onboarding/domain/review_onboarding_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'review activation resets old setup before persisting a newly verified year',
    () async {
      SharedPreferences.setMockInitialValues({
        'app_review_parent_birth_year': 1970,
        'app_review_onboarding_profile': '{}',
      });
      final notifier = AppReviewFlowNotifier();
      addTearDown(notifier.dispose);
      await notifier.ready;
      final publishedYears = <int?>[];
      notifier.addListener(() {
        if (notifier.state.hasReviewBypass) {
          publishedYears.add(notifier.state.parentBirthYear);
        }
      });
      await notifier.enableReviewBypass(email: appReviewBypassEmail);
      expect(publishedYears, [null]);
      await notifier.saveParentBirthYear(1985);
      expect(publishedYears, [null, 1985]);
      expect(notifier.state.hasCompletedOnboarding, false);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('app_review_parent_birth_year'), 1985);
      expect(preferences.getString('app_review_onboarding_profile'), isNull);
      final restored = AppReviewFlowNotifier();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.state.isReady, true);
      expect(restored.state.hasReviewBypass, true);
      expect(restored.state.parentBirthYear, 1985);
    },
  );

  test('direct reviewer activation cannot inherit an old year', () async {
    SharedPreferences.setMockInitialValues({
      'app_review_parent_birth_year': 1970,
    });
    final notifier = AppReviewFlowNotifier();
    addTearDown(notifier.dispose);
    await notifier.ready;
    await notifier.enableReviewBypass(email: appReviewBypassEmail);
    expect(notifier.state.hasParentBirthYear, false);
  });

  test('hydration retains a completed review setup', () async {
    SharedPreferences.setMockInitialValues({
      'app_review_bypass_email': appReviewBypassEmail,
      'app_review_parent_birth_year': 1980,
      'app_review_onboarding_profile': jsonEncode({
        'childNickname': 'Reader',
        'childAgeRange': 'age10to12',
        'parentBirthYear': 1980,
        'parentGoal': 'lovesReading',
      }),
    });
    final notifier = AppReviewFlowNotifier();
    addTearDown(notifier.dispose);
    await notifier.ready;
    expect(notifier.state.hasCompletedOnboarding, true);
    expect(notifier.state.onboardingProfile?.childNickname, 'Reader');
  });

  test('provider disposal while hydration is pending is safe', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    final notifier = container.read(appReviewFlowNotifierProvider);
    expect(notifier.state.isReady, false);
    container.dispose();
    await expectLater(notifier.ready, completes);
  });

  test(
    'a mutation waits for hydration before preserving review state',
    () async {
      SharedPreferences.setMockInitialValues({
        'app_review_bypass_email': appReviewBypassEmail,
      });
      final notifier = AppReviewFlowNotifier();
      addTearDown(notifier.dispose);
      await notifier.saveParentBirthYear(1985);
      expect(notifier.state.isReady, true);
      expect(notifier.state.hasReviewBypass, true);
      expect(notifier.state.parentBirthYear, 1985);
    },
  );

  final mutations = <String, Future<void> Function(AppReviewFlowNotifier)>{
    'activation': (notifier) =>
        notifier.enableReviewBypass(email: appReviewBypassEmail),
    'birth year': (notifier) => notifier.saveParentBirthYear(1985),
    'onboarding': (notifier) => notifier.completeOnboarding(
      const ReviewOnboardingProfile(
        childNickname: 'Reader',
        childAgeRange: ChildAgeRange.age7to9,
        parentBirthYear: 1985,
        parentGoal: ParentGoal.lovesReading,
      ),
    ),
    'reset': (notifier) => notifier.clearReviewFlow(),
  };
  for (final mutation in mutations.entries) {
    test('${mutation.key} does not notify after disposal', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AppReviewFlowNotifier();
      await notifier.ready;
      final pending = mutation.value(notifier);
      notifier.dispose();
      await expectLater(pending, completes);
    });
  }
}
