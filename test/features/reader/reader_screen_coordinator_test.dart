import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_player/gif_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/gen_ui/data/gen_ui_preferences_provider.dart';
import 'package:loratone/src/features/gen_ui/data/gen_ui_providers.dart';
import 'package:loratone/src/features/gen_ui/data/mock_gen_ui_cards.dart';
import 'package:loratone/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:loratone/src/features/gen_ui/presentation/reader_activity_card.dart';
import 'package:loratone/src/features/reader/application/reader_experience_controller.dart';
import 'package:loratone/src/features/reader/application/reader_experience_effects.dart';
import 'package:loratone/src/features/reader/reader_screen.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:loratone/src/features/reader/runtime/reader_session.dart';
import 'package:loratone/src/features/reader/runtime/word_help/reader_word_help.dart';

class _EmptyGenUiRepo implements MockGenUiCardRepository {
  const _EmptyGenUiRepo();
  @override
  List<GenUiCardSchema> readerCardsForPage({
    required String bookId,
    required int pageIndex,
  }) => const [];
}

void main() {
  setUp(() {
    // The gen-UI preferences notifier reads SharedPreferences on construction;
    // provide an in-memory store so reader tests don't hit the platform plugin.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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
          mockGenUiCardRepositoryProvider.overrideWithValue(
            const _EmptyGenUiRepo(),
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
    // Avoid pumpAndSettle here; reader chrome animations can keep this
    // coordinator routing assertion waiting longer than necessary.
    await tester.pump();
    await tester.pump();

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceToggleNarration>(),
      hasLength(1),
    );
  });

  testWidgets('fresh open always starts at page 0 ignoring retained page', (
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
          currentBookProvider(
            'book-multi',
          ).overrideWith((ref) async => _multiPageBook),
          bookManifestProvider('book-multi').overrideWith((ref) async => null),
          readerSessionProvider.overrideWith((ref) => _FakeReaderSession()),
          readerExperienceControllerProvider.overrideWith(
            // Simulate a controller that retained a later page from a prior
            // visit. A fresh open must still begin at page 0.
            () => _FakeReaderExperienceControllerNotifier._(
              coordinatorLog,
              'book-multi',
              initialPageIndex: 2,
            ),
          ),
          readerExperienceEffectsProvider.overrideWith(
            (ref) => const NoopReaderExperienceEffects(),
          ),
          mockGenUiCardRepositoryProvider.overrideWithValue(
            const _EmptyGenUiRepo(),
          ),
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-multi')),
      ),
    );
    await tester.pump();
    await tester.pump();

    final start = coordinatorLog.actions
        .whereType<ReaderExperienceStart>()
        .single;
    expect(start.initialPageIndex, 0);
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

  testWidgets('ReaderScreen retains GifPlayer controller across GIF unmounts', (
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
          mockGenUiCardRepositoryProvider.overrideWithValue(
            const _EmptyGenUiRepo(),
          ),
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
      ),
    );
    await tester.pump();
    await tester.pump();

    coordinatorLog.controller!.setShowCelebrationGif(true);
    await tester.pump();
    expect(find.byType(GifPlayer), findsOneWidget);

    coordinatorLog.controller!.setShowCelebrationGif(false);
    await tester.pump();
    expect(find.byType(GifPlayer), findsNothing);

    coordinatorLog.controller!.setShowCelebrationGif(true);
    await tester.pump();
    expect(find.byType(GifPlayer), findsOneWidget);
  });

  testWidgets('Story Spark takeover dispatches activity shown/dismissed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
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
          // Story Sparks are off by default; force them on for this takeover
          // test so the activity overlay renders.
          storySparksEnabledProvider.overrideWithValue(true),
          // NOTE: no mockGenUiCardRepositoryProvider override here — page 0
          // yields the null-anchor reflection card, which is live on load.
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
      ),
    );
    await tester.pump();
    await tester.pump(); // let the post-frame onActivityShown fire

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceActivityShown>(),
      hasLength(1),
    );

    // Skip via the card's close button. Scope the finder to the activity card
    // so it can't match any other close icon in the chrome.
    final closeButton = find.descendant(
      of: find.byType(ReaderActivityCard),
      matching: find.byIcon(Icons.close_rounded),
    );
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pump();

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceActivityDismissed>(),
      hasLength(1),
    );
  });

  testWidgets('Story Spark overlay is hidden by default', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
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
          // No storySparksEnabledProvider override: rely on the default (off).
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
      ),
    );
    await tester.pump();
    await tester.pump();

    // With Story Sparks disabled by default, the activity overlay must not
    // mount and no activity-shown action should be dispatched.
    expect(find.byType(ReaderActivityCard), findsNothing);
    expect(
      coordinatorLog.actions.whereType<ReaderExperienceActivityShown>(),
      isEmpty,
    );
  });
}

class _CoordinatorLog {
  _FakeReaderExperienceControllerNotifier? controller;
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
    String bookId, {
    this.initialPageIndex = 0,
  });

  final _CoordinatorLog log;
  final int initialPageIndex;

  @override
  ValueListenable<Duration> get narrationPositionListenable =>
      log.narrationPositionListenable;

  @override
  ValueListenable<double> get scrollOffsetListenable =>
      log.scrollOffsetListenable;

  @override
  ReaderExperienceState build(String bookId) {
    log.controller = this;
    return ReaderExperienceState(
      readerState: ReaderViewState(
        isReady: true,
        activePageIndex: initialPageIndex,
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
      activityNarrationPaused: false,
    );
  }

  void setShowCelebrationGif(bool visible) {
    state = state.copyWith(showCelebrationGif: visible);
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

const _multiPageBook = Book(
  id: 'book-multi',
  title: 'Multi Page Book',
  pageCount: 3,
  pages: [
    PageData(id: 'mp-1', pageNumber: 1, textContent: 'page one'),
    PageData(id: 'mp-2', pageNumber: 2, textContent: 'page two'),
    PageData(id: 'mp-3', pageNumber: 3, textContent: 'page three'),
  ],
);
