import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/narration_studio/application/narration_recorder.dart';
import 'package:loratone/src/features/narration_studio/application/recording_controller.dart';
import 'package:loratone/src/features/narration_studio/data/narration_repository.dart';
import 'package:loratone/src/features/narration_studio/domain/narration_track.dart';

class _FakeRecorder implements NarrationRecorder {
  _FakeRecorder(this.directory);

  final Directory directory;
  bool permission = true;
  bool startThrows = false;
  bool stopReturnsNothing = false;
  File? lastStarted;
  int disposeCalls = 0;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<File> start(String fileNameHint) async {
    if (startThrows) throw Exception('mic busy');
    final file = File('${directory.path}/$fileNameHint.m4a')
      ..writeAsStringSync('audio');
    lastStarted = file;
    return file;
  }

  @override
  Future<File?> stop() async => stopReturnsNothing ? null : lastStarted;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async => disposeCalls++;
}

class _FakeRepository implements NarrationRepository {
  int createCalls = 0;
  int uploadCalls = 0;
  int readyCalls = 0;
  Object? uploadError;
  Object? readyError;

  @override
  Future<NarrationTrack> createTrack({
    required String bookId,
    required String label,
  }) async {
    createCalls++;
    return NarrationTrack(
      id: 'track-1',
      bookId: bookId,
      label: label,
      isReady: false,
      pages: const [],
    );
  }

  @override
  Future<NarrationPageRecording> uploadPageRecording({
    required String trackId,
    required int pageNumber,
    required File audioFile,
    required Duration duration,
    String contentType = 'audio/mp4',
  }) async {
    uploadCalls++;
    if (uploadError != null) throw uploadError!;
    return NarrationPageRecording(
      pageId: 'page-$pageNumber',
      pageNumber: pageNumber,
      audioUrl: 'https://cdn.test/$pageNumber.m4a',
      wordTimestamps: const [],
      wordCount: 4,
      alignment: NarrationAlignment.aligned,
    );
  }

  @override
  Future<NarrationTrack> setTrackReady(String trackId) async {
    readyCalls++;
    if (readyError != null) throw readyError!;
    return NarrationTrack(
      id: trackId,
      bookId: 'book-1',
      label: 'Mom',
      isReady: true,
      pages: const [],
    );
  }

  @override
  Future<void> deleteTrack(String trackId) async {}

  @override
  Future<List<NarrationTrack>> getTracksForBook(String bookId) async => const [];
}

