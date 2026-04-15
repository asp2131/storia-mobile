import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reading_session_payload.dart';

class ReadingSessionRepository {
  const ReadingSessionRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<bool> saveReadingSession(ReadingSessionPayload payload) async {
    try {
      await _supabase.functions.invoke(
        'reading-sessions',
        method: HttpMethod.post,
        body: payload.toJson(),
      );
      return true;
    } catch (e) {
      debugPrint('[ReadingSessionRepository] saveReadingSession failed: $e');
      return false;
    }
  }
}
