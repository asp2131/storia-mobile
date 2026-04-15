import 'package:flutter/foundation.dart';

enum BookProgressStatus {
  newBook('new'),
  inProgress('in_progress'),
  completed('completed');

  const BookProgressStatus(this.value);
  final String value;

  static BookProgressStatus fromString(String? value) {
    return switch (value) {
      'in_progress' => BookProgressStatus.inProgress,
      'completed' => BookProgressStatus.completed,
      _ => BookProgressStatus.newBook,
    };
  }
}

@immutable
class BookProgress {
  const BookProgress({
    required this.childProfileId,
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
    required this.progressPercent,
    this.lastReadAt,
    this.completedAt,
    required this.completionCount,
    this.lastSessionId,
    required this.status,
  });

  final String childProfileId;
  final String bookId;
  final int currentPage;
  final int totalPages;
  final int progressPercent;
  final DateTime? lastReadAt;
  final DateTime? completedAt;
  final int completionCount;
  final String? lastSessionId;
  final BookProgressStatus status;

  factory BookProgress.fromJson(Map<String, dynamic> json) {
    return BookProgress(
      childProfileId: json['childProfileId'] as String? ??
          json['child_profile_id'] as String? ??
          '',
      bookId: json['bookId'] as String? ??
          json['book_id'] as String? ??
          '',
      currentPage: (json['currentPage'] as num?)?.toInt() ??
          (json['current_page'] as num?)?.toInt() ??
          0,
      totalPages: (json['totalPages'] as num?)?.toInt() ??
          (json['total_pages'] as num?)?.toInt() ??
          0,
      progressPercent: (json['progressPercent'] as num?)?.toInt() ??
          (json['progress_percent'] as num?)?.toInt() ??
          0,
      lastReadAt: _parseDateTime(json['lastReadAt'] ?? json['last_read_at']),
      completedAt:
          _parseDateTime(json['completedAt'] ?? json['completed_at']),
      completionCount: (json['completionCount'] as num?)?.toInt() ??
          (json['completion_count'] as num?)?.toInt() ??
          0,
      lastSessionId: json['lastSessionId'] as String? ??
          json['last_session_id'] as String?,
      status: BookProgressStatus.fromString(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'childProfileId': childProfileId,
      'bookId': bookId,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'lastSessionId': lastSessionId,
      'completed': status == BookProgressStatus.completed,
      'source': 'mobile',
    };
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value);
  return null;
}
