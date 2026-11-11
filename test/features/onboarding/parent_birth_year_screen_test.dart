import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/core/widgets/parental_gate.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/features/onboarding/presentation/parent_birth_year_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_review_bypass_email': appReviewBypassEmail,
    });
    // Reset the singleton as well as the mocked preferences between tests.
    GateLockout.instance.reset();
  });

  tearDown(() {
    GateLockout.instance.reset();
  });

  Future<AppReviewFlowNotifier> mount(WidgetTester tester) async {
    final review = AppReviewFlowNotifier();
    await review.ready;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appReviewFlowNotifierProvider.overrideWith((ref) => review),
        ],
        child: const MaterialApp(home: ParentBirthYearScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return review;
  }

  Future<void> passGate(WidgetTester tester) async {
    final card = tester.widget<GateChallengeCard>(
      find.byType(GateChallengeCard),
    );
    final challenge = card.controller.value as GateChallenging;
    card.controller.submitAnswer(challenge.answer.toString());
    await tester.pumpAndSettle();
  }

  testWidgets('review birth year entry requires the parental gate', (
    tester,
  ) async {
    final review = await mount(tester);
    expect(find.text('Parents only'), findsOneWidget);
    expect(find.text('Please enter your year of birth.'), findsNothing);
    await passGate(tester);
    expect(find.byType(GateChallengeCard), findsNothing);
    expect(find.text('Please enter your year of birth.'), findsOneWidget);
    expect(review.state.hasParentBirthYear, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an incorrect gate answer cannot reveal birth year entry', (
    tester,
  ) async {
    final review = await mount(tester);
    final card = tester.widget<GateChallengeCard>(
      find.byType(GateChallengeCard),
    );
    final challenge = card.controller.value as GateChallenging;
    card.controller.submitAnswer('${challenge.answer + 1}');
    await tester.pumpAndSettle();
    expect(find.byType(GateChallengeCard), findsOneWidget);
    expect(find.text('Please enter your year of birth.'), findsNothing);
    expect(review.state.hasParentBirthYear, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('incomplete, implausible and underage years are not persisted', (
    tester,
  ) async {
    final review = await mount(tester);
    await passGate(tester);
    final invalidYears = {
      '12': 'Enter all 4 digits of your birth year.',
      '1929': 'Enter a valid parent birth year.',
      '${DateTime.now().year - 17}': 'Enter a valid parent birth year.',
    };
    for (final entry in invalidYears.entries) {
      await tester.enterText(find.byType(TextField), entry.key);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(review.state.hasParentBirthYear, false);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('app_review_parent_birth_year'), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
