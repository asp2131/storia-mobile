import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/api_client.dart';
import '../domain/book_question.dart';
import '../domain/comprehension_result.dart';

class ComprehensionRepository {
  const ComprehensionRepository(this._supabase, this._apiClient);

  final SupabaseClient _supabase;
  final ApiClient _apiClient;

  Future<List<BookQuestion>> fetchBookQuestions(String bookId) async {
    if (_apiClient.isConfigured) {
      try {
        final data = await _apiClient.get('/api/books/$bookId/questions');
        return _parseQuestions(data);
      } catch (e) {
        debugPrint(
          '[ComprehensionRepository] ApiClient fetchBookQuestions failed, '
          'falling back to Supabase: $e',
        );
      }
    }

    try {
      final data = await _supabase.functions.invoke(
        'books/$bookId/questions',
        method: HttpMethod.get,
      );
      return _parseQuestions(data.data);
    } catch (e) {
      debugPrint('[ComprehensionRepository] fetchBookQuestions failed: $e');
      return const [];
    }
  }

  Future<ComprehensionResult?> submitAnswers({
    required String childProfileId,
    required String bookId,
    String? readingSessionId,
    required List<QuestionAnswer> answers,
  }) async {
    final payload = <String, dynamic>{
      'childProfileId': childProfileId,
      'bookId': bookId,
      if (readingSessionId != null) 'readingSessionId': readingSessionId,
      'answers': answers.map((a) => a.toJson()).toList(),
      'source': 'mobile',
    };

    if (_apiClient.isConfigured) {
      try {
        final data = await _apiClient.post(
          '/api/comprehension',
          body: payload,
        );
        return _parseResult(data);
      } catch (e) {
        debugPrint(
          '[ComprehensionRepository] ApiClient submitAnswers failed, '
          'falling back to Supabase: $e',
        );
      }
    }

    try {
      final data = await _supabase.functions.invoke(
        'comprehension',
        method: HttpMethod.post,
        body: payload,
      );
      return _parseResult(data.data);
    } catch (e) {
      debugPrint('[ComprehensionRepository] submitAnswers failed: $e');
      return null;
    }
  }

  List<BookQuestion> _parseQuestions(dynamic raw) {
    final body = raw is Map<String, dynamic> ? raw : null;
    final questions = body?['questions'] as List<dynamic>? ?? const [];
    return questions
        .whereType<Map<String, dynamic>>()
        .map(BookQuestion.fromJson)
        .toList();
  }

  ComprehensionResult? _parseResult(dynamic raw) {
    final body = raw is Map<String, dynamic> ? raw : null;
    final result = body?['result'];
    if (result is! Map<String, dynamic>) return null;
    return ComprehensionResult.fromJson(result);
  }
}
