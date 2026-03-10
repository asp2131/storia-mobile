import 'dart:convert';

import 'package:flutter/foundation.dart';

enum ChildAgeRange { age4to6, age7to9, age10to12 }

extension ChildAgeRangeCopy on ChildAgeRange {
  String get label => switch (this) {
    ChildAgeRange.age4to6 => '4-6',
    ChildAgeRange.age7to9 => '7-9',
    ChildAgeRange.age10to12 => '10-12',
  };

  static ChildAgeRange? fromExactAge(int age) {
    if (age >= 4 && age <= 6) {
      return ChildAgeRange.age4to6;
    }
    if (age >= 7 && age <= 9) {
      return ChildAgeRange.age7to9;
    }
    if (age >= 10 && age <= 12) {
      return ChildAgeRange.age10to12;
    }
    return null;
  }
}

enum ParentGoal { improveReading, reduceScreenTime, lovesReading }

extension ParentGoalCopy on ParentGoal {
  String get label => switch (this) {
    ParentGoal.improveReading => "Improve my child's reading level",
    ParentGoal.reduceScreenTime => 'Pull them away from brain-rot apps',
    ParentGoal.lovesReading => 'They already love reading',
  };

  String get description => switch (this) {
    ParentGoal.improveReading =>
      'Build stronger reading habits and confidence over time.',
    ParentGoal.reduceScreenTime =>
      'Replace low-value screen time with calmer story moments.',
    ParentGoal.lovesReading =>
      'Keep a good thing going with more books they will ask for.',
  };
}

@immutable
class ReviewOnboardingProfile {
  const ReviewOnboardingProfile({
    required this.childNickname,
    required this.childAgeRange,
    required this.parentBirthYear,
    required this.parentGoal,
  });

  final String childNickname;
  final ChildAgeRange childAgeRange;
  final int parentBirthYear;
  final ParentGoal parentGoal;

  Map<String, dynamic> toMap() {
    return {
      'childNickname': childNickname,
      'childAgeRange': childAgeRange.name,
      'parentBirthYear': parentBirthYear,
      'parentGoal': parentGoal.name,
    };
  }

  String toJson() => jsonEncode(toMap());

  static ReviewOnboardingProfile? tryParse(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(source);
      if (map is! Map<String, dynamic>) {
        return null;
      }

      final goalName = map['parentGoal'];
      final goal = ParentGoal.values.where((item) => item.name == goalName);
      if (goal.isEmpty) {
        return null;
      }

      final ageRangeName = map['childAgeRange'];
      final ageRangeMatch = ChildAgeRange.values.where(
        (item) => item.name == ageRangeName,
      );
      ChildAgeRange? ageRange;
      if (ageRangeMatch.isNotEmpty) {
        ageRange = ageRangeMatch.first;
      }

      final nickname = map['childNickname'];
      final legacyChildAge = map['childAge'];
      final parentBirthYear = map['parentBirthYear'];

      if (ageRange == null && legacyChildAge is int) {
        ageRange = ChildAgeRangeCopy.fromExactAge(legacyChildAge);
      }

      if (nickname is! String || parentBirthYear is! int || ageRange == null) {
        return null;
      }

      return ReviewOnboardingProfile(
        childNickname: nickname,
        childAgeRange: ageRange,
        parentBirthYear: parentBirthYear,
        parentGoal: goal.first,
      );
    } catch (_) {
      return null;
    }
  }
}
