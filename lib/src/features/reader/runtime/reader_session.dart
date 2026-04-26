import 'reader_intent.dart';
import 'reader_view_state.dart';

abstract interface class ReaderSession {
  Stream<ReaderViewState> get states;

  /// Emits the active page index whenever the reader transitions to a new
  /// page. Useful for cancelling per-page work (e.g. pronunciation playback).
  Stream<int> get pageChanges;

  Future<void> dispatch(ReaderIntent intent);

  Future<void> dispose();
}
