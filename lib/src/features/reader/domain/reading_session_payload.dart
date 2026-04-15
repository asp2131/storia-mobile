import 'package:flutter/foundation.dart';

import 'reader_entry_intent.dart';

@immutable
class ReadingSessionPayload {
  const ReadingSessionPayload({
    required this.sessionId,
    required this.childProfileId,
    required this.bookId,
    required this.startedAt,
    required this.endedAt,
    required this.startPage,
    required this.endPage,
    required this.entryIntent,
    required this.usedNarration,
    required this.usedPracticeMode,
    required this.completedBook,
    required this.source,
    this.metadata,
  });

  final String sessionId;
  final String childProfileId;
  final String bookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int startPage;
  final int endPage;
  final ReaderEntryIntent entryIntent;
  final bool usedNarration;
  final bool usedPracticeMode;
  final bool completedBook;
  final String source;
  final Map<String, dynamic>? metadata;

  int get durationSeconds => endedAt.difference(startedAt).inSeconds;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'childProfileId': childProfileId,
      'bookId': bookId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'startPage': startPage,
      'endPage': endPage,
      'entryIntent': entryIntent.value,
      'usedNarration': usedNarration,
      'usedPracticeMode': usedPracticeMode,
      'completedBook': completedBook,
      'source': source,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
