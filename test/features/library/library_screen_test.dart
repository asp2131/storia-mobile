import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/library/library_providers.dart';
import 'package:loratone/src/features/library/library_screen.dart';
import 'package:loratone/src/features/reader/data/reading_checkpoint_provider.dart';
import 'package:loratone/src/features/reader/domain/reading_checkpoint.dart';

Book _book(String id, String title, {int pages = 10}) =>
    Book(id: id, title: title, pageCount: pages, pages: const []);

ReadingCheckpoint _checkpoint(
  String bookId, {
  int pageIndex = 2,
  bool completed = false,
}) => ReadingCheckpoint(
  bookId: bookId,
  contentRevision: 'r1',
  pageId: 'p$pageIndex',
  pageIndex: pageIndex,
  completed: completed,
  updatedAt: DateTime(2026, 10, 29),
);

final _books = [
  _book('a', 'Oldest Owl'),
  _book('b', 'Middle Moon'),
  _book('c', 'Newest Nap'),
];

Future<List<String>> _pump(
  WidgetTester tester, {
  bool failLoad = false,
  ReadingCheckpoint? continuation,
  List<ReadingCheckpoint> shelf = const [],
  DateTime? now,
  bool dated = true,
}) async {
  final clock = now ?? DateTime(2026, 11, 5, 21, 30);
  final launch = dated ? DateTime(2026, 11, 8) : null;
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final opened = <String>[];
  final router = GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
      GoRoute(
        path: '/reader/:bookId',
        builder: (_, state) {
          opened.add(state.pathParameters['bookId']!);
          return const Scaffold(body: Text('Reader'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookLibraryProvider.overrideWith(
          (ref) async => failLoad ? throw Exception('offline') : _books,
        ),
        readingContinuationProvider.overrideWith((ref) async => continuation),
        libraryShelfProvider.overrideWith((ref) async => shelf),
        libraryClockProvider.overrideWithValue(() => clock),
        comicsLaunchProvider.overrideWithValue(launch),
        activeChildProfileProvider.overrideWithValue(
          const AsyncData(
            ChildProfile(
              id: 'kid',
              displayName: 'Jo',
              ageBand: '6-8',
              isDefault: true,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // The hero equalizer loops forever, so pump frames instead of settling.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return opened;
}

void main() {
  testWidgets('greets the child and features the newest book', (tester) async {
    await _pump(tester);

    expect(find.text('Hi, Jo!'), findsOneWidget);
    expect(find.text('Start listening'), findsOneWidget);
    expect(find.text('New books'), findsOneWidget);
    expect(find.text('All books'), findsOneWidget);
    expect(find.text('Comics are coming'), findsOneWidget);
    expect(find.text('Newest Nap'), findsWidgets);
  });

  testWidgets('hero resumes an unfinished book at its page', (tester) async {
    final opened = await _pump(tester, continuation: _checkpoint('b'));

    expect(find.text('Keep listening'), findsOneWidget);
    expect(find.text('Page 3 of 10'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Keep listening: Middle Moon'));
    await tester.pump();
    await tester.pump();
    expect(opened, ['b']);
  });

  testWidgets('search narrows the books', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Search books'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'owl');
    await tester.pump();

    expect(find.text('Oldest Owl'), findsWidgets);
    expect(find.text('Middle Moon'), findsNothing);
    expect(find.text('New books'), findsNothing);
  });

  testWidgets('my shelf lists started books with progress', (tester) async {
    await _pump(
      tester,
      shelf: [
        _checkpoint('a', pageIndex: 4),
        _checkpoint('c', completed: true),
      ],
    );

    await tester.tap(find.text('My shelf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Page 5 of 10'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Middle Moon'), findsNothing);
  });

  testWidgets('empty shelf explains how to fill it', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('My shelf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Your shelf is empty'), findsOneWidget);
  });

  testWidgets('comics banner counts down to Nov 8', (tester) async {
    await _pump(tester);

    expect(find.text('Coming Nov 8'), findsOneWidget);
    expect(
      find.bySemanticsLabel('2 days, 2 hours, 30 minutes to go'),
      findsOneWidget,
    );
    expect(find.text('Learn more'), findsOneWidget);
  });

  testWidgets('comics banner drops the countdown after launch', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 8, 9));

    expect(find.text('Out now'), findsOneWidget);
    expect(find.text('Comics are here'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.text('Learn more'), findsOneWidget);
  });

  testWidgets('comics banner skips the countdown without a date', (
    tester,
  ) async {
    await _pump(tester, dated: false);

    expect(find.text('In the works'), findsOneWidget);
    expect(find.text('Comics are coming'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.text('Learn more'), findsOneWidget);
  });

  testWidgets('load failure offers a retry', (tester) async {
    await _pump(tester, failLoad: true);

    expect(find.text('Our books could not load'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
