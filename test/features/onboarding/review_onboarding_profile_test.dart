import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/onboarding/domain/review_onboarding_profile.dart';

void main() {
  for (final goal in [null, 'lovesReading', 'retiredGoal', 42]) {
    test('legacy goal $goal does not discard a completed review profile', () {
      final profile = ReviewOnboardingProfile.tryParse(
        jsonEncode({
          'childNickname': 'Reader',
          'childAgeRange': 'age7to9',
          'parentBirthYear': 1980,
          if (goal != null) 'parentGoal': goal,
        }),
      );
      expect(profile?.childNickname, 'Reader');
      expect(profile?.childAgeRange, ChildAgeRange.age7to9);
      expect(profile?.parentBirthYear, 1980);
      expect(profile?.toMap().containsKey('parentGoal'), false);
    });
  }

  test('legacy exact child age still restores its supported age range', () {
    final profile = ReviewOnboardingProfile.tryParse(
      jsonEncode({
        'childNickname': 'Reader',
        'childAge': 5,
        'parentBirthYear': 1980,
        'parentGoal': 'improveReading',
      }),
    );
    expect(profile?.childAgeRange, ChildAgeRange.age4to6);
  });

  test('incomplete or malformed saved profiles do not count as completed', () {
    for (final source in [
      '{',
      '{}',
      jsonEncode({'childNickname': 'Reader', 'parentBirthYear': 1980}),
    ]) {
      expect(ReviewOnboardingProfile.tryParse(source), isNull);
    }
  });
}
