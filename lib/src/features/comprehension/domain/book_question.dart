import 'package:flutter/foundation.dart';

@immutable
class BookQuestionOption {
  const BookQuestionOption({
    required this.id,
    required this.optionKey,
    required this.optionText,
    required this.sortOrder,
  });

  final String id;
  final String optionKey;
  final String optionText;
  final int sortOrder;

  factory BookQuestionOption.fromJson(Map<String, dynamic> json) {
    return BookQuestionOption(
      id: json['id'] as String? ?? '',
      optionKey: json['optionKey'] as String? ??
          json['option_key'] as String? ??
          '',
      optionText: json['optionText'] as String? ??
          json['option_text'] as String? ??
          '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'optionKey': optionKey,
      'optionText': optionText,
      'sortOrder': sortOrder,
    };
  }
}

@immutable
class BookQuestion {
  const BookQuestion({
    required this.id,
    required this.bookId,
    required this.questionText,
    required this.questionType,
    required this.sortOrder,
    required this.options,
  });

  final String id;
  final String bookId;
  final String questionText;
  final String questionType;
  final int sortOrder;
  final List<BookQuestionOption> options;

  factory BookQuestion.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'] as List<dynamic>? ?? [];
    return BookQuestion(
      id: json['id'] as String? ?? '',
      bookId: json['bookId'] as String? ??
          json['book_id'] as String? ??
          '',
      questionText: json['questionText'] as String? ??
          json['question_text'] as String? ??
          '',
      questionType: json['questionType'] as String? ??
          json['question_type'] as String? ??
          'multiple_choice',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ??
          (json['sort_order'] as num?)?.toInt() ??
          0,
      options: optionsList
          .whereType<Map<String, dynamic>>()
          .map(BookQuestionOption.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'questionText': questionText,
      'questionType': questionType,
      'sortOrder': sortOrder,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}
