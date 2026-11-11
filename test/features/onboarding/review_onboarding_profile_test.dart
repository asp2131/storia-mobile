import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/onboarding/domain/review_onboarding_profile.dart';

void main() {
  const completedProfile = {
    'childNickname': 'Reader',
    'childAgeRange': 'age7to9',
    'parentBirthYear': 1980,
    'parentGoal': 'lovesReading',
  };
  const goals = {
    ParentGoal.improveReading: 'improveReading',
    ParentGoal.reduceScreenTime: 'reduceScreenTime',
    ParentGoal.lovesReading: 'lovesReading',
  };

  for (final entry in goals.entries) {
    test('completed profile preserves ${entry.value} when serialized', () {
      final profile = ReviewOnboardingProfile(
        childNickname: 'Reader',
        childAgeRange: ChildAgeRange.age7to9,
        parentBirthYear: 1980,
        parentGoal: entry.key,
      );

      expect(profile.toMap(), {...completedProfile, 'parentGoal': entry.value});
      final restored = ReviewOnboardingProfile.tryParse(profile.toJson());
      expect(restored?.childNickname, 'Reader');
      expect(restored?.childAgeRange, ChildAgeRange.age7to9);
      expect(restored?.parentBirthYear, 1980);
      expect(restored?.parentGoal, entry.key);
    });
  }

  for (final goal in [null, 'retiredGoal', 42]) {
    test('invalid parent goal $goal does not complete a profile', () {
      expect(
        ReviewOnboardingProfile.tryParse(
          jsonEncode({...completedProfile, 'parentGoal': goal}),
        ),
        isNull,
      );
    });
  }

  for (final field in completedProfile.keys) {
    test('a profile missing $field does not count as completed', () {
      final incompleteProfile = {...completedProfile}..remove(field);
      expect(
        ReviewOnboardingProfile.tryParse(jsonEncode(incompleteProfile)),
        isNull,
      );
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
    expect(profile?.toMap(), {
      'childNickname': 'Reader',
      'childAgeRange': 'age4to6',
      'parentBirthYear': 1980,
      'parentGoal': 'improveReading',
    });
  });

  test('incomplete or malformed saved profiles do not count as completed', () {
    for (final source in [
      null,
      '',
      '{',
      '{}',
      '[]',
      'null',
      '42',
      jsonEncode({'childNickname': 'Reader', 'parentBirthYear': 1980}),
    ]) {
      expect(ReviewOnboardingProfile.tryParse(source), isNull, reason: source);
    }
  });

  test('invalid field types and unsupported age ranges are rejected', () {
    for (final invalidFields in [
      {'childNickname': 42},
      {'childNickname': null},
      {'childAgeRange': 'retiredRange'},
      {'childAgeRange': 5},
      {'childAgeRange': null},
      {'parentBirthYear': '1980'},
      {'parentBirthYear': null},
      {'childAgeRange': null, 'childAge': '5'},
      {'childAgeRange': null, 'childAge': 3},
      {'childAgeRange': null, 'childAge': 13},
    ]) {
      final source = jsonEncode({...completedProfile, ...invalidFields});
      expect(ReviewOnboardingProfile.tryParse(source), isNull, reason: source);
    }
  });
}
