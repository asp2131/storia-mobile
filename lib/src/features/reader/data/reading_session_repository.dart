import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/api_client.dart';
import '../domain/reading_session_payload.dart';

class ReadingSessionRepository {
  const ReadingSessionRepository(this._supabase, this._apiClient);

  final SupabaseClient _supabase;
  final ApiClient _apiClient;

  Future<bool> saveReadingSession(ReadingSessionPayload payload) async {
    try {
      await _apiClient.post('/api/reading-sessions', body: payload.toJson());
      return true;
    } catch (e) {
      debugPrint('[ReadingSessionRepository] API saveReadingSession failed: $e');
    }

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
