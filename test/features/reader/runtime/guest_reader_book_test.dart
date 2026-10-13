import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/auth/data/intro_books_provider.dart';
import 'package:loratone/src/features/auth/presentation/guest_reader_screen.dart';

void main() {
  test(
    'an arbitrary guest book ID cannot initialize catalog or repository',
    () async {
      final container = ProviderContainer(
        overrides: [
          introBooksProvider.overrideWith(
            (ref) => throw StateError('catalog read'),
          ),
          bookRepositoryProvider.overrideWith(
            (ref) => throw StateError('repository initialized'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(guestReaderBookProvider('999').future),
        isNull,
      );
    },
  );

  test('an allowlisted but unpublished book cannot fetch full pages', () async {
    final container = ProviderContainer(
      overrides: [
        introBooksProvider.overrideWith((ref) async => []),
        bookRepositoryProvider.overrideWith(
          (ref) => throw StateError('unpublished pages queried'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(guestReaderBookProvider('68').future), isNull);
  });
}
