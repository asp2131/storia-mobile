import 'dart:async';

import '../../../core/analytics/analytics_service.dart';
import '../../progress/data/progress_repository.dart';
import '../data/reading_session_repository.dart';
import '../domain/reader_entry_intent.dart';
import '../domain/reading_session_draft.dart';
import '../domain/reading_session_payload.dart';

/// Bridges the reader UX layer to proof-test data writes.
///
/// Owns the reading session draft lifecycle and coordinates:
/// - session start/finalize
/// - debounced progress saves
/// - narration/practice mode tracking
/// - analytics event emission
///
/// The existing [ReaderSessionImpl] stays focused on reading behavior,
/// audio, and interaction state. This coordinator observes those changes
/// and translates them into canonical proof data.
class ReadingSessionCoordinator {
  ReadingSessionCoordinator({
    required ProgressRepository progressRepository,
    required ReadingSessionRepository sessionRepository,
    required AnalyticsService analyticsService,
  }) : _progressRepo = progressRepository,
       _sessionRepo = sessionRepository,
       _analytics = analyticsService;

  final ProgressRepository _progressRepo;
  final ReadingSessionRepository _sessionRepo;
  final AnalyticsService _analytics;

  ReadingSessionDraft? _draft;
  Timer? _progressDebounce;
  int _totalPages = 0;

  ReadingSessionDraft? get currentDraft => _draft;
  bool get hasActiveSession => _draft != null;

  /// Session ID available after [onBookCompleted] for comprehension linking.
  String? get completedSessionId =>
      (_draft?.completedBook ?? false) ? _draft?.sessionId : null;

  /// Book ID available after [onBookCompleted] for comprehension linking.
  String? get completedBookId =>
      (_draft?.completedBook ?? false) ? _draft?.bookId : null;

  /// Child profile ID from the active draft.
  String? get activeChildProfileId => _draft?.childProfileId;

  /// Call when the reader opens. Creates a new session draft.
  void startSession({
    required String sessionId,
    required String childProfileId,
    required String bookId,
    required int startPage,
    required int totalPages,
    required ReaderEntryIntent entryIntent,
  }) {
    _draft = ReadingSessionDraft(
      sessionId: sessionId,
      childProfileId: childProfileId,
      bookId: bookId,
      startedAt: DateTime.now(),
      startPage: startPage,
      entryIntent: entryIntent,
    );
    _totalPages = totalPages;

    if (entryIntent == ReaderEntryIntent.autoplayNarration) {
      _draft!.markNarrationUsed();
    }

    _analytics.trackReadingSessionStarted(
      childId: childProfileId,
      bookId: bookId,
      sessionId: sessionId,
      entryIntent: entryIntent,
    );
  }

  /// Call on each page change. Updates the draft and debounces a progress save.
  void onPageChanged(int page) {
    final draft = _draft;
    if (draft == null) return;

    draft.markPage(page);

    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 3), () {
      _saveProgressQuietly(draft, page);
    });
  }

  /// Call when narration is toggled on during the session.
  void onNarrationUsed() {
    _draft?.markNarrationUsed();
  }

  /// Call when practice mode is activated during the session.
  void onPracticeModeUsed() {
    _draft?.markPracticeModeUsed();
  }

  Future<void> flushProgress() async {
    final draft = _draft;
    if (draft == null) return;

    _progressDebounce?.cancel();
    _progressDebounce = null;

    await _progressRepo.saveBookProgress(
      childProfileId: draft.childProfileId,
      bookId: draft.bookId,
      currentPage: draft.latestPage,
      totalPages: _totalPages,
      lastSessionId: draft.sessionId,
      completed: draft.completedBook,
    );
  }

  /// Call when the child reaches the final page.
  void onBookCompleted() {
    final draft = _draft;
    if (draft == null) return;

    draft.markCompleted();

    _analytics.trackBookCompleted(
      childId: draft.childProfileId,
      bookId: draft.bookId,
      sessionId: draft.sessionId,
    );
  }

  /// Call on reader exit or app backgrounding. Finalizes and uploads the session.
  Future<void> finalizeAndSave() async {
    final draft = _draft;
    if (draft == null) return;

    _progressDebounce?.cancel();
    _progressDebounce = null;

    final payload = draft.finalize(DateTime.now());
    _draft = null;

    _analytics.trackReadingSessionEnded(
      childId: payload.childProfileId,
      bookId: payload.bookId,
      sessionId: payload.sessionId,
      startPage: payload.startPage,
      endPage: payload.endPage,
      completedBook: payload.completedBook,
    );

    // Save final progress and session in parallel.
    await Future.wait([
      _saveProgress(payload),
      _sessionRepo.saveReadingSession(payload),
    ]);
  }

  Future<void> _saveProgress(ReadingSessionPayload payload) async {
    await _progressRepo.saveBookProgress(
      childProfileId: payload.childProfileId,
      bookId: payload.bookId,
      currentPage: payload.endPage,
      totalPages: _totalPages,
      lastSessionId: payload.sessionId,
      completed: payload.completedBook,
    );
  }

  void _saveProgressQuietly(ReadingSessionDraft draft, int page) {
    _progressRepo.saveBookProgress(
      childProfileId: draft.childProfileId,
      bookId: draft.bookId,
      currentPage: page,
      totalPages: _totalPages,
      lastSessionId: draft.sessionId,
    );
  }

  /// Cancel any pending timers. Call from dispose.
  void dispose() {
    _progressDebounce?.cancel();
    _progressDebounce = null;
  }
}
