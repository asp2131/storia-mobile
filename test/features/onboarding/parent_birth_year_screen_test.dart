import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/core/widgets/parental_gate.dart';
import 'package:loratone/src/features/onboarding/data/entry_flow_provider.dart';
import 'package:loratone/src/features/onboarding/domain/entry_flow_state.dart';
import 'package:loratone/src/features/onboarding/presentation/parent_birth_year_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<EntryFlowNotifier> mount(
    WidgetTester tester, {
    required bool passed,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final entry = EntryFlowNotifier(clock: () => DateTime.utc(2030, 1, 1));
    await entry.ready;
    if (passed) {
      entry.beginParentEntry(EntryAuthIntent.signUp);
      entry.authorizeParentAfterPassedGate();
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [entryFlowNotifierProvider.overrideWith((ref) => entry)],
        child: const MaterialApp(home: ParentBirthYearScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return entry;
  }

  testWidgets('a live passed entry gate skips the duplicate challenge', (
    tester,
  ) async {
    final entry = await mount(tester, passed: true);
    expect(find.byType(GateChallengeCard), findsNothing);
    expect(find.text('Please enter your year of birth.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2013');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid parent birth year.'), findsOneWidget);
    expect(entry.state.isAdultVerified, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a legacy direct year entry still requires the existing gate', (
    tester,
  ) async {
    final entry = await mount(tester, passed: false);
    expect(find.text('Parents only'), findsOneWidget);
    expect(find.text('Please enter your year of birth.'), findsNothing);
    final card = tester.widget<GateChallengeCard>(
      find.byType(GateChallengeCard),
    );
    final challenge = card.controller.value as GateChallenging;
    card.controller.submitAnswer(challenge.answer.toString());
    await tester.pumpAndSettle();
    expect(entry.state.isParentAuthorized, true);
    expect(find.byType(GateChallengeCard), findsNothing);
    expect(find.text('Please enter your year of birth.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'backgrounding relocks the year screen with a usable fresh challenge',
    (tester) async {
      final entry = await mount(tester, passed: false);
      final firstCard = tester.widget<GateChallengeCard>(
        find.byType(GateChallengeCard),
      );
      final firstChallenge = firstCard.controller.value as GateChallenging;
      firstCard.controller.submitAnswer(firstChallenge.answer.toString());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1980');
      entry.didChangeAppLifecycleState(AppLifecycleState.paused);
      entry.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final nextCard = tester.widget<GateChallengeCard>(
        find.byType(GateChallengeCard),
      );
      expect(nextCard.controller.value, isA<GateChallenging>());
      final nextChallenge = nextCard.controller.value as GateChallenging;
      nextCard.controller.submitAnswer(nextChallenge.answer.toString());
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(entry.state.isAdultVerified, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
