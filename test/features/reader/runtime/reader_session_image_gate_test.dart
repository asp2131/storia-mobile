import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/audio/page_audio.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session_impl.dart';

void main() {
  group('ReaderSessionImpl gates audio on illustration readiness', () {
    test('holds loadPage until the image-ready probe completes', () async {
      final probe = Completer<void>();
      final pageAudio = _FakePageAudio();
      final session = ReaderSessionImpl(
        pageAudio: pageAudio,
        speechPort: _FakeSpeechPracticePort(),
        scheduler: _FakeSchedulerPort(),
        imageReadyProbe: (_) => probe.future,
      );
      addTearDown(session.dispose);

      unawaited(session.dispatch(ReaderStart(book: _book)));
      await pumpEventQueue();
      expect(
        pageAudio.loadPageCalls,
        0,
        reason: 'audio must not start before the illustration is ready',
      );

      probe.complete();
      await pumpEventQueue();
      expect(pageAudio.loadPageCalls, 1);
    });

    test('a stale page flip cancels the pending audio load', () async {
      final firstProbe = Completer<void>();
      final pageAudio = _FakePageAudio();
      final session = ReaderSessionImpl(
        pageAudio: pageAudio,
        speechPort: _FakeSpeechPracticePort(),
        scheduler: _FakeSchedulerPort(),
        // Every page resolves immediately except the first, which we stall.
        imageReadyProbe: (url) =>
            url == _book.pages.first.imageUrl ? firstProbe.future : Future.value(),
      );
      addTearDown(session.dispose);

      unawaited(session.dispatch(ReaderStart(book: _book)));
      await pumpEventQueue();
      await session.dispatch(const ReaderGoToPage(1));
      await pumpEventQueue();

      // Page 1 loaded; now release the stale page-0 probe.
      firstProbe.complete();
      await pumpEventQueue();

      expect(pageAudio.loadedPageIds, ['page-2']);
    });
  });
}

final _book = Book(
  id: 'book-1',
  title: 'Test Book',
  pageCount: 2,
  pages: const [
    PageData(
      id: 'page-1',
      pageNumber: 1,
      textContent: 'hello world',
      imageUrl: 'https://example.test/1.png',
    ),
    PageData(
      id: 'page-2',
      pageNumber: 2,
      textContent: 'goodbye world',
      imageUrl: 'https://example.test/2.png',
    ),
  ],
);

class _FakePageAudio implements PageAudio {
  final _statesController = StreamController<AudioSnapshot>.broadcast();
  int loadPageCalls = 0;
  final List<String> loadedPageIds = [];

  @override
  Stream<AudioSnapshot> get states => _statesController.stream;

  @override
  Future<void> loadPage(PageData page) async {
    loadPageCalls++;
    loadedPageIds.add(page.id);
  }

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
