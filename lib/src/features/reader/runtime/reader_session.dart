import 'reader_intent.dart';
import 'reader_view_state.dart';

abstract interface class ReaderSession {
  Stream<ReaderViewState> get states;

  Future<void> dispatch(ReaderIntent intent);

  Future<void> dispose();
}
