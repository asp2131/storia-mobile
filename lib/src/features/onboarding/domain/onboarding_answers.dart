import 'package:flutter/material.dart';

import 'review_onboarding_profile.dart';

/// Enum names are the API values stored on `child_profile` (storia backend),
/// where interests are counted to decide which books to commission next.
enum ReadingStyle { independent, someHelp, listening }

extension ReadingStyleCopy on ReadingStyle {
  String get label => switch (this) {
    ReadingStyle.independent => 'On their own',
    ReadingStyle.someHelp => 'With some help',
    ReadingStyle.listening => 'Listening along',
  };

  IconData get icon => switch (this) {
    ReadingStyle.independent => Icons.auto_stories_rounded,
    ReadingStyle.someHelp => Icons.people_alt_rounded,
    ReadingStyle.listening => Icons.headphones_rounded,
  };
}

enum ReadingInterest {
  adventure,
  funny,
  mystery,
  magicFantasy,
  spaceScience,
  oceanWeather,
  sports,
  friendshipFeelings,
  mangaAnime,
  howThingsWork,
}

extension ReadingInterestCopy on ReadingInterest {
  String get label => switch (this) {
    ReadingInterest.adventure => 'Adventure',
    ReadingInterest.funny => 'Funny',
    ReadingInterest.mystery => 'Mystery',
    ReadingInterest.magicFantasy => 'Magic & fantasy',
    ReadingInterest.spaceScience => 'Space & science',
    ReadingInterest.oceanWeather => 'Ocean & weather',
    ReadingInterest.sports => 'Sports',
    ReadingInterest.friendshipFeelings => 'Friendship & feelings',
    ReadingInterest.mangaAnime => 'Manga & anime',
    ReadingInterest.howThingsWork => 'How things work',
  };

  IconData get icon => switch (this) {
    ReadingInterest.adventure => Icons.explore_rounded,
    ReadingInterest.funny => Icons.sentiment_very_satisfied_rounded,
    ReadingInterest.mystery => Icons.search_rounded,
    ReadingInterest.magicFantasy => Icons.auto_awesome_rounded,
    ReadingInterest.spaceScience => Icons.rocket_launch_rounded,
    ReadingInterest.oceanWeather => Icons.waves_rounded,
    ReadingInterest.sports => Icons.sports_soccer_rounded,
    ReadingInterest.friendshipFeelings => Icons.favorite_rounded,
    ReadingInterest.mangaAnime => Icons.menu_book_rounded,
    ReadingInterest.howThingsWork => Icons.build_rounded,
  };
}

enum ReadingTime { beforeSchool, afterSchool, bedtime, weekends }

extension ReadingTimeCopy on ReadingTime {
  String get label => switch (this) {
    ReadingTime.beforeSchool => 'Before school',
    ReadingTime.afterSchool => 'After school',
    ReadingTime.bedtime => 'At bedtime',
    ReadingTime.weekends => 'On weekends',
  };

  IconData get icon => switch (this) {
    ReadingTime.beforeSchool => Icons.wb_sunny_rounded,
    ReadingTime.afterSchool => Icons.backpack_rounded,
    ReadingTime.bedtime => Icons.bedtime_rounded,
    ReadingTime.weekends => Icons.weekend_rounded,
  };
}

/// Everything the onboarding flow collects. Only name, age and goal are
/// required; the rest may be skipped.
@immutable
class OnboardingAnswers {
  const OnboardingAnswers({
    required this.nickname,
    required this.ageRange,
    required this.goal,
    this.readingStyle,
    this.interests = const {},
    this.readingTime,
  });

  final String nickname;
  final ChildAgeRange ageRange;
  final ParentGoal goal;
  final ReadingStyle? readingStyle;
  final Set<ReadingInterest> interests;
  final ReadingTime? readingTime;
}
