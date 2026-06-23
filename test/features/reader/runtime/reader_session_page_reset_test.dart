import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/audio/page_audio.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session_impl.dart';

void main() {
  group('ReaderSessionImpl page-index lifecycle', () {
    late ReaderSessionImpl session;

    setUp(() {
      session = ReaderSessionImpl(
        pageAudio: _FakePageAudio(),
        speechPort: _FakeSpeechPracticePort(),
        scheduler: _FakeSchedulerPort(),
      );
    });

    tearDown(() async {
      await session.dispose();
    });

    test('replays page 0 to a new subscriber after the session ends', () async {
      await session.dispatch(ReaderStart(book: _book));
      await session.dispatch(const ReaderGoToPage(2));
      await pumpEventQueue();
      expect((await session.states.first).activePageIndex, 2);

      await session.dispatch(const ReaderEnd(reason: 'screen_dispose'));
      await pumpEventQueue();

      expect((await session.states.first).activePageIndex, 0);
    });
  });
}

final _book = Book(
  id: 'book-1',
  title: 'Test Book',
  pageCount: 3,
  pages: const [
    PageData(id: 'page-1', pageNumber: 1, textContent: 'hello world'),
    PageData(id: 'page-2', pageNumber: 2, textContent: 'goodbye world'),
    PageData(id: 'page-3', pageNumber: 3, textContent: 'the end'),
  ],
);

class _FakePageAudio implements PageAudio {
  final _statesController = StreamController<AudioSnapshot>.broadcast();

  @override
  Stream<AudioSnapshot> get states => _statesController.stream;

  @override
  Future<void> loadPage(PageData page) async {}

  @override
  Future<void> toggleNarration() async {}

  @override
  Future<void> toggleSoundscape() async {}

  @override
  Future<void> setNarrationVolume(double volume) async {}

  @override
  Future<void> setSoundscapeVolume(double volume) async {}

  @override
  Future<void> duckForPractice() async {}

  @override
  Future<void> restoreFromPractice() async {}

  @override
  Future<void> stopAll() async {}
}

class _FakeSpeechPracticePort implements SpeechPracticePort {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
    onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeSchedulerPort implements SchedulerPort {
  @override
  CancelableTask schedule(Duration delay, void Function() action) {
    return _FakeCancelableTask();
  }
}

class _FakeCancelableTask implements CancelableTask {
  @override
  void cancel() {}
}
