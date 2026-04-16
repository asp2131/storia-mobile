import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:Storia_Kids/src/features/comprehension/data/comprehension_repository.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/book_question.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/comprehension_result.dart';
import 'package:Storia_Kids/src/features/comprehension/presentation/comprehension_screen.dart';
import 'package:Storia_Kids/src/features/comprehension/providers/comprehension_providers.dart';

class _FakeRepository implements ComprehensionRepository {
  _FakeRepository({this.questionsFuture, this.errorMessage});

  final Future<List<BookQuestion>>? questionsFuture;
  final String? errorMessage;

  @override
  Future<List<BookQuestion>> fetchBookQuestions(String bookId) async {
    if (errorMessage != null) {
      throw StateError(errorMessage!);
    }
    if (questionsFuture != null) {
      return questionsFuture!;
    }
    return const [];
  }

  @override
  Future<ComprehensionResult?> submitAnswers({
    required String childProfileId,
    required String bookId,
    String? readingSessionId,
    required List<QuestionAnswer> answers,
  }) async {
    return null;
  }
}

GoRouter _router(Widget screen) {
  return GoRouter(
    initialLocation: '/comprehension/b1',
    routes: [
      GoRoute(path: '/comprehension/:bookId', builder: (_, __) => screen),
      GoRoute(
        path: '/library',
        builder: (_, __) => const Scaffold(body: Text('Library Page')),
      ),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ComprehensionRepository repo,
}) async {
  const screen = ComprehensionScreen(bookId: 'b1');
  final router = _router(screen);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        comprehensionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

void main() {
  testWidgets('shows loading spinner while questions load', (tester) async {
    final completer = Completer<List<BookQuestion>>();
    final repo = _FakeRepository(questionsFuture: completer.future);

    await _pumpScreen(tester, repo: repo);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('shows error state with Back to library button on failure', (tester) async {
    final repo = _FakeRepository(errorMessage: 'boom');

    await _pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('Could not load questions'), findsOneWidget);
    expect(find.text('Back to library'), findsOneWidget);
  });

  testWidgets('navigates to library when question list is empty', (tester) async {
    final repo = _FakeRepository(questionsFuture: Future.value(const []));

    await _pumpScreen(tester, repo: repo);
    await tester.pumpAndSettle();

    expect(find.text('Library Page'), findsOneWidget);
  });
}
