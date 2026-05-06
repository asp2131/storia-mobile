import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/data/providers.dart';
import 'package:storia_kids/src/features/reader/reader_screen.dart';
import 'package:storia_kids/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:storia_kids/src/features/reader/runtime/providers/reader_word_help_provider.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/word_help/reader_word_help.dart';

void main() {
  testWidgets(
    'audio controls remain draggable after navigating past first page',
    (tester) async {
      final session = _FakeReaderSession();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentBookProvider(
              _book.id,
            ).overrideWith((ref) => Future.value(_book)),
            bookManifestProvider(
              _book.id,
            ).overrideWith((ref) => Future.value(null)),
            readerSessionProvider.overrideWithValue(session),
            readerWordHelpProvider.overrideWith(
              _FakeReaderWordHelpController.new,
            ),
          ],
          child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final handle = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Move audio controls',
      );
      expect(handle, findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(session.activePageIndex, 1);

      final before = tester.getCenter(handle);
      await tester.dragFrom(
        before + const Offset(42, 0),
        const Offset(64, -72),
      );
      await tester.pump();
      final after = tester.getCenter(handle);

      expect(after.dx, greaterThan(before.dx + 40));
      expect(after.dy, lessThan(before.dy - 40));
    },
  );
}

const _book = Book(
  id: 'book-1',
  title: 'Reader Drag Regression',
  pageCount: 2,
  pages: [
    PageData(
      id: 'page-1',
      pageNumber: 1,
      textContent: 'First page',
      imageUrl: 'memory://page-1.png',
      narrationUrl: 'memory://page-1.mp3',
      soundscapeUrl: 'memory://page-1.wav',
    ),
    PageData(
      id: 'page-2',
      pageNumber: 2,
      textContent: 'Second page',
      imageUrl: 'memory://page-2.png',
      narrationUrl: 'memory://page-2.mp3',
      soundscapeUrl: 'memory://page-2.wav',
    ),
  ],
);

class _FakeReaderSession implements ReaderSession {
  final _states = StreamController<ReaderViewState>.broadcast();
  final _pageChanges = StreamController<int>.broadcast();
  ReaderViewState _state = const ReaderViewState.initial();

  int get activePageIndex => _state.activePageIndex;

  @override
  Stream<ReaderViewState> get states => _states.stream;

  @override
  Stream<int> get pageChanges => _pageChanges.stream;

  @override
  Future<void> dispatch(ReaderIntent intent) async {
    switch (intent) {
      case ReaderStart(:final initialPageIndex):
        _emit(
          _state.copyWith(isReady: true, activePageIndex: initialPageIndex),
        );
      case ReaderGoToPage(:final pageIndex):
        _emit(_state.copyWith(activePageIndex: pageIndex));
        _pageChanges.add(pageIndex);
      case ReaderEnd():
        break;
      case ReaderToggleNarration():
      case ReaderToggleSoundscape():
      case ReaderSetNarrationVolume():
      case ReaderSetSoundscapeVolume():
      case ReaderPracticePrimaryAction():
      case ReaderPauseListening():
      case ReaderResumeListening():
      case ReaderAckCelebration():
        break;
    }
  }

  void _emit(ReaderViewState next) {
    _state = next;
    _states.add(next);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _pageChanges.close();
  }
}

class _FakeReaderWordHelpController extends ReaderWordHelpController {
  @override
  WordHelpSnapshot build(String bookId) => const WordHelpSnapshot.idle();

  @override
  Future<WordHelpResult> play(WordHelpRequest request) async {
    return const WordHelpResult(outcome: WordHelpOutcome.fallbackPlayed);
  }

  @override
  Future<void> cancel({
    WordHelpCancelReason reason = WordHelpCancelReason.user,
  }) async {}
}
