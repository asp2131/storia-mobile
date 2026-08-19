import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/analytics_repository.dart';
import '../data/narration_repository.dart';
import '../domain/narration_track.dart';
import 'narration_recorder.dart';

/// Where one page sits in the record → keep → upload → aligned flow.
enum PageRecordingStatus {
  notRecorded,
  recording,

  /// Captured locally, waiting for the adult to keep or retake it.
  previewing,

  uploading,
  ready,
  failed,

  /// Image-only page — nothing to read aloud.
  skipped,
}

@immutable
class PageRecordingState {
  const PageRecordingState({
    required this.pageNumber,
    required this.status,
    this.localFile,
    this.duration = Duration.zero,
    this.recording,
    this.errorMessage,
  });

  final int pageNumber;
  final PageRecordingStatus status;

  /// Kept until the server confirms the upload, so a dropped request is
  /// retryable rather than a lost take.
  final File? localFile;

  final Duration duration;
  final NarrationPageRecording? recording;
  final String? errorMessage;

  bool get needsRetakeNudge =>
      recording != null && !recording!.alignment.isReliable;

  PageRecordingState copyWith({
    PageRecordingStatus? status,
    File? localFile,
    Duration? duration,
    NarrationPageRecording? recording,
    String? errorMessage,
    bool clearError = false,
    bool clearLocalFile = false,
  }) {
    return PageRecordingState(
      pageNumber: pageNumber,
      status: status ?? this.status,
      localFile: clearLocalFile ? null : (localFile ?? this.localFile),
      duration: duration ?? this.duration,
      recording: recording ?? this.recording,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

@immutable
class NarrationStudioState {
  const NarrationStudioState({
    required this.pages,
    this.trackId,
    this.trackLabel,
    this.isFinishing = false,
    this.errorMessage,
  });

  final List<PageRecordingState> pages;
  final String? trackId;
  final String? trackLabel;
  final bool isFinishing;
  final String? errorMessage;

  PageRecordingState? pageAt(int pageNumber) {
    for (final page in pages) {
      if (page.pageNumber == pageNumber) return page;
    }
    return null;
  }

  Iterable<PageRecordingState> get recordablePages =>
      pages.where((p) => p.status != PageRecordingStatus.skipped);

  int get readyCount =>
      pages.where((p) => p.status == PageRecordingStatus.ready).length;

  int get remainingCount => recordablePages
      .where((p) => p.status != PageRecordingStatus.ready)
      .length;

  bool get isComplete => remainingCount == 0 && readyCount > 0;

  NarrationStudioState copyWith({
    List<PageRecordingState>? pages,
    String? trackId,
    String? trackLabel,
    bool? isFinishing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NarrationStudioState(
      pages: pages ?? this.pages,
      trackId: trackId ?? this.trackId,
      trackLabel: trackLabel ?? this.trackLabel,
      isFinishing: isFinishing ?? this.isFinishing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives the page-by-page recording session.
///
/// Deliberately dumb about UI: the screen renders [state] and calls the verbs.
class NarrationStudioController extends ValueNotifier<NarrationStudioState> {
  NarrationStudioController({
    required NarrationRepository repository,
    required NarrationRecorder recorder,
    required String bookId,
    required List<int> recordablePageNumbers,
    required List<int> textlessPageNumbers,
    NarrationTrack? existingTrack,
    AnalyticsRepository? analytics,
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _recorder = recorder,
       _bookId = bookId,
       _analytics = analytics,
       _now = now,
       super(
         NarrationStudioState(
           trackId: existingTrack?.id,
           trackLabel: existingTrack?.label,
           pages: [
             for (final pageNumber in [
               ...recordablePageNumbers,
               ...textlessPageNumbers,
             ]..sort())
               PageRecordingState(
                 pageNumber: pageNumber,
                 // Resuming a draft: pages the adult already kept come back as
                 // ready, so the session picks up where it stopped instead of
                 // asking for every page again.
                 status: textlessPageNumbers.contains(pageNumber)
                     ? PageRecordingStatus.skipped
                     : existingTrack?.pageFor(pageNumber) != null
                     ? PageRecordingStatus.ready
                     : PageRecordingStatus.notRecorded,
                 recording: existingTrack?.pageFor(pageNumber),
               ),
           ],
         ),
       );

  final NarrationRepository _repository;
  final NarrationRecorder _recorder;
  final String _bookId;
  final AnalyticsRepository? _analytics;
  final DateTime Function() _now;

  DateTime? _startedAt;
  int? _activePageNumber;

  void _updatePage(
    int pageNumber,
    PageRecordingState Function(PageRecordingState) update,
  ) {
    value = value.copyWith(
      pages: [
        for (final page in value.pages)
          if (page.pageNumber == pageNumber) update(page) else page,
      ],
    );
  }

  /// Creates the track lazily so an abandoned session leaves no empty rows.
  Future<String> _ensureTrack(String label) async {
    final existing = value.trackId;
    if (existing != null) return existing;

    final track = await _repository.createTrack(bookId: _bookId, label: label);
    value = value.copyWith(trackId: track.id, trackLabel: track.label);
    return track.id;
  }

  Future<bool> startRecording(int pageNumber) async {
    if (!await _recorder.hasPermission()) {
      value = value.copyWith(
        errorMessage: 'Microphone access is needed to record your voice.',
      );
      return false;
    }

    try {
      final file = await _recorder.start('page_$pageNumber');
      _startedAt = _now();
      _emit(
        AnalyticsEventType.narrationRecordingStarted,
        pageNumber: pageNumber,
      );
      _activePageNumber = pageNumber;

      _updatePage(
        pageNumber,
        (page) => page.copyWith(
          status: PageRecordingStatus.recording,
          localFile: file,
          duration: Duration.zero,
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      value = value.copyWith(errorMessage: 'Could not start recording: $error');
      return false;
    }
  }

  Future<void> stopRecording() async {
    final pageNumber = _activePageNumber;
    if (pageNumber == null) return;

    final file = await _recorder.stop();
    final startedAt = _startedAt;
    final duration = startedAt == null
        ? Duration.zero
        : _now().difference(startedAt);

    _startedAt = null;
    _activePageNumber = null;

    _updatePage(
      pageNumber,
      (page) => file == null
          ? page.copyWith(
              status: PageRecordingStatus.notRecorded,
              errorMessage: 'Nothing was recorded. Try again.',
              clearLocalFile: true,
            )
          : page.copyWith(
              status: PageRecordingStatus.previewing,
              localFile: file,
              duration: duration,
            ),
    );
  }

  /// Discards the local take and returns the page to its unrecorded state.
  Future<void> retake(int pageNumber) async {
    final page = value.pageAt(pageNumber);
    final file = page?.localFile;

    if (file != null && await file.exists()) {
      await file.delete();
    }

    _updatePage(
      pageNumber,
      (page) => page.copyWith(
        status: PageRecordingStatus.notRecorded,
        duration: Duration.zero,
        clearLocalFile: true,
        clearError: true,
      ),
    );
  }

  /// Uploads the kept take. Safe to call again after a failure — the local file
  /// is only deleted once the server has the recording.
  Future<void> keepAndUpload(int pageNumber, {required String label}) async {
    final page = value.pageAt(pageNumber);
    final file = page?.localFile;
    if (page == null || file == null) return;

    _updatePage(
      pageNumber,
      (page) => page.copyWith(
        status: PageRecordingStatus.uploading,
        clearError: true,
      ),
    );

    try {
      final trackId = await _ensureTrack(label);
      final recording = await _repository.uploadPageRecording(
        trackId: trackId,
        pageNumber: pageNumber,
        audioFile: file,
        duration: page.duration,
      );

      if (await file.exists()) {
        await file.delete();
      }

      _updatePage(
        pageNumber,
        (page) => page.copyWith(
          status: PageRecordingStatus.ready,
          recording: recording,
          clearLocalFile: true,
        ),
      );

      _emit(
        AnalyticsEventType.narrationPageRecorded,
        pageNumber: pageNumber,
        metadata: {
          'alignment': recording.alignment.name,
          'durationMs': page.duration.inMilliseconds,
        },
      );
      if (!recording.alignment.isReliable) {
        _emit(
          AnalyticsEventType.narrationAlignmentFallback,
          pageNumber: pageNumber,
          metadata: {'alignment': recording.alignment.name},
        );
      }
    } catch (error) {
      _updatePage(
        pageNumber,
        (page) => page.copyWith(
          status: PageRecordingStatus.failed,
          errorMessage: _readableError(error),
        ),
      );
    }
  }

  Future<void> retryUpload(int pageNumber, {required String label}) {
    _updatePage(
      pageNumber,
      (page) => page.copyWith(
        status: PageRecordingStatus.previewing,
        clearError: true,
      ),
    );
    return keepAndUpload(pageNumber, label: label);
  }

  /// Marks the track ready so it appears in the reader's voice picker.
  Future<bool> finish() async {
    final trackId = value.trackId;
    if (trackId == null) return false;

    value = value.copyWith(isFinishing: true, clearError: true);
    try {
      await _repository.setTrackReady(trackId);
      value = value.copyWith(isFinishing: false);
      _emit(
        AnalyticsEventType.narrationTrackCompleted,
        metadata: {
          'pagesRecorded': value.readyCount,
          'pagesSkipped': value.remainingCount,
        },
      );
      return true;
    } catch (error) {
      value = value.copyWith(
        isFinishing: false,
        errorMessage: _readableError(error),
      );
      return false;
    }
  }

  /// Fire-and-forget: instrumentation must never fail a recording.
  void _emit(
    AnalyticsEventType type, {
    int? pageNumber,
    Map<String, Object?> metadata = const {},
  }) {
    final analytics = _analytics;
    if (analytics == null) return;
    unawaited(
      analytics.track(
        type,
        bookId: _bookId,
        pageNumber: pageNumber,
        metadata: metadata,
      ),
    );
  }

  String _readableError(Object error) {
    if (error is NarrationRepositoryException) {
      return switch (error.statusCode) {
        401 || 403 => 'Please sign in again to save this recording.',
        413 => 'That recording is too long for one page.',
        415 => 'That audio format is not supported.',
        _ => 'Saving failed. Tap to try again.',
      };
    }
    return 'Saving failed. Tap to try again.';
  }

  @override
  void dispose() {
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
