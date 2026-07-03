import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/page_audio.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:loratone/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:loratone/src/features/reader/runtime/reader_session.dart';
import 'package:loratone/src/features/reader/runtime/reader_session_impl.dart';

final _book = Book(
  id: 'b1',
  title: 'T',
  pageCount: 1,
  pages: const [PageData(id: 'p1', pageNumber: 1, textContent: 'hello world')],
);

void main() {
  test('ReaderPauseNarration / ReaderResumeNarration are state-guarded', () async {
    final audio = _CountingPageAudio();
    final session = ReaderSessionImpl(
      pageAudio: audio,
      speechPort: _FakeSpeechPracticePort(),
      scheduler: _FakeSchedulerPort(),
    );

    await session.dispatch(ReaderStart(book: _book));
    await session.dispatch(const ReaderToggleNarration());
    expect(audio.toggleNarrationCalls, 1);

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2);
    expect((await session.states.first).isNarrationPlaying, isFalse);

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2);

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3);
    expect((await session.states.first).isNarrationPlaying, isTrue);

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3);

    await session.dispose();
  });
}

class _CountingPageAudio implements PageAudio {
  final _statesController = StreamController<AudioSnapshot>.broadcast();
  int toggleNarrationCalls = 0;

  @override
  Stream<AudioSnapshot> get states => _statesController.stream;

  @override
  Future<void> loadPage(PageData page) async {}

  @override
  Future<void> toggleNarration() async {
    toggleNarrationCalls++;
  }

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
  CancelableTask schedule(Duration delay, void Function() action) =>
      _FakeCancelableTask();
}

class _FakeCancelableTask implements CancelableTask {
  @override
  void cancel() {}
}
