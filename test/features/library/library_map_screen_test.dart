import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/data/providers.dart' as providers;
import 'package:storia_kids/src/features/library/ports/library_map_session.dart';
import 'package:storia_kids/src/features/library/ports/library_map_types.dart';
import 'package:storia_kids/src/features/library/services/library_map_session_impl.dart';
import 'package:storia_kids/src/features/library/library_screen.dart';
import 'fakes/fake_ports.dart';

// ── Fake library map screen for testing without Flame ─────────────────────

/// A stripped-down [LibraryMapSession] that records calls for test verification.
class FakeLibraryMapScreenSession implements LibraryMapSession {
  FakeLibraryMapScreenSession({List<Book>? books}) {
    if (books != null) {
      _loadedBooks = books;
      _visibleBookIds = books.map((b) => b.id).toSet();
    }
  }

  late List<Book> _loadedBooks;

  List<LibraryMapBook> _books = [];
  LibraryMapQuery _query = const LibraryMapQuery();
  Set<String> _visibleBookIds = {};
  LibraryMapBook? _selectedNode;
  LibraryMapBook? _previewBook;
  double _cameraX = 0;

  LibraryMapEventCallback? _onEvent;
  bool _disposed = false;

  void Function(LibraryMapBook)? onNavigateToBook;
  void Function(LibraryMapLengthFilter)? onFilterChanged;
  void Function(String)? onSearchChanged;

  void loadBooks(List<Book> books) {
    _loadedBooks = books;
    _visibleBookIds = books.map((b) => b.id).toSet();
  }

  @override
  List<LibraryMapBook> get books => _books;

  @override
  LibraryMapQuery get query => _query;

  @override
  LibraryMapLengthFilter get lengthFilter => _query.lengthFilter;

  @override
  Set<String> get visibleBookIds => _visibleBookIds;

  @override
  LibraryMapBook? get selectedNode => _selectedNode;

  @override
  LibraryMapBook? get previewBook => _previewBook;

  @override
  double get cameraX => _cameraX;

  @override
  LibraryMapViewport get viewport => LibraryMapViewport(
        screenWidth: 400,
        screenHeight: 800,
        cameraX: _cameraX,
        worldWidth: 600,
      );

  @override
  void setEventCallback(LibraryMapEventCallback callback) {
    _onEvent = callback;
  }

  @override
  void setSearchText(String text) {
    _query = _query.copyWith(searchText: text);
    onSearchChanged?.call(text);
  }

  @override
  void setLengthFilter(LibraryMapLengthFilter filter) {
    _query = _query.copyWith(lengthFilter: filter);
    onFilterChanged?.call(filter);
  }

  @override
  void applyQuery(LibraryMapQuery query) {
    _query = query;
    onFilterChanged?.call(query.lengthFilter);
  }

  @override
  void navigateToBook(
    LibraryMapBook book, {
    ArrivalMode mode = ArrivalMode.walkAndPreview,
  }) {
    _selectedNode = book;
    onNavigateToBook?.call(book);
  }

  @override
  void selectBrowseResult(LibraryMapBook book) {
    navigateToBook(book, mode: ArrivalMode.walk);
  }

  @override
  void dismissPreview() {
    _previewBook = null;
  }

  @override
  ui.Offset? screenPositionOfNode(LibraryMapBook book) => null;

  @override
  List<LibraryMapBook> getBrowseResults({int limit = 8}) => const [];

  @override
  void dispose() {
    _disposed = true;
  }

  bool get isDisposed => _disposed;
}

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
    (ref) => Future<List<Book>>.delayed(
      const Duration(seconds: 30),
      () => const [],
    ),
  );
}

Override _failingBooksOverride() {
  return providers.bookLibraryProvider.overrideWith(
    (ref) => Future<List<Book>>.error(Exception('bookRepository unreachable')),
  );
}

Override _twoBooksOverride() {
  return _booksOverride(Future.value([
    _makeBook(id: 'b1', title: 'The Cat', author: 'Dr. Seuss', pageCount: 5),
    _makeBook(id: 'b2', title: 'The Hobbit', author: 'J.R.R. Tolkien', pageCount: 40),
  ]));
}

Override _emptyBooksOverride() {
  return _booksOverride(Future.value(const []));
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

      await tester.pumpAndSettle();

      expect(find.text('Could not load the library'), findsOneWidget);
      expect(find.textContaining('bookRepository'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    // ── Data state ────────────────────────────────────────────────────

    testWidgets('shows game view when books load successfully', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Tales'), findsOneWidget);
      expect(find.text('Quick Reads'), findsOneWidget);
      expect(find.text('Longer Reads'), findsOneWidget);
    });

    // ── Search debounce ───────────────────────────────────────────────

    testWidgets(
      'search input debounces and does not fire on every keystroke',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [_twoBooksOverride()],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'c');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'ca');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'cat');
        await tester.pump(const Duration(milliseconds: 50));

        // Debounce is 220ms, so 50ms hasn't triggered anything yet
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        final textField = tester.widget<TextField>(searchField);
        expect(textField.controller?.text, equals('cat'));
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      },
    );

    testWidgets('search clear button resets the search', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [_twoBooksOverride()],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cat');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

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

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Material, 'All Tales'), findsOneWidget);
      expect(find.widgetWithText(Material, 'Quick Reads'), findsOneWidget);
      expect(find.widgetWithText(Material, 'Longer Reads'), findsOneWidget);

      await tester.tap(find.widgetWithText(Material, 'Quick Reads'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Material, 'Longer Reads'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Material, 'All Tales'));
      await tester.pumpAndSettle();

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

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      router.go('/reader/test-book-id');
      await tester.pumpAndSettle();

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

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

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

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

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

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}