import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/application/reader_experience_controller.dart';
import 'package:storia_kids/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/word_help/reader_word_help.dart';

import 'reader_experience_fakes.dart';

void main() {
  group('ReaderExperienceController', () {
    late FakeReaderSession session;
    late FakeReaderWordHelp wordHelp;
    late FakeReaderExperienceEffects effects;
    late ReaderExperienceController controller;

    setUp(() {
      session = FakeReaderSession();
      wordHelp = FakeReaderWordHelp();
      effects = FakeReaderExperienceEffects();
      controller = ReaderExperienceController(
        session: session,
        wordHelp: wordHelp,
        effects: effects,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await session.dispose();
      await wordHelp.dispose();
    });

    test('dispatches ReaderStart with the selected book and page', () async {
      await controller.dispatch(
        ReaderExperienceStart(book: _book, initialPageIndex: 1),
      );

      expect(session.intents, hasLength(1));
      final intent = session.intents.single;
      expect(intent, isA<ReaderStart>());
      final start = intent as ReaderStart;
      expect(start.book, same(_book));
      expect(start.initialPageIndex, 1);
    });

    test('dispatches page changes to the reader session', () async {
      await controller.dispatch(const ReaderExperiencePageChanged(1));

      expect(session.intents.single, isA<ReaderGoToPage>());
      expect((session.intents.single as ReaderGoToPage).pageIndex, 1);
    });

    test('dispatches audio and practice controls to runtime intents', () async {
      await controller.dispatch(const ReaderExperienceToggleNarration());
      await controller.dispatch(const ReaderExperienceToggleSoundscape());
      await controller.dispatch(const ReaderExperienceSetNarrationVolume(0.7));
      await controller.dispatch(const ReaderExperienceSetSoundscapeVolume(0.2));
      await controller.dispatch(const ReaderExperienceTogglePractice());
      await controller.dispatch(const ReaderExperiencePauseListening());
      await controller.dispatch(const ReaderExperienceResumeListening());

      expect(session.intents[0], isA<ReaderToggleNarration>());
      expect(session.intents[1], isA<ReaderToggleSoundscape>());
      expect(session.intents[2], isA<ReaderSetNarrationVolume>());
      expect(
        (session.intents[2] as ReaderSetNarrationVolume).volume,
        closeTo(0.7, 0.001),
      );
      expect(session.intents[3], isA<ReaderSetSoundscapeVolume>());
      expect(
        (session.intents[3] as ReaderSetSoundscapeVolume).volume,
        closeTo(0.2, 0.001),
      );
      expect(session.intents[4], isA<ReaderPracticePrimaryAction>());
      expect(session.intents[5], isA<ReaderPauseListening>());
      expect(session.intents[6], isA<ReaderResumeListening>());
    });

    test('builds word-help requests for taps and long presses', () async {
      await controller.dispatch(ReaderExperienceStart(book: _book));

      await controller.dispatch(
        const ReaderExperienceWordTapped(
          word: 'firefly',
          globalIndex: 12,
          pageIndex: 1,
        ),
      );
      await controller.dispatch(
        const ReaderExperienceWordLongPressed(
          word: 'moon-light',
          globalIndex: 13,
          pageIndex: 1,
        ),
      );

      expect(wordHelp.requests, hasLength(2));
      expect(wordHelp.requests[0].bookId, 'book-1');
      expect(wordHelp.requests[0].pageIndex, 1);
      expect(wordHelp.requests[0].wordIndex, 12);
      expect(wordHelp.requests[0].rawWord, 'firefly');
      expect(wordHelp.requests[0].mode, WordHelpMode.word);
      expect(wordHelp.requests[1].bookId, 'book-1');
      expect(wordHelp.requests[1].pageIndex, 1);
      expect(wordHelp.requests[1].wordIndex, 13);
      expect(wordHelp.requests[1].rawWord, 'moon-light');
      expect(wordHelp.requests[1].mode, WordHelpMode.breakdown);
    });

    test('requires start before handling word-help actions', () async {
      await expectLater(
        controller.dispatch(
          const ReaderExperienceWordTapped(
            word: 'firefly',
            globalIndex: 12,
            pageIndex: 0,
          ),
        ),
        throwsStateError,
      );
      expect(wordHelp.requests, isEmpty);
    });

    test(
      'updates state and runs celebration effects only on transitions',
      () async {
        session.emitState(
          const ReaderViewState.initial().copyWith(showCelebration: true),
        );
        await pumpEventQueue();

        expect(controller.state.readerState.showCelebration, isTrue);
        expect(controller.state.showCelebrationGif, isTrue);
        expect(effects.playCelebrationCount, 1);
        expect(effects.stopCelebrationCount, 0);

        session.emitState(
          const ReaderViewState.initial().copyWith(showCelebration: true),
        );
        await pumpEventQueue();
        expect(effects.playCelebrationCount, 1);

        session.emitState(const ReaderViewState.initial());
        await pumpEventQueue();

        expect(controller.state.readerState.showCelebration, isFalse);
        expect(controller.state.showCelebrationGif, isFalse);
        expect(effects.stopCelebrationCount, 1);
      },
    );

    test('merges word-help snapshots into controller state', () async {
      wordHelp.emitSnapshot(
        const WordHelpSnapshot(
          phase: WordHelpPhase.playingPronunciation,
          activeWordIndex: 7,
        ),
      );
      await pumpEventQueue();

      expect(
        controller.state.wordHelpSnapshot.phase,
        WordHelpPhase.playingPronunciation,
      );
      expect(controller.state.wordHelpSnapshot.activeWordIndex, 7);
    });

    test(
      'keeps narration position and scroll listenables behind boundary',
      () async {
        expect(controller.narrationPositionListenable.value, Duration.zero);
        expect(controller.scrollOffsetListenable.value, 0.0);

        session.emitState(
          const ReaderViewState.initial().copyWith(
            narrationPosition: Duration(seconds: 7),
          ),
        );
        await pumpEventQueue();
        await controller.dispatch(
          const ReaderExperienceScrollOffsetChanged(1.25),
        );

        expect(
          controller.narrationPositionListenable.value,
          const Duration(seconds: 7),
        );
        expect(controller.scrollOffsetListenable.value, 1.25);
      },
    );

    test(
      'ends on lifecycle pause and restarts remembered book on resume',
      () async {
        await controller.dispatch(
          ReaderExperienceStart(book: _book, initialPageIndex: 1),
        );
        session.emitState(
          const ReaderViewState.initial().copyWith(activePageIndex: 1),
        );
        await pumpEventQueue();
        session.intents.clear();

        await controller.handleLifecycleState(AppLifecycleState.paused);

        expect(controller.state.endedForLifecycle, isTrue);
        expect(session.intents.single, isA<ReaderEnd>());
        expect((session.intents.single as ReaderEnd).reason, 'app_paused');

        session.intents.clear();
        await controller.handleLifecycleState(AppLifecycleState.resumed);

        expect(controller.state.endedForLifecycle, isFalse);
        expect(session.intents.single, isA<ReaderStart>());
        final restart = session.intents.single as ReaderStart;
        expect(restart.book, same(_book));
        expect(restart.initialPageIndex, 1);
      },
    );

    test('dispatches explicit end actions', () async {
      await controller.dispatch(const ReaderExperienceEnd(reason: 'close'));

      expect(session.intents.single, isA<ReaderEnd>());
      expect((session.intents.single as ReaderEnd).reason, 'close');
    });

    test('provider wires dependencies, projects state, and disposes', () async {
      final providerSession = FakeReaderSession();
      final providerWordHelp = FakeReaderWordHelp();
      final providerEffects = FakeReaderExperienceEffects();
      addTearDown(providerSession.dispose);
      addTearDown(providerWordHelp.dispose);

      final container = ProviderContainer(
        overrides: [
          readerSessionProvider.overrideWith((ref) => providerSession),
          readerExperienceWordHelpProvider(
            'book-1',
          ).overrideWith((ref) => providerWordHelp),
          readerExperienceEffectsProvider.overrideWith(
            (ref) => providerEffects,
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        readerExperienceControllerProvider('book-1'),
        (_, _) {},
        fireImmediately: true,
      );
      final notifier = container.read(
        readerExperienceControllerProvider('book-1').notifier,
      );

      await notifier.dispatch(ReaderExperienceStart(book: _book));
      providerSession.emitState(
        const ReaderViewState.initial().copyWith(showCelebration: true),
      );
      await pumpEventQueue();

      expect(providerSession.intents.single, isA<ReaderStart>());
      expect(subscription.read().showCelebrationGif, isTrue);
      expect(providerEffects.playCelebrationCount, 1);

      container.dispose();
      await pumpEventQueue();

      expect(
        providerSession.intents.whereType<ReaderEnd>().map(
          (intent) => intent.reason,
        ),
        ['screen_dispose'],
      );
      expect(providerWordHelp.cancelReasons, [WordHelpCancelReason.disposed]);
    });

    test(
      'dispose ends the session, cancels word help, and ignores later events',
      () async {
        await controller.dispose();

        expect(session.intents.single, isA<ReaderEnd>());
        expect((session.intents.single as ReaderEnd).reason, 'screen_dispose');
        expect(wordHelp.cancelReasons, [WordHelpCancelReason.disposed]);
        expect(effects.disposeCount, 1);

        session.emitState(
          const ReaderViewState.initial().copyWith(showCelebration: true),
        );
        wordHelp.emitSnapshot(
          const WordHelpSnapshot(
            phase: WordHelpPhase.playingPronunciation,
            activeWordIndex: 3,
          ),
        );
        await pumpEventQueue();

        expect(effects.playCelebrationCount, 0);
        expect(controller.state.showCelebrationGif, isFalse);
        expect(controller.state.wordHelpSnapshot.activeWordIndex, isNull);

        await controller.dispose();
        expect(
          session.intents.whereType<ReaderEnd>().map((intent) => intent.reason),
          ['screen_dispose'],
        );
        expect(wordHelp.cancelReasons, [WordHelpCancelReason.disposed]);
        expect(effects.disposeCount, 1);
      },
    );
  });
}

const _book = Book(
  id: 'book-1',
  title: 'Boundary Test Book',
  pageCount: 2,
  pages: [
    PageData(id: 'page-1', pageNumber: 1, textContent: 'hello firefly'),
    PageData(id: 'page-2', pageNumber: 2, textContent: 'moon light'),
  ],
);
