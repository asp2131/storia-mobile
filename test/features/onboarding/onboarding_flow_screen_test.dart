import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/onboarding/domain/onboarding_answers.dart';
import 'package:loratone/src/features/onboarding/domain/review_onboarding_profile.dart';
import 'package:loratone/src/features/onboarding/presentation/onboarding_flow_screen.dart';

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('walks all six steps and hands back the answers', (tester) async {
    OnboardingAnswers? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlowScreen(
          onFinish: (answers) async => saved = answers,
        ),
      ),
    );

    // Name is required before Continue does anything.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text("What's your reader's name?"), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Mo');
    await tester.pump();
    await tapText(tester, 'Continue');

    // Single-choice steps advance on tap; a double tap must not skip a step.
    await tester.tap(find.text('7-9'));
    await tester.tap(find.text('7-9'));
    await tester.pumpAndSettle();
    expect(find.text('How does Mo read?'), findsOneWidget);
    await tapText(tester, 'Skip for now');

    await tapText(tester, ParentGoal.reduceScreenTime.label);
    expect(find.text(ParentGoal.reduceScreenTime.description), findsOneWidget);
    await tapText(tester, 'Continue');

    await tapText(tester, 'Mystery');
    await tapText(tester, 'Manga & anime');
    await tapText(tester, 'Continue');

    await tapText(tester, 'At bedtime');
    await tapText(tester, 'Start reading');

    expect(saved!.nickname, 'Mo');
    expect(saved!.ageRange, ChildAgeRange.age7to9);
    expect(saved!.readingStyle, isNull);
    expect(saved!.goal, ParentGoal.reduceScreenTime);
    expect(saved!.interests, {
      ReadingInterest.mystery,
      ReadingInterest.mangaAnime,
    });
    expect(saved!.readingTime, ReadingTime.bedtime);
  });

  testWidgets('a failed save keeps the parent on the last step', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlowScreen(
          onFinish: (_) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Mo');
    await tester.pump();
    await tapText(tester, 'Continue');
    await tapText(tester, '4-6');
    await tapText(tester, 'On their own');
    await tapText(tester, ParentGoal.improveReading.label);
    await tapText(tester, 'Continue');
    await tapText(tester, 'Skip for now');
    await tapText(tester, 'Start reading');

    expect(find.text('Could not save right now. Try again.'), findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
  });

  testWidgets('first run hides Back on the first step', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingFlowScreen(onFinish: (_) async {})),
    );
    expect(find.byTooltip('Back'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Mo');
    await tester.pump();
    await tapText(tester, 'Continue');
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
