import 'reader_entry_intent.dart';
import 'reading_session_payload.dart';

class ReadingSessionDraft {
  ReadingSessionDraft({
    required this.sessionId,
    required this.childProfileId,
    required this.bookId,
    required this.startedAt,
    required this.startPage,
    required this.entryIntent,
  }) : latestPage = startPage;

  final String sessionId;
  final String childProfileId;
  final String bookId;
  final DateTime startedAt;
  final int startPage;
  final ReaderEntryIntent entryIntent;

  int latestPage;
  bool usedNarration = false;
  bool usedPracticeMode = false;
  bool completedBook = false;

  void markPage(int page) {
    latestPage = page;
  }

  void markNarrationUsed() {
    usedNarration = true;
  }

  void markPracticeModeUsed() {
    usedPracticeMode = true;
  }

  void markCompleted() {
    completedBook = true;
  }

  ReadingSessionPayload finalize(DateTime endedAt) {
    return ReadingSessionPayload(
      sessionId: sessionId,
      childProfileId: childProfileId,
      bookId: bookId,
      startedAt: startedAt,
      endedAt: endedAt,
      startPage: startPage,
      endPage: latestPage,
      entryIntent: entryIntent,
      usedNarration: usedNarration,
      usedPracticeMode: usedPracticeMode,
      completedBook: completedBook,
      source: 'mobile',
    );
  }
}
