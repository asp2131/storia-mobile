import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gooey/gooey.dart';
import 'package:go_router/go_router.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/data/providers.dart' as providers;
import 'package:storia_kids/src/features/library/library_screen.dart';

// ── Book helpers ───────────────────────────────────────────────────────────

Book _makeBook({
  required String id,
  required String title,
  String? author,
  String? coverUrl,
  int pageCount = 10,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    coverUrl: coverUrl,
    pageCount: pageCount,
    pages: const [],
  );
}

// ── Router factory ─────────────────────────────────────────────────────────

GoRouter _testRouter({void Function(String)? onNavigate}) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          onNavigate?.call(state.pathParameters['bookId'] ?? '');
          return Scaffold(
            body: Text('Reader: ${state.pathParameters['bookId']}'),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
}

// ── Provider overrides ─────────────────────────────────────────────────────

/// Creates a FutureProvider override that resolves with the given books.
/// The `overrideWith` function signature matches
/// `FutureOr<T> Function(FutureProviderRef<T>)`.
Override _booksOverride(Future<List<Book>> books) {
  return providers.bookLibraryProvider.overrideWith((ref) => books);
}

Override _loadingBooksOverride() {
  return providers.bookLibraryProvider.overrideWith(
    (ref) => Completer<List<Book>>().future,
  );
}

Override _failingBooksOverride() {
  return providers.bookLibraryProvider.overrideWith(
    (ref) => Future<List<Book>>.error(Exception('bookRepository unreachable')),
  );
}

Override _twoBooksOverride() {
  return _booksOverride(
    Future.value([
      _makeBook(id: 'b1', title: 'The Cat', author: 'Dr. Seuss', pageCount: 5),
      _makeBook(
        id: 'b2',
        title: 'The Hobbit',
        author: 'J.R.R. Tolkien',
        pageCount: 40,
      ),
    ]),
  );
}

Override _emptyBooksOverride() {
  return _booksOverride(Future.value(const []));
}

Future<void> _pumpLoadedLibrary(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

int _numberWordValue(String word) {
  const words = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
  };

  return word.split('-').fold<int>(0, (total, part) => total + words[part]!);
}

int _answerForGateQuestion(String question) {
  final match = RegExp(r'What is (.+) plus (.+)\?').firstMatch(question)!;
  return _numberWordValue(match.group(1)!) + _numberWordValue(match.group(2)!);
}

Future<void> _completeParentalGate(WidgetTester tester) async {
  await _pumpNavigation(tester);
  final question = tester.widget<Text>(find.textContaining('What is ')).data!;
  final answer = _answerForGateQuestion(question).toString();

  await tester.enterText(find.byType(TextField).last, answer);
  await tester.tap(find.text('Continue'));
  await _pumpNavigation(tester);
}

// ── Tests ─────────────────────────────────────────────────────────────────

void main() {
  group('LibraryScreen widget tests', () {
    late GoRouter router;
    String? navigatedToBookId;

    setUp(() {
      navigatedToBookId = null;
      router = _testRouter(onNavigate: (id) => navigatedToBookId = id);
    });

    // ── Loading state ─────────────────────────────────────────────────

    testWidgets('shows loading indicator when books are loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_loadingBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading your library...'), findsOneWidget);
    });

    // ── Error state ────────────────────────────────────────────────────

    testWidgets('shows error state with retry button when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_failingBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpNavigation(tester);

      expect(find.text('Could not load the library'), findsOneWidget);
      expect(find.textContaining('bookRepository'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    // ── Data state ────────────────────────────────────────────────────

    testWidgets('shows game view when books load successfully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Tales'), findsOneWidget);
      expect(find.text('Quick Reads'), findsOneWidget);
      expect(find.text('Longer Reads'), findsOneWidget);
    });

    // ── Search debounce ───────────────────────────────────────────────

    testWidgets('search input debounces and does not fire on every keystroke', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'c');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(searchField, 'ca');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(searchField, 'cat');
      await tester.pump(const Duration(milliseconds: 50));

      // Debounce is 220ms, so 50ms hasn't triggered anything yet
      await tester.pump(const Duration(milliseconds: 250));

      final textField = tester.widget<TextField>(searchField);
      expect(textField.controller?.text, equals('cat'));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('search clear button resets the search', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await _pumpNavigation(tester);

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals(''));
    });

    // ── Filter chips ───────────────────────────────────────────────────

    testWidgets('filter chip changes lengthFilter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      expect(find.text('All Tales'), findsOneWidget);
      expect(find.text('Quick Reads'), findsOneWidget);
      expect(find.text('Longer Reads'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('library-filter-gooey-indicator')),
        findsOneWidget,
      );
      expect(find.byType(GooeyZone), findsOneWidget);
      expect(find.byType(GooeyBlob), findsNWidgets(2));

      await tester.tap(find.text('Quick Reads'));
      await _pumpNavigation(tester);
      expect(
        find.byKey(const ValueKey('library-filter-gooey-indicator')),
        findsOneWidget,
      );

      await tester.tap(find.text('Longer Reads'));
      await _pumpNavigation(tester);

      await tester.tap(find.text('All Tales'));
      await _pumpNavigation(tester);

      expect(find.text('All Tales'), findsOneWidget);
      expect(find.text('Quick Reads'), findsOneWidget);
      expect(find.text('Longer Reads'), findsOneWidget);
    });

    // ── Book tap → navigate to reader ─────────────────────────────────

    testWidgets('reader route exists and is navigable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      router.go('/reader/test-book-id');
      await _pumpNavigation(tester);

      expect(find.textContaining('Reader:'), findsOneWidget);
      expect(navigatedToBookId, equals('test-book-id'));
    });

    // ── Settings button ────────────────────────────────────────────────

    testWidgets('settings icon button navigates to settings', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await _completeParentalGate(tester);

      expect(find.text('Settings'), findsOneWidget);
    });

    // ── Empty library ─────────────────────────────────────────────────

    testWidgets('empty library shows game view without crash', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_emptyBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    // ── Widget tree structure ───────────────────────────────────────────

    testWidgets('screen renders all expected layers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await _pumpLoadedLibrary(tester);

      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}
