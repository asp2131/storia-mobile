import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'book_repository.dart';
import 'models.dart';
import 'pronunciation_models.dart';
import 'pronunciation_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
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

final pronunciationRepositoryProvider = Provider<PronunciationRepository>((
  ref,
) {
  final supabase = ref.watch(supabaseClientProvider);
  return PronunciationRepository(supabase);
});

final bookManifestProvider = FutureProvider.family<
  BookPronunciationManifest?,
  String
>((ref, bookId) async {
  if (bookId.isEmpty) {
    return null;
  }
  final repo = ref.watch(pronunciationRepositoryProvider);
  return repo.getManifestForBook(bookId);
});
