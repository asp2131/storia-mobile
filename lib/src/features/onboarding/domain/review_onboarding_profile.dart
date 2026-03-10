import 'dart:convert';

import 'package:flutter/foundation.dart';

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
    required this.childAge,
    required this.parentBirthYear,
    required this.parentGoal,
  });

  final String childNickname;
  final int childAge;
  final int parentBirthYear;
  final ParentGoal parentGoal;

  Map<String, dynamic> toMap() {
    return {
      'childNickname': childNickname,
      'childAge': childAge,
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

      final nickname = map['childNickname'];
      final childAge = map['childAge'];
      final parentBirthYear = map['parentBirthYear'];

      if (nickname is! String || childAge is! int || parentBirthYear is! int) {
        return null;
      }

      return ReviewOnboardingProfile(
        childNickname: nickname,
        childAge: childAge,
        parentBirthYear: parentBirthYear,
        parentGoal: goal.first,
      );
    } catch (_) {
      return null;
    }
  }
}