void main() {
  late Directory tempDir;
  late _FakeRecorder recorder;
  late _FakeRepository repository;

  NarrationStudioController build({
    List<int> recordable = const [1, 2],
    List<int> textless = const [3],
  }) => NarrationStudioController(
    repository: repository,
    recorder: recorder,
    bookId: 'book-1',
    recordablePageNumbers: recordable,
    textlessPageNumbers: textless,
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('narration_test');
    recorder = _FakeRecorder(tempDir);
    repository = _FakeRepository();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('marks textless pages as skipped and excludes them from remaining', () {
    final controller = build();

    expect(controller.value.pageAt(3)!.status, PageRecordingStatus.skipped);
    expect(controller.value.remainingCount, 2);
    expect(controller.value.recordablePages, hasLength(2));
  });

  test('walks idle → recording → previewing → uploading → ready', () async {
    final controller = build();

    await controller.startRecording(1);
    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.recording);

    await controller.stopRecording();
    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.previewing);
    expect(controller.value.pageAt(1)!.localFile, isNotNull);

    await controller.keepAndUpload(1, label: 'Mom');
    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.ready);
    expect(controller.value.pageAt(1)!.recording, isNotNull);
    expect(controller.value.readyCount, 1);
  });

  test('creates the track once, lazily, on the first upload', () async {
    final controller = build();
    expect(controller.value.trackId, isNull);
    expect(repository.createCalls, 0);

    for (final page in [1, 2]) {
      await controller.startRecording(page);
      await controller.stopRecording();
      await controller.keepAndUpload(page, label: 'Mom');
    }

    expect(repository.createCalls, 1);
    expect(controller.value.trackId, 'track-1');
    expect(controller.value.isComplete, isTrue);
  });

  test('deletes the local take once the server has it', () async {
    final controller = build();

    await controller.startRecording(1);
    await controller.stopRecording();
    final file = controller.value.pageAt(1)!.localFile!;

    await controller.keepAndUpload(1, label: 'Mom');

    expect(file.existsSync(), isFalse);
    expect(controller.value.pageAt(1)!.localFile, isNull);
  });

  test('keeps the local take when the upload fails, so it can be retried', () async {
    final controller = build();
    repository.uploadError = const NarrationRepositoryException(
      'boom',
      statusCode: 500,
    );

    await controller.startRecording(1);
    await controller.stopRecording();
    final file = controller.value.pageAt(1)!.localFile!;
    await controller.keepAndUpload(1, label: 'Mom');

    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.failed);
    expect(file.existsSync(), isTrue);
    expect(controller.value.pageAt(1)!.errorMessage, contains('try again'));

    repository.uploadError = null;
    await controller.retryUpload(1, label: 'Mom');

    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.ready);
    expect(repository.uploadCalls, 2);
  });

  test('surfaces auth failures with a sign-in hint', () async {
    final controller = build();
    repository.uploadError = const NarrationRepositoryException(
      'nope',
      statusCode: 401,
    );

    await controller.startRecording(1);
    await controller.stopRecording();
    await controller.keepAndUpload(1, label: 'Mom');

    expect(controller.value.pageAt(1)!.errorMessage, contains('sign in'));
  });

  test('retake discards the local file and resets the page', () async {
    final controller = build();

    await controller.startRecording(1);
    await controller.stopRecording();
    final file = controller.value.pageAt(1)!.localFile!;

    await controller.retake(1);

    expect(file.existsSync(), isFalse);
    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.notRecorded);
    expect(controller.value.pageAt(1)!.localFile, isNull);
  });

  test('refuses to record without microphone permission', () async {
    final controller = build();
    recorder.permission = false;

    final started = await controller.startRecording(1);

    expect(started, isFalse);
    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.notRecorded);
    expect(controller.value.errorMessage, contains('Microphone'));
  });

  test('reports a failed recorder start without changing page status', () async {
    final controller = build();
    recorder.startThrows = true;

    final started = await controller.startRecording(1);

    expect(started, isFalse);
    expect(controller.value.errorMessage, contains('Could not start'));
  });

  test('handles a stop that captured nothing', () async {
    final controller = build();
    recorder.stopReturnsNothing = true;

    await controller.startRecording(1);
    await controller.stopRecording();

    expect(controller.value.pageAt(1)!.status, PageRecordingStatus.notRecorded);
    expect(controller.value.pageAt(1)!.errorMessage, contains('Nothing was recorded'));
  });

  test('finish marks the track ready', () async {
    final controller = build();

    await controller.startRecording(1);
    await controller.stopRecording();
    await controller.keepAndUpload(1, label: 'Mom');

    expect(await controller.finish(), isTrue);
    expect(repository.readyCalls, 1);
    expect(controller.value.isFinishing, isFalse);
  });

  test('finish is a no-op before any track exists', () async {
    final controller = build();

    expect(await controller.finish(), isFalse);
    expect(repository.readyCalls, 0);
  });

  test('finish surfaces failure without stranding the finishing flag', () async {
    final controller = build();
    await controller.startRecording(1);
    await controller.stopRecording();
    await controller.keepAndUpload(1, label: 'Mom');

    repository.readyError = const NarrationRepositoryException('no', statusCode: 500);

    expect(await controller.finish(), isFalse);
    expect(controller.value.isFinishing, isFalse);
    expect(controller.value.errorMessage, isNotNull);
  });

  test('resuming a draft track seeds the pages it already recorded', () {
    final controller = NarrationStudioController(
      repository: repository,
      recorder: recorder,
      bookId: 'book-1',
      recordablePageNumbers: const [1, 2, 3],
      textlessPageNumbers: const [],
      existingTrack: const NarrationTrack(
        id: 'track-9',
        bookId: 'book-1',
        label: 'Dad',
        isReady: false,
        pages: [
          NarrationPageRecording(
            pageId: 'p1',
            pageNumber: 1,
            audioUrl: 'https://cdn/p1.m4a',
            wordTimestamps: [],
            wordCount: 4,
            alignment: NarrationAlignment.aligned,
          ),
        ],
      ),
    );

    expect(controller.value.trackId, 'track-9');
    expect(controller.value.trackLabel, 'Dad');
    expect(controller.value.pageAt(1)?.status, PageRecordingStatus.ready);
    expect(controller.value.pageAt(2)?.status, PageRecordingStatus.notRecorded);
    expect(controller.value.remainingCount, 2);
  });
}
