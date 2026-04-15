import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/book_question.dart';
import '../domain/comprehension_result.dart';

class ComprehensionRepository {
  const ComprehensionRepository(this._supabase);

  final SupabaseClient _supabase;

  Future<List<BookQuestion>> fetchBookQuestions(String bookId) async {
    try {
      final data = await _supabase.functions.invoke(
        'books/$bookId/questions',
        method: HttpMethod.get,
      );

      final body = data.data as Map<String, dynamic>?;
      final questions = body?['questions'] as List<dynamic>? ?? [];

      return questions
          .whereType<Map<String, dynamic>>()
          .map(BookQuestion.fromJson)
          .toList();
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
    try {
      final data = await _supabase.functions.invoke(
        'comprehension',
        method: HttpMethod.post,
        body: {
          'childProfileId': childProfileId,
          'bookId': bookId,
          if (readingSessionId != null) 'readingSessionId': readingSessionId,
          'answers': answers.map((a) => a.toJson()).toList(),
          'source': 'mobile',
        },
      );

      final body = data.data as Map<String, dynamic>?;
      final result = body?['result'];
      if (result == null) return null;

      return ComprehensionResult.fromJson(result as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ComprehensionRepository] submitAnswers failed: $e');
      return null;
    }
  }
}
