import 'dart:async';
import 'dart:math';

import '../../../data/analytics_repository.dart';
import '../../../data/models.dart';

typedef ReaderSessionIdFactory = String Function();

/// Centralized analytics instrumentation for the reader runtime.
///
/// This class owns per-reading-session identity and de-duplication so widgets
/// can report high-level runtime actions without coupling rebuilds to analytics
/// calls. It intentionally stores only metadata/scores/indices; never raw child
/// audio or speech transcripts.
class ReaderAnalyticsTracker {
  ReaderAnalyticsTracker({
    required AnalyticsRepository analyticsRepository,
    ReaderSessionIdFactory? sessionIdFactory,
    DateTime Function()? clock,
  }) : _analyticsRepository = analyticsRepository,
       _sessionIdFactory = sessionIdFactory ?? _defaultSessionId,
       _clock = clock ?? DateTime.now;

  final AnalyticsRepository _analyticsRepository;
  final ReaderSessionIdFactory _sessionIdFactory;
  final DateTime Function() _clock;

  Book? _book;
  String? _sessionId;
  DateTime? _sessionStartedAt;
  int _activePageIndex = 0;
  bool _bookCompletedTracked = false;
  bool _sessionEnded = true;
  int _speechAttemptSequence = 0;
  final Set<int> _viewedPageIndices = <int>{};

  String? get sessionId => _sessionId;

  void startBook(Book book, {int initialPageIndex = 0}) {
    if (!_sessionEnded) {
      endSession(reason: 'restarted');
    }

    _book = book;
    _sessionId = _sessionIdFactory();
    _sessionStartedAt = _clock();
    _activePageIndex = _clampPageIndex(book, initialPageIndex);
    _bookCompletedTracked = false;
    _sessionEnded = false;
    _speechAttemptSequence = 0;
    _viewedPageIndices.clear();

    _track(
      AnalyticsEventType.readingSessionStarted,
      metadata: {
        'initialPageIndex': _activePageIndex,
        'pageCount': book.pages.length,
      },
    );
    _track(
      AnalyticsEventType.bookStarted,
      metadata: {
        'initialPageIndex': _activePageIndex,
        'pageCount': book.pages.length,
      },
    );
    recordPageViewed(_activePageIndex, source: 'initial');
  }

  void recordPageNavigation(int fromPageIndex, int toPageIndex) {
    final book = _book;
    if (book == null || fromPageIndex == toPageIndex) {
      return;
    }
    final fromPage = _pageAt(book, fromPageIndex);
    final toPage = _pageAt(book, toPageIndex);
    _track(
      AnalyticsEventType.pageInteracted,
      page: fromPage,
      metadata: {
        'interactionType': 'page_navigation',
        'fromPageIndex': fromPageIndex,
        'toPageIndex': toPageIndex,
        if (toPage != null) 'toPageId': toPage.id,
        if (toPage != null) 'toPageNumber': toPage.pageNumber,
      },
    );
  }

  void recordPageViewed(int pageIndex, {String source = 'navigation'}) {
    final book = _book;
    if (book == null || book.pages.isEmpty) {
      return;
    }

    final clampedIndex = _clampPageIndex(book, pageIndex);
    _activePageIndex = clampedIndex;
    _viewedPageIndices.add(clampedIndex);
    final page = _pageAt(book, clampedIndex);
    _track(
      AnalyticsEventType.pageViewed,
      page: page,
      metadata: {
        'pageIndex': clampedIndex,
        'source': source,
        'pageCount': book.pages.length,
      },
    );

    if (clampedIndex == book.pages.length - 1 && !_bookCompletedTracked) {
      _bookCompletedTracked = true;
      _track(
        AnalyticsEventType.bookCompleted,
        page: page,
        metadata: {
          'pageIndex': clampedIndex,
          'pageCount': book.pages.length,
          'viewedPageCount': _viewedPageIndices.length,
        },
      );
    }
  }

  void recordPageInteraction({
    required String interactionType,
    int? pageIndex,
    Map<String, Object?> metadata = const {},
  }) {
    final book = _book;
    if (book == null) {
      return;
    }
    final effectivePageIndex = pageIndex ?? _activePageIndex;
    _track(
      AnalyticsEventType.pageInteracted,
      page: _pageAt(book, effectivePageIndex),
      metadata: {
        'interactionType': interactionType,
        'pageIndex': effectivePageIndex,
        ...metadata,
      },
    );
  }

  void recordNarrationPlayed({int? pageIndex}) {
    recordPageInteraction(
      interactionType: 'narration_toggle',
      pageIndex: pageIndex,
    );
    _trackCurrentPage(
      AnalyticsEventType.narrationPlayed,
      pageIndex: pageIndex,
      metadata: {'pageIndex': pageIndex ?? _activePageIndex},
    );
  }

