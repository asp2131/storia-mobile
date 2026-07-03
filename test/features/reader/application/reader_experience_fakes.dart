import 'dart:async';

import 'package:loratone/src/features/reader/application/reader_experience_effects.dart';
import 'package:loratone/src/features/reader/runtime/reader_session.dart';
import 'package:loratone/src/features/reader/runtime/word_help/reader_word_help.dart';

class FakeReaderSession implements ReaderSession {
  final intents = <ReaderIntent>[];
  final _states = StreamController<ReaderViewState>.broadcast();
  final _pageChanges = StreamController<int>.broadcast();
  bool disposed = false;

  @override
  Stream<ReaderViewState> get states => _states.stream;

  @override
  Stream<int> get pageChanges => _pageChanges.stream;

  void emitState(ReaderViewState state) => _states.add(state);

  void emitPageChange(int pageIndex) => _pageChanges.add(pageIndex);

  @override
  Future<void> dispatch(ReaderIntent intent) async {
    intents.add(intent);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _states.close();
    await _pageChanges.close();
  }
}

class FakeReaderWordHelp implements ReaderWordHelp {
  final requests = <WordHelpRequest>[];
  final cancelReasons = <WordHelpCancelReason>[];
  final _snapshots = StreamController<WordHelpSnapshot>.broadcast();
  WordHelpSnapshot _snapshot = const WordHelpSnapshot.idle();
  WordHelpResult result = const WordHelpResult(
    outcome: WordHelpOutcome.pronunciationPlayed,
  );
  bool disposed = false;

  @override
  WordHelpSnapshot get snapshot => _snapshot;

  @override
  Stream<WordHelpSnapshot> get snapshots => _snapshots.stream;

  void emitSnapshot(WordHelpSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  Future<WordHelpResult> play(WordHelpRequest request) async {
    requests.add(request);
    return result;
  }

  @override
  Future<void> cancel({required WordHelpCancelReason reason}) async {
    cancelReasons.add(reason);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _snapshots.close();
  }
}

class FakeReaderExperienceEffects implements ReaderExperienceEffects {
  int playCelebrationCount = 0;
  int stopCelebrationCount = 0;
  int disposeCount = 0;

  @override
  Future<void> playCelebration() async {
    playCelebrationCount += 1;
  }

  @override
  Future<void> stopCelebration() async {
    stopCelebrationCount += 1;
  }

  @override
  void dispose() {
    disposeCount += 1;
  }
}
