import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'book_repository.dart';
import 'models.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ApiClient(supabase);
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return BookRepository(supabase);
});

final bookLibraryProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getPublishedBooks();
});
final currentBookProvider = FutureProvider.family<Book?, String>((
  ref,
  bookId,
) async {
  if (bookId.isEmpty) {
    return null;
  }
  final repo = ref.watch(bookRepositoryProvider);
  return repo.getBookById(bookId);
});
