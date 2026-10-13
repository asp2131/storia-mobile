import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/page_audio.dart';
import 'package:loratone/src/audio/audio_providers.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/application/reader_experience_controller.dart';
import 'package:loratone/src/features/reader/application/reader_experience_effects.dart';
import 'package:loratone/src/features/reader/domain/reader_capabilities.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_capabilities_provider.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_session_provider.dart';

void main() {
  test(
    'guest reading never constructs analytics, speech or word-help services',
    () async {
      final audio = _PageAudio();
      final container = ProviderContainer(
        overrides: [
          readerCapabilitiesProvider.overrideWithValue(
            const ReaderCapabilities(access: ReaderAccess.guest),
          ),
          pageAudioProvider.overrideWithValue(audio),
          readerImageReadyProbeProvider.overrideWithValue((_) async {}),
          readerSpeechPracticePortProvider.overrideWith(
            (ref) => throw StateError('speech initialized'),
          ),
          readerAnalyticsTrackerProvider.overrideWith(
            (ref) => throw StateError('analytics initialized'),
          ),
          readerExperienceWordHelpProvider(
            '68',
          ).overrideWith((ref) => throw StateError('word help initialized')),
          readerExperienceEffectsProvider.overrideWithValue(
            const NoopReaderExperienceEffects(),
          ),
        ],
      );
      final subscription = container.listen(
        readerExperienceControllerProvider('68'),
        (_, _) {},
      );
      final controller = container.read(
        readerExperienceControllerProvider('68').notifier,
      );
      await controller.dispatch(ReaderExperienceStart(book: _book));
      await controller.dispatch(const ReaderExperiencePageChanged(1));
      await controller.dispatch(const ReaderExperienceTogglePractice());
      await controller.dispatch(const ReaderExperienceResumeListening());
      await controller.dispatch(
        const ReaderExperienceWordTapped(
          word: 'world',
          globalIndex: 0,
          pageIndex: 1,
        ),
      );
      await pumpEventQueue();

      final state = container.read(readerExperienceControllerProvider('68'));
      expect(state.readerState.activePageIndex, 1);
      expect(state.readerState.isPracticeMode, isFalse);
      expect(state.readerState.isListening, isFalse);
      expect(audio.loadedPages, ['1', '2']);
      await controller.dispatch(const ReaderExperienceEnd());
      subscription.close();
      container.dispose();
      await pumpEventQueue();
      await audio.close();
    },
  );
}

final _book = Book(
  id: '68',
  title: 'Story',
  pageCount: 2,
  pages: const [
    PageData(id: '1', pageNumber: 1, textContent: 'hello'),
    PageData(id: '2', pageNumber: 2, textContent: 'world'),
  ],
);

class _PageAudio implements PageAudio {
  final loadedPages = <String>[];
  final _states = StreamController<AudioSnapshot>.broadcast();
  @override
  Stream<AudioSnapshot> get states => _states.stream;
  @override
  Future<void> loadPage(PageData page) async {
    loadedPages.add(page.id);
  }

  @override
  Future<void> toggleNarration() async {}
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
  Future<void> close() => _states.close();
}
