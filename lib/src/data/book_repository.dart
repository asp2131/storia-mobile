import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class BookRepository {
  final SupabaseClient _supabase;

  const BookRepository(this._supabase);

  Future<List<Book>> getPublishedBooks() async {
    final data = await _supabase
        .from('books')
        .select('id, title, author, cover_url, pages(count)')
        .eq('is_published', true)
        // Newest first. (postgrest's order() already defaults to descending;
        // spelled out because the library once assumed the opposite.)
        .order('inserted_at', ascending: false);

    final rows = (data as List<dynamic>).whereType<Map<String, dynamic>>();
    return rows.map(Book.fromLibraryJson).toList(growable: false);
  }

  Future<Book?> getBookById(String bookId) async {
    return _getBookById(bookId);
  }

  /// Publication is checked in the same query that returns pages, so a shared
  /// URL cannot load a draft or a book unpublished since the catalog loaded.
  Future<Book?> getPublishedBookById(String bookId) async {
    return _getBookById(bookId, publishedOnly: true);
  }

  Future<Book?> _getBookById(
    String bookId, {
    bool publishedOnly = false,
  }) async {
    var query = _supabase
        .from('books')
        .select(
          'id, title, author, cover_url, pages(*, page_audio_assignments(id, audio_url, audio_type, scope, range_start, range_end, volume), scenes(soundscapes(audio_url, admin_approved)))',
        )
        .eq('id', bookId);
    if (publishedOnly) query = query.eq('is_published', true);
    final data = await query.maybeSingle();

    if (data == null) {
      return null;
    }

    return Book.fromJson(Map<String, dynamic>.from(data));
  }
}
