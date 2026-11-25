import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loratone/src/data/book_repository.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/auth/presentation/guest_reader_screen.dart';
import 'package:loratone/src/features/sharing/book_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('book links use the permanent custom domain with no private state', () {
    expect(
      BookLinks.forBook('70').toString(),
      'https://app.loratone.com/book/70',
    );
    for (final id in ['', '../settings', 'draft', '70?token=private']) {
      expect(() => BookLinks.forBook(id), throwsArgumentError);
    }
  });

  test('malformed shared IDs cannot initialize the repository', () async {
    final container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith(
          (ref) => throw StateError('repository initialized'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(sharedReaderBookProvider('draft').future),
      isNull,
    );
  });

  test(
    'a shared title outside the intro list queries only published content',
    () async {
      final client = SupabaseClient(
        'https://catalog.example.com',
        'anon',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['id'], 'eq.70');
          expect(request.url.queryParameters['is_published'], 'eq.true');
          expect(request.url.queryParameters['select'], contains('pages('));
          return http.Response(
            '{"id":70,"title":"Shared story","pages":[]}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          bookRepositoryProvider.overrideWithValue(BookRepository(client)),
        ],
      );
      addTearDown(container.dispose);
      final book = await container.read(sharedReaderBookProvider('70').future);
      expect(book?.id, '70');
      expect(book?.title, 'Shared story');
    },
  );

  testWidgets('an unpublished shared title shows an unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedReaderBookProvider('70').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: GuestReaderScreen.shared(bookId: '70')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This story is not available right now.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
