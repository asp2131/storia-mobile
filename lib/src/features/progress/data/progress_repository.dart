import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/api_client.dart';
import '../domain/book_progress.dart';
import '../domain/continue_reading_item.dart';

class ProgressRepository {
  const ProgressRepository(this._supabase, this._apiClient);

  final SupabaseClient _supabase;
  final ApiClient _apiClient;

  Future<BookProgress?> fetchBookProgress({
    required String childProfileId,
    required String bookId,
  }) async {
    try {
      final body = await _apiClient.get(
        '/api/reading-progress',
        queryParameters: {
          'childProfileId': childProfileId,
          'bookId': bookId,
        },
      ) as Map<String, dynamic>?;
      final progress = body?['progress'];
      if (progress == null) return null;
      return BookProgress.fromJson(progress as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProgressRepository] API fetchBookProgress failed: $e');
    }

    try {
      final data = await _supabase.functions.invoke(
        'reading-progress',
        method: HttpMethod.get,
        queryParameters: {
          'childProfileId': childProfileId,
          'bookId': bookId,
        },
      );

      final body = data.data as Map<String, dynamic>?;
      final progress = body?['progress'];
      if (progress == null) return null;

      return BookProgress.fromJson(progress as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProgressRepository] fetchBookProgress failed: $e');
      return null;
    }
  }

  Future<BookProgress?> saveBookProgress({
    required String childProfileId,
    required String bookId,
    required int currentPage,
    required int totalPages,
    String? lastSessionId,
    bool completed = false,
  }) async {
    final normalizedTotalPages = totalPages < 1 ? 1 : totalPages;
    final normalizedCurrentPage = currentPage.clamp(1, normalizedTotalPages);
    final payload = {
      'childProfileId': childProfileId,
      'bookId': bookId,
      'currentPage': normalizedCurrentPage,
      'totalPages': normalizedTotalPages,
      'lastSessionId': lastSessionId,
      'completed': completed,
      'source': 'mobile',
    };

    try {
      final body = await _apiClient.post(
        '/api/reading-progress',
        body: payload,
      ) as Map<String, dynamic>?;
      final progress = body?['progress'];
      if (progress == null) return null;
      return BookProgress.fromJson(progress as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProgressRepository] API saveBookProgress failed: $e');
    }

    try {
      final data = await _supabase.functions.invoke(
        'reading-progress',
        method: HttpMethod.post,
        body: payload,
      );

      final body = data.data as Map<String, dynamic>?;
      final progress = body?['progress'];
      if (progress == null) return null;

      return BookProgress.fromJson(progress as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ProgressRepository] saveBookProgress failed: $e');
      return null;
    }
  }

  Future<ContinueReadingItem?> fetchContinueReading({
    required String childProfileId,
  }) async {
    try {
      final body = await _apiClient.get(
        '/api/continue-reading',
        queryParameters: {'childProfileId': childProfileId},
      ) as Map<String, dynamic>?;
      final continueReading = body?['continueReading'];
      if (continueReading == null) return null;

      return ContinueReadingItem.fromJson(
        continueReading as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[ProgressRepository] API fetchContinueReading failed: $e');
    }

    try {
      final data = await _supabase.functions.invoke(
        'continue-reading',
        method: HttpMethod.get,
        queryParameters: {'childProfileId': childProfileId},
      );

      final body = data.data as Map<String, dynamic>?;
      final continueReading = body?['continueReading'];
      if (continueReading == null) return null;

      return ContinueReadingItem.fromJson(
        continueReading as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[ProgressRepository] fetchContinueReading failed: $e');
      return null;
    }
  }

  Future<Map<String, BookProgress>> fetchBookProgressMap({
    required String childProfileId,
  }) async {
    try {
      final body = await _apiClient.get(
        '/api/reading-progress',
        queryParameters: {'childProfileId': childProfileId},
      ) as Map<String, dynamic>?;
      final progressList = body?['progressList'] as List<dynamic>?;
      if (progressList != null) {
        final entries = progressList
            .whereType<Map<String, dynamic>>()
            .map(BookProgress.fromJson);
        return {for (final p in entries) p.bookId: p};
      }
    } catch (e) {
      debugPrint('[ProgressRepository] API fetchBookProgressMap failed: $e');
    }

    try {
      final data = await _supabase.functions.invoke(
        'reading-progress',
        method: HttpMethod.get,
        queryParameters: {'childProfileId': childProfileId},
      );

      final body = data.data as Map<String, dynamic>?;
      final progressList = body?['progressList'] as List<dynamic>?;
      if (progressList == null) return const {};

      final entries = progressList
          .whereType<Map<String, dynamic>>()
          .map(BookProgress.fromJson);

      return {for (final p in entries) p.bookId: p};
    } catch (e) {
      debugPrint('[ProgressRepository] fetchBookProgressMap failed: $e');
      return const {};
    }
  }
}
