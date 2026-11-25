import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/page_audio.dart';
import 'package:loratone/src/audio/audio_providers.dart';
import 'package:loratone/src/data/analytics_repository.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/reader/application/reader_experience_controller.dart';
import 'package:loratone/src/features/reader/application/reader_experience_effects.dart';
import 'package:loratone/src/features/reader/domain/reader_capabilities.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_capabilities_provider.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_session_provider.dart';

void main() {
  test(
    'guest reading sends only anonymous reading events, never speech or word help',
    () async {
      final audio = _PageAudio();
      final transport = _RecordingTransport();
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
          analyticsRepositoryProvider.overrideWithValue(
            AnalyticsRepository(
              transport: transport,
              currentAnonId: () => 'anon-1',
            ),
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
      await pumpEventQueue();
      expect(transport.bodies, isNotEmpty);
      for (final body in transport.bodies) {
        expect(body['anonId'], 'anon-1');
        expect(
          AnalyticsRepository.guestEvents.map((e) => e.eventName),
          contains(body['event']),
        );
      }
      subscription.close();
      container.dispose();
      await pumpEventQueue();
      await audio.close();
    },
  );
}

class _RecordingTransport implements AnalyticsTransport {
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<void> send(Map<String, dynamic> body, {String? accessToken}) async {
    expect(accessToken, isNull);
    bodies.add(body);
  }
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
