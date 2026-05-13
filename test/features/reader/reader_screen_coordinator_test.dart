import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/data/providers.dart';
import 'package:storia_kids/src/features/reader/application/reader_experience_controller.dart';
import 'package:storia_kids/src/features/reader/application/reader_experience_effects.dart';
import 'package:storia_kids/src/features/reader/reader_screen.dart';
import 'package:storia_kids/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/word_help/reader_word_help.dart';

void main() {
  testWidgets('ReaderScreen routes start and controls through coordinator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final coordinatorLog = _CoordinatorLog();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentBookProvider('book-1').overrideWith((ref) async => _book),
          bookManifestProvider('book-1').overrideWith((ref) async => null),
          readerSessionProvider.overrideWith((ref) => _FakeReaderSession()),
          readerExperienceControllerProvider.overrideWith(
            () => _FakeReaderExperienceControllerNotifier._(
              coordinatorLog,
              'book-1',
            ),
          ),
          readerExperienceEffectsProvider.overrideWith(
            (ref) => const NoopReaderExperienceEffects(),
          ),
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(coordinatorLog.actions, hasLength(1));
    expect(coordinatorLog.actions.single, isA<ReaderExperienceStart>());

    // Tap the narration icon (headphones icon) inside the pill.
    await tester.tap(find.byIcon(Icons.headphones_rounded));
    // Do NOT pumpAndSettle — it triggers AnimatedOpacity which calls
    // pause() on the GifPlayerController after dispose during test teardown.
    await tester.pump();
    await tester.pump();

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceToggleNarration>(),
      hasLength(1),
    );
  });

  testWidgets('ReaderScreen keeps book-not-found flow outside coordinator', (
    tester,
  ) async {
    final coordinatorLog = _CoordinatorLog();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentBookProvider('missing').overrideWith((ref) async => null),
          readerSessionProvider.overrideWith((ref) => _FakeReaderSession()),
          readerExperienceControllerProvider.overrideWith(
            () => _FakeReaderExperienceControllerNotifier._(
              coordinatorLog,
              'missing',
            ),
          ),
          readerExperienceEffectsProvider.overrideWith(
            (ref) => const NoopReaderExperienceEffects(),
          ),
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'missing')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Book not found'), findsOneWidget);
    expect(coordinatorLog.actions, isEmpty);
  });
}

class _CoordinatorLog {
  final actions = <ReaderExperienceAction>[];
  final lifecycleStates = <AppLifecycleState>[];
  final narrationPositionListenable = ValueNotifier<Duration>(Duration.zero);
  final scrollOffsetListenable = ValueNotifier<double>(0.0);
}

class _FakeReaderSession implements ReaderSession {
  @override
  Stream<ReaderViewState> get states => const Stream.empty();

  @override
  Stream<int> get pageChanges => const Stream.empty();

  @override
  Future<void> dispatch(ReaderIntent intent) async {}

  @override
  Future<void> dispose() async {}
}

class _FakeReaderExperienceControllerNotifier
    extends ReaderExperienceControllerNotifier {
  _FakeReaderExperienceControllerNotifier._(
    this.log,
    String bookId,
  );

  final _CoordinatorLog log;

  @override
  ValueListenable<Duration> get narrationPositionListenable =>
      log.narrationPositionListenable;

  @override
  ValueListenable<double> get scrollOffsetListenable =>
      log.scrollOffsetListenable;

  @override
  ReaderExperienceState build(String bookId) {
    return ReaderExperienceState(
      readerState: ReaderViewState(
        isReady: true,
        activePageIndex: 0,
        isNarrationPlaying: false,
        isSoundscapePlaying: false,
        narrationVolume: 1,
        soundscapeVolume: 1,
        isPracticeMode: false,
        isListening: false,
        spokenWordIndices: {},
        narrationPosition: Duration.zero,
        showCelebration: false,
      ),
      wordHelpSnapshot: const WordHelpSnapshot.idle(),
      showCelebrationGif: false,
      endedForLifecycle: false,
    );
  }

  @override
  Future<void> dispatch(ReaderExperienceAction action) async {
    log.actions.add(action);
    if (action case ReaderExperienceScrollOffsetChanged(:final offset)) {
      log.scrollOffsetListenable.value = offset;
    }
  }

  @override
  Future<void> handleLifecycleState(AppLifecycleState lifecycleState) async {
    log.lifecycleStates.add(lifecycleState);
  }
}

const _book = Book(
  id: 'book-1',
  title: 'Coordinator Book',
  pageCount: 1,
  pages: [
    PageData(
      id: 'page-1',
      pageNumber: 1,
      textContent: 'hello coordinator',
      narrationUrl: 'https://example.test/narration.mp3',
      soundscapeUrl: 'https://example.test/soundscape.mp3',
    ),
  ],
);
