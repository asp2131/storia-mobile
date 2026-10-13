import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:loratone/src/audio/audio_providers.dart';
import 'package:loratone/src/audio/raw_player.dart';
import 'package:loratone/src/core/widgets/parental_gate.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/narration_studio/data/narration_providers.dart';
import 'package:loratone/src/features/onboarding/data/sample_book_provider.dart';
import 'package:loratone/src/features/onboarding/presentation/sample_reader_screen.dart';
import 'package:loratone/src/features/reader/application/reader_experience_controller.dart';
import 'package:loratone/src/features/reader/domain/reader_capabilities.dart';
import 'package:loratone/src/features/reader/data/reading_checkpoint_provider.dart';
import 'package:loratone/src/features/reader/domain/reading_checkpoint.dart';
import 'package:loratone/src/features/reader/page_renderer.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_word_help_provider.dart';
import 'package:loratone/src/features/reader/runtime/word_help/reader_word_help.dart';

Widget _sampleApp() => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: const SampleReaderScreen(),
);

void main() {
  testWidgets(
    'sample stays offline, silent until play, and relocks audio on resume',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          null,
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final players = <_AssetPlayer>[];
      Never forbidden() =>
          throw StateError('Sample constructed a prohibited service');
      final container = ProviderContainer(
        overrides: [
          readingOwnerProvider.overrideWithValue(const ReadingOwner.guest()),
          sampleBookBundleProvider.overrideWith(
            (ref) async =>
                SampleBookBundle(book: _book, contentRevision: 'fixture-1'),
          ),
          sampleRawPlayerFactoryProvider.overrideWithValue(() {
            final player = _AssetPlayer();
            players.add(player);
            return player;
          }),
          currentBookProvider.overrideWith((ref, id) async => forbidden()),
          bookManifestProvider.overrideWith((ref, id) async => forbidden()),
          pronunciationRepositoryProvider.overrideWith((ref) => forbidden()),
          narrationRepositoryProvider.overrideWith((ref) => forbidden()),
          readerAnalyticsTrackerProvider.overrideWith((ref) => forbidden()),
          activeChildProfileIdProvider.overrideWith((ref) => forbidden()),
          wordTtsServiceProvider.overrideWith((ref) => forbidden()),
          pronunciationPlayerProvider.overrideWith((ref) => forbidden()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _sampleApp()),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/idle.png'),
          tester.element(find.byType(SampleReaderScreen)),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(PageRenderer), findsWidgets);
      expect(find.byIcon(Icons.mic_off_rounded), findsNothing);
      expect(players.where((p) => p.isPlaying), isEmpty);
      expect(
        players.expand((p) => p.assets),
        contains('assets/audio/sfx/page_turn.wav'),
      );

      final readerContext = tester.element(find.byType(PageView));
      final scoped = ProviderScope.containerOf(readerContext);
      final controller = scoped.read(
        readerExperienceControllerProvider(sampleBookId).notifier,
      );
      await controller.dispatch(const ReaderExperienceSetNarrationVolume(.3));
      await controller.dispatch(const ReaderExperienceSetSoundscapeVolume(.2));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(players.first.isPlaying, isTrue);
      await tester.tap(find.byType(TextButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(players.where((p) => p.isPlaying), isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(GateChallengeCard),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .isReady,
        isTrue,
      );
      expect(players.where((p) => p.isPlaying), isEmpty);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        closeTo(0, .01),
      );
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(players.first.isPlaying, isTrue);
      await tester.drag(find.byType(PageView), const Offset(0, -650));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .activePageIndex,
        1,
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        closeTo(1, .01),
      );

      await controller.dispatch(const ReaderExperienceTogglePractice());
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .isPracticeMode,
        isFalse,
      );
      final result = await scoped
          .read(readerWordHelpProvider(sampleBookId).notifier)
          .play(
            const WordHelpRequest(
              bookId: sampleBookId,
              pageIndex: 1,
              wordIndex: 0,
              rawWord: 'Light',
              mode: WordHelpMode.word,
            ),
          );
      expect(result.outcome, WordHelpOutcome.failed);

      await controller.handleLifecycleState(AppLifecycleState.paused);
      expect(players.where((p) => p.isPlaying), isEmpty);
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .activePageIndex,
        1,
      );
      expect(players.where((p) => p.isPlaying), isEmpty);
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .narrationVolume,
        .3,
      );
      expect(
        scoped
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .soundscapeVolume,
        .2,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();
      expect(players.where((p) => p.isPlaying), isEmpty);
      expect(tester.takeException(), isNull);
      final repository = await container.read(
        readingCheckpointRepositoryProvider.future,
      );
      final stored = await repository.load(
        const ReadingOwner.guest(),
        sampleBookId,
      );
      expect(stored?.pageIndex, 1);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _sampleApp()),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final restoredScope = ProviderScope.containerOf(
        tester.element(find.byType(PageView)),
      );
      expect(
        restoredScope
            .read(readerExperienceControllerProvider(sampleBookId))
            .readerState
            .activePageIndex,
        1,
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        closeTo(1, .01),
      );
      expect(find.byType(PageRenderer).hitTestable(), findsOneWidget);
      expect(players.where((p) => p.isPlaying), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

final _book = Book(
  id: sampleBookId,
  title: 'Fixture',
  pageCount: 2,
  pages: const [
    PageData(
      id: 'p1',
      pageNumber: 1,
      imageUrl: 'asset:///assets/images/idle.png',
      textContent: 'Technical fixture page one',
      narrationUrl: 'asset:///assets/audio/sfx/page_turn.wav',
    ),
    PageData(
      id: 'p2',
      pageNumber: 2,
      imageUrl: 'asset:///assets/images/idle.png',
      textContent: 'Technical fixture page two',
      narrationUrl: 'asset:///assets/audio/sfx/page_turn.wav',
    ),
  ],
);

class _AssetPlayer implements RawPlayer {
  final assets = <String>[];
  final _playing = StreamController<bool>.broadcast();
  bool _isPlaying = false;
  @override
  Future<void> setSource(String url) async =>
      throw StateError('Network source: $url');
  @override
  Future<void> setAsset(String path) async => assets.add(path);
  @override
  Future<void> play() async {
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    if (!_playing.isClosed) _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setLoopMode(RawLoopMode mode) async {}
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => Duration.zero;
  @override
  Duration? get duration => const Duration(seconds: 1);
  @override
  RawPlayerState get state => RawPlayerState.ready;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<RawPlayerState> get stateStream => const Stream.empty();
  @override
  Future<void> dispose() async {
    _isPlaying = false;
    await _playing.close();
  }
}
