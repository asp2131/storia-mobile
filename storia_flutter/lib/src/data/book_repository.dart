import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class BookRepository {
  final SupabaseClient _supabase;

  const BookRepository(this._supabase);

  Future<List<Book>> getPublishedBooks() async {
    final data = await _supabase
        .from('books')
        .select(
          'id, title, author, cover_url, pages(*, page_audio_assignments(id, audio_url, audio_type, scope, range_start, range_end, volume), scenes(soundscapes(audio_url, admin_approved)))',
        )
        .eq('is_published', true)
        .order('inserted_at');

    final rows = (data as List<dynamic>).whereType<Map<String, dynamic>>();
    return rows.map(Book.fromJson).toList();
  }

  Future<Book?> getBookById(String bookId) async {
    final data = await _supabase
        .from('books')
        .select(
          'id, title, author, cover_url, pages(*, page_audio_assignments(id, audio_url, audio_type, scope, range_start, range_end, volume), scenes(soundscapes(audio_url, admin_approved)))',
        )
        .eq('id', bookId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Book.fromJson(Map<String, dynamic>.from(data));
  }
}
