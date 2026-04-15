import 'package:flutter/foundation.dart';

import '../../features/reader/domain/reader_entry_intent.dart';

/// Centralized analytics service for proof-test event taxonomy.
///
/// MVP implementation logs to debug console. Replace internals with PostHog
/// or another analytics provider when ready — call sites stay unchanged.
class AnalyticsService {
  void trackLibraryViewed({required String childId}) {
    _track('library_viewed', {'childId': childId});
  }

  void trackContinueReadingImpression({
    required String childId,
    required String bookId,
    required int currentPage,
  }) {
    _track('continue_reading_impression', {
      'childId': childId,
      'bookId': bookId,
      'currentPage': currentPage,
      'source': 'library',
    });
  }

  void trackContinueReadingResumeTapped({
    required String childId,
    required String bookId,
    required int currentPage,
  }) {
    _track('continue_reading_resume_tapped', {
      'childId': childId,
      'bookId': bookId,
      'currentPage': currentPage,
      'source': 'library',
    });
  }

  void trackContinueReadingPlayTapped({
    required String childId,
    required String bookId,
    required int currentPage,
  }) {
    _track('continue_reading_play_tapped', {
      'childId': childId,
      'bookId': bookId,
      'currentPage': currentPage,
      'source': 'library',
    });
  }

  void trackBookPreviewOpened({
    required String childId,
    required String bookId,
    required String progressStatus,
    required bool hasNarration,
  }) {
    _track('book_preview_opened', {
      'childId': childId,
      'bookId': bookId,
      'progressStatus': progressStatus,
      'hasNarration': hasNarration,
      'source': 'library_map',
    });
  }

  void trackBookPreviewReadTapped({
    required String childId,
    required String bookId,
  }) {
    _track('book_preview_read_tapped', {
      'childId': childId,
      'bookId': bookId,
      'source': 'library_map',
    });
  }

  void trackBookPreviewPlayTapped({
    required String childId,
    required String bookId,
  }) {
    _track('book_preview_play_tapped', {
      'childId': childId,
      'bookId': bookId,
      'source': 'library_map',
    });
  }

  void trackReaderOpened({
    required String childId,
    required String bookId,
    required String sessionId,
    required ReaderEntryIntent entryIntent,
    required int resumePage,
  }) {
    _track('reader_opened', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'entryIntent': entryIntent.value,
      'resumePage': resumePage,
      'source': 'mobile',
    });
  }

  void trackReadingSessionStarted({
    required String childId,
    required String bookId,
    required String sessionId,
    required ReaderEntryIntent entryIntent,
  }) {
    _track('reading_session_started', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'entryIntent': entryIntent.value,
      'source': 'mobile',
    });
  }

  void trackReadingSessionEnded({
    required String childId,
    required String bookId,
    required String sessionId,
    required int startPage,
    required int endPage,
    required bool completedBook,
  }) {
    _track('reading_session_ended', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'startPage': startPage,
      'endPage': endPage,
      'completedBook': completedBook,
      'source': 'mobile',
    });
  }

  void trackBookCompleted({
    required String childId,
    required String bookId,
    required String sessionId,
  }) {
    _track('book_completed', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'source': 'mobile',
    });
  }

  void trackComprehensionStarted({
    required String childId,
    required String bookId,
    required String sessionId,
    required int totalQuestions,
  }) {
    _track('comprehension_started', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'totalQuestions': totalQuestions,
      'source': 'mobile',
    });
  }

  void trackComprehensionQuestionAnswered({
    required String childId,
    required String bookId,
    required String questionId,
    required bool isCorrect,
  }) {
    _track('comprehension_question_answered', {
      'childId': childId,
      'bookId': bookId,
      'questionId': questionId,
      'isCorrect': isCorrect,
      'source': 'mobile',
    });
  }

  void trackComprehensionCompleted({
    required String childId,
    required String bookId,
    required String sessionId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
  }) {
    _track('comprehension_completed', {
      'childId': childId,
      'bookId': bookId,
      'sessionId': sessionId,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'scorePercent': scorePercent,
      'source': 'mobile',
    });
  }

  void _track(String event, Map<String, dynamic> properties) {
    // MVP: debug logging. Replace with PostHog or backend call later.
    debugPrint('[Analytics] $event $properties');
  }
}
