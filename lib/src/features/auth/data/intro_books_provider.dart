import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../domain/intro_book_selection.dart';

final introBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  // The catalog query enforces publication status; getBookById does not.
  final publishedBooks = await repository.getPublishedBooks();
  final selectedBooks = {
    for (final book in publishedBooks)
      if (introBookIds.contains(book.id)) book.id: book,
  };
  return [
    for (final id in introBookIds)
      if (selectedBooks[id] case final book?) book,
  ];
});
