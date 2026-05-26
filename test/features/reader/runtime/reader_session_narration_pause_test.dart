import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/audio_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session_impl.dart';

final _book = Book(
  id: 'b1',
  title: 'T',
  pageCount: 1,
  pages: const [PageData(id: 'p1', pageNumber: 1, textContent: 'hello world')],
);

void main() {
  test('ReaderPauseNarration / ReaderResumeNarration are state-guarded', () async {
    final audio = _CountingAudioPort();
    final session = ReaderSessionImpl(
      audioPort: audio,
      speechPort: _FakeSpeechPracticePort(),
      scheduler: _FakeSchedulerPort(),
    );

    await session.dispatch(ReaderStart(book: _book));
    // Turn narration on (toggle from initial false).
    await session.dispatch(const ReaderToggleNarration());
    expect(audio.toggleNarrationCalls, 1);

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2); // was playing -> paused

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2); // already paused -> no-op

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3); // was paused -> resumed

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3); // already playing -> no-op

    await session.dispose();
  });
}

class _CountingAudioPort implements AudioPort {
  final _narrationPosition = StreamController<Duration>.broadcast();
  final _narrationPlaying = StreamController<bool>.broadcast();
  final _soundscapePlaying = StreamController<bool>.broadcast();
  int toggleNarrationCalls = 0;

  @override
  Stream<Duration> get narrationPosition => _narrationPosition.stream;
  @override
  Stream<bool> get narrationPlaying => _narrationPlaying.stream;
  @override
  Stream<bool> get soundscapePlaying => _soundscapePlaying.stream;
  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> loadPage(PageData page) async {}
  @override
  Future<void> transitionToPage(PageData page) async {}
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
  Future<void> dispose() async {
    await _narrationPosition.close();
    await _narrationPlaying.close();
    await _soundscapePlaying.close();
  }
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
