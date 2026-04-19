import 'package:flutter/foundation.dart';

@immutable
class ReportSummary {
  const ReportSummary({
    required this.childProfileId,
    required this.range,
    required this.booksStarted,
    required this.booksCompleted,
    required this.totalSessions,
    required this.totalReadingMinutes,
    required this.averageSessionMinutes,
    required this.comprehensionAttempts,
    required this.averageComprehensionScore,
    required this.practiceSessions,
    required this.practiceMinutes,
    required this.practiceSessionRatePercent,
  });

  final String childProfileId;
  final String range;
  final int booksStarted;
  final int booksCompleted;
  final int totalSessions;
  final int totalReadingMinutes;
  final int averageSessionMinutes;
  final int comprehensionAttempts;
  final int averageComprehensionScore;
  final int practiceSessions;
  final int practiceMinutes;
  final int practiceSessionRatePercent;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      childProfileId: json['childProfileId'] as String? ?? '',
      range: json['range'] as String? ?? '30d',
      booksStarted: (json['booksStarted'] as num?)?.toInt() ?? 0,
      booksCompleted: (json['booksCompleted'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalReadingMinutes: (json['totalReadingMinutes'] as num?)?.toInt() ?? 0,
      averageSessionMinutes:
          (json['averageSessionMinutes'] as num?)?.toInt() ?? 0,
      comprehensionAttempts:
          (json['comprehensionAttempts'] as num?)?.toInt() ?? 0,
      averageComprehensionScore:
          (json['averageComprehensionScore'] as num?)?.toInt() ?? 0,
      practiceSessions: (json['practiceSessions'] as num?)?.toInt() ?? 0,
      practiceMinutes: (json['practiceMinutes'] as num?)?.toInt() ?? 0,
      practiceSessionRatePercent:
          (json['practiceSessionRatePercent'] as num?)?.toInt() ?? 0,
    );
  }
}

const reportRanges = <String>['7d', '30d', '90d'];

String reportRangeLabel(String range) {
  return switch (range) {
    '7d' => '7 days',
    '30d' => '30 days',
    '90d' => '90 days',
    _ => range,
  };
}