  void recordSoundscapePlayed({int? pageIndex}) {
    recordPageInteraction(
      interactionType: 'soundscape_toggle',
      pageIndex: pageIndex,
    );
    _trackCurrentPage(
      AnalyticsEventType.soundscapePlayed,
      pageIndex: pageIndex,
      metadata: {'pageIndex': pageIndex ?? _activePageIndex},
    );
  }

  void recordWordAudioPlayed({
    required int wordIndex,
    required String outcome,
    int? pageIndex,
  }) {
    recordPageInteraction(
      interactionType: 'word_tap',
      pageIndex: pageIndex,
      metadata: {'wordIndex': wordIndex},
    );
    _trackCurrentPage(
      AnalyticsEventType.wordAudioPlayed,
      pageIndex: pageIndex,
      metadata: {'wordIndex': wordIndex, 'outcome': outcome},
    );
  }

  void recordPhonemeAudioPlayed({
    required int wordIndex,
    required String outcome,
    int? pageIndex,
  }) {
    recordPageInteraction(
      interactionType: 'word_long_press',
      pageIndex: pageIndex,
      metadata: {'wordIndex': wordIndex},
    );
    _trackCurrentPage(
      AnalyticsEventType.phonemeAudioPlayed,
      pageIndex: pageIndex,
      metadata: {'wordIndex': wordIndex, 'outcome': outcome},
    );
  }

  String? recordSpeechAttemptStarted({int? pageIndex}) {
    final book = _book;
    final sessionId = _sessionId;
    if (book == null || sessionId == null || _sessionEnded) {
      return null;
    }

    final attemptId = '$sessionId-speech-${++_speechAttemptSequence}';
    _trackCurrentPage(
      AnalyticsEventType.speechAttemptStarted,
      pageIndex: pageIndex,
      metadata: {
        'attemptId': attemptId,
        'pageIndex': pageIndex ?? _activePageIndex,
      },
    );
    return attemptId;
  }

  void recordSpeechAttemptCompleted({
    required String? attemptId,
    required String reason,
    required int matchedWordCount,
    required bool hadSpeech,
    int? pageIndex,
  }) {
    if (attemptId == null) {
      return;
    }
    _trackCurrentPage(
      AnalyticsEventType.speechAttemptCompleted,
      pageIndex: pageIndex,
      metadata: {
        'attemptId': attemptId,
        'reason': reason,
        'matchedWordCount': matchedWordCount,
        'hadSpeech': hadSpeech,
      },
    );
  }

  void endSession({String reason = 'dispose'}) {
    final book = _book;
    final sessionId = _sessionId;
    if (book == null || sessionId == null || _sessionEnded) {
      return;
    }

    final startedAt = _sessionStartedAt;
    final durationMs = startedAt == null
        ? null
        : _clock().difference(startedAt).inMilliseconds;
    final eventType = _bookCompletedTracked
        ? AnalyticsEventType.readingSessionEnded
        : AnalyticsEventType.readingSessionDropOff;

    _track(
      eventType,
      page: _pageAt(book, _activePageIndex),
      metadata: {
        'reason': reason,
        'completed': _bookCompletedTracked,
        'lastPageIndex': _activePageIndex,
        'pageCount': book.pages.length,
        'viewedPageCount': _viewedPageIndices.length,
        if (durationMs != null) 'durationMs': durationMs,
      },
    );

    _sessionEnded = true;
  }

  void _trackCurrentPage(
    AnalyticsEventType eventType, {
    int? pageIndex,
    Map<String, Object?> metadata = const {},
  }) {
    final book = _book;
    if (book == null) {
      return;
    }
    _track(
      eventType,
      page: _pageAt(book, pageIndex ?? _activePageIndex),
      metadata: metadata,
    );
  }

  void _track(
    AnalyticsEventType eventType, {
    PageData? page,
    Map<String, Object?> metadata = const {},
  }) {
    final book = _book;
    final sessionId = _sessionId;
    if (book == null || sessionId == null) {
      return;
    }

    try {
      unawaited(
        _analyticsRepository
            .track(
              eventType,
              bookId: book.id,
              pageId: page?.id,
              pageNumber: page?.pageNumber,
              sessionId: sessionId,
              metadata: metadata,
            )
            .catchError((Object _) => false),
      );
    } catch (_) {
      // Analytics must never interrupt reader interactions.
    }
  }

  static int _clampPageIndex(Book book, int pageIndex) {
    if (book.pages.isEmpty) {
      return 0;
    }
    return pageIndex.clamp(0, book.pages.length - 1);
  }

  static PageData? _pageAt(Book book, int pageIndex) {
    if (book.pages.isEmpty) {
      return null;
    }
    return book.pages[_clampPageIndex(book, pageIndex)];
  }

  static String _defaultSessionId() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entropy = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'reader-$timestamp-$entropy';
  }
}
