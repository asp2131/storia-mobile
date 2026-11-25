import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/reader/page_like_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('likes accumulate per page and survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    const key = (childId: 'child-1', bookId: '77');

    final first = ProviderContainer();
    final notifier = first.read(pageLikesProvider(key).notifier);
    await notifier.like('p1');
    await notifier.like('p1');
    await notifier.like('p2');
    expect(first.read(pageLikesProvider(key)), {'p1': 2, 'p2': 1});
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // A tap that lands before stored counts load is added, not overwritten.
    await second.read(pageLikesProvider(key).notifier).like('p1');
    expect(second.read(pageLikesProvider(key)), {'p1': 3, 'p2': 1});

    // Another child starts from zero.
    const other = (childId: 'child-2', bookId: '77');
    await second.read(pageLikesProvider(other).notifier).like('p1');
    expect(second.read(pageLikesProvider(other)), {'p1': 1});
  });

  testWidgets('tapping the heart repeatedly counts every tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Stack(
            children: [
              PageLikeButton(
                childId: null,
                bookId: '77',
                pageId: 'p1',
                pageNumber: 1,
                trackAnalytics: false,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Love this page'));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    // Floating hearts clean themselves up; only the filled button remains.
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('a guest can like a page once, reported with no identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final reports = <Map<String, Object>>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestLikeReporterProvider.overrideWithValue(({
            required bookId,
            required pageNumber,
            required likes,
          }) async {
            reports.add({
              'bookId': bookId,
              'pageNumber': pageNumber,
              'likes': likes,
            });
          }),
        ],
        child: const MaterialApp(
          home: Stack(
            children: [
              PageLikeButton(
                childId: null,
                bookId: '77',
                pageId: 'p4',
                pageNumber: 4,
                trackAnalytics: false,
                countGuestLikes: true,
                repeatable: false,
              ),
            ],
          ),
        ),
      ),
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Love this page'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(reports, isEmpty);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(reports, [
      {'bookId': '77', 'pageNumber': 4, 'likes': 1},
    ]);
    // Filled heart, no counter, and later taps add nothing.
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('1'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Love this page'));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(reports, hasLength(1));
  });
}
