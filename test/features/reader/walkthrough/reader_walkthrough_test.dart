import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../lib/src/features/child/data/child_profile_providers.dart';
import '../../../../lib/src/features/reader/walkthrough/reader_walkthrough.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<Override> overridesFor({required String childId}) => [
    activeChildProfileIdProvider.overrideWith((ref) => childId),
  ];

  testWidgets('shows walkthrough when not seen, advances through all steps',
      (tester) async {
    final onCompleteCalled = ValueNotifier<int>(0);
    addTearDown(onCompleteCalled.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(childId: 'child-1'),
        child: MaterialApp(
          home: Scaffold(
            body: ReaderWalkthrough(
              onComplete: () => onCompleteCalled.value++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 — "Listen to the Story"
    expect(find.text('Listen to the Story'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2 — "Story Sounds"
    expect(find.text('Story Sounds'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 3 — "Hear a Word Again"
    expect(find.text('Hear a Word Again'), findsOneWidget);
    expect(find.text('3 / 4'), findsOneWidget);

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 4 — "Break It Down"
    expect(find.text('Break It Down'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);

    // Tap "Let's Read!" — last step calls onComplete
    await tester.tap(find.text('Let\u2019s Read!'));
    await tester.pumpAndSettle();

    expect(onCompleteCalled.value, 1);

    // Verify persisted as seen
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('reader_walkthrough_seen.child-1'),
      isTrue,
    );
  });

  testWidgets('skip marks seen and calls onComplete', (tester) async {
    final onCompleteCalled = ValueNotifier<int>(0);
    addTearDown(onCompleteCalled.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(childId: 'child-2'),
        child: MaterialApp(
          home: Scaffold(
            body: ReaderWalkthrough(
              onComplete: () => onCompleteCalled.value++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // On step 1, tap "Skip"
    expect(find.text('Listen to the Story'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(onCompleteCalled.value, 1);

    // Verify persisted as seen
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('reader_walkthrough_seen.child-2'),
      isTrue,
    );
  });

  test('walkthrough seen provider returns false when no prefs set',
      () async {
    final container = ProviderContainer(
      overrides: overridesFor(childId: 'child-3'),
    );
    addTearDown(container.dispose);

    // The provider loads async via SharedPreferences; pump the container.
    final sub = container.listen(
      readerWalkthroughSeenProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await Future.delayed(const Duration(milliseconds: 50));
    expect(sub.read().valueOrNull, isFalse);
  });

  test('walkthrough seen provider returns true when pref set', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_walkthrough_seen.child-3', true);

    final container = ProviderContainer(
      overrides: overridesFor(childId: 'child-3'),
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      readerWalkthroughSeenProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await Future.delayed(const Duration(milliseconds: 50));
    expect(sub.read().valueOrNull, isTrue);
  });
}
