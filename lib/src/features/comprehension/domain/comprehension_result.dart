import 'package:flutter/foundation.dart';

@immutable
class QuestionAnswer {
  const QuestionAnswer({
    required this.questionId,
    required this.selectedAnswer,
    this.isCorrect,
  });

  final String questionId;
  final String selectedAnswer;
  final bool? isCorrect;

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedAnswer': selectedAnswer,
    };
  }

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      questionId: json['questionId'] as String? ??
          json['question_id'] as String? ??
          '',
      selectedAnswer: json['selectedAnswer'] as String? ??
          json['selected_answer'] as String? ??
          '',
      isCorrect: json['isCorrect'] as bool? ?? json['is_correct'] as bool?,
    );
  }
}

@immutable
class ComprehensionResult {
  const ComprehensionResult({
    required this.bookId,
    required this.childProfileId,
    required this.totalQuestions,
    required this.correctCount,
    required this.scorePercent,
    this.submittedAt,
  });

  final String bookId;
  final String childProfileId;
  final int totalQuestions;
  final int correctCount;
  final int scorePercent;
  final DateTime? submittedAt;

  factory ComprehensionResult.fromJson(Map<String, dynamic> json) {
    return ComprehensionResult(
      bookId: json['bookId'] as String? ??
          json['book_id'] as String? ??
          '',
      childProfileId: json['childProfileId'] as String? ??
          json['child_profile_id'] as String? ??
          '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ??
          (json['total_questions'] as num?)?.toInt() ??
          0,
      correctCount: (json['correctCount'] as num?)?.toInt() ??
          (json['correct_count'] as num?)?.toInt() ??
          0,
      scorePercent: (json['scorePercent'] as num?)?.toInt() ??
          (json['score_percent'] as num?)?.toInt() ??
          0,
      submittedAt: _parseDateTime(
        json['submittedAt'] ?? json['submitted_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'childProfileId': childProfileId,
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'scorePercent': scorePercent,
      if (submittedAt != null)
        'submittedAt': submittedAt!.toUtc().toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
