import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'review activation copies the active year before publishing bypass',
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
      await notifier.enableReviewBypass(
        email: appReviewBypassEmail,
        verifiedParentBirthYear: 1985,
      );
      expect(publishedYears, [1985]);
      expect(notifier.state.hasCompletedOnboarding, false);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('app_review_parent_birth_year'), 1985);
      expect(preferences.getString('app_review_onboarding_profile'), isNull);
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

  test(
    'hydration retains completed legacy review setup after goal removal',
    () async {
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
    },
  );
}
