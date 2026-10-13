import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio/audio_engine.dart';
import '../../../audio/audio_providers.dart';
import '../../../audio/just_audio_player.dart';
import '../../reader/application/reader_experience_controller.dart';
import '../../reader/application/reader_experience_effects.dart';
import '../../reader/domain/reader_capabilities.dart';
import '../../reader/data/reading_checkpoint_provider.dart';
import '../../reader/reader_screen.dart';
import '../../reader/runtime/providers/reader_session_provider.dart';

/// Injectable native players; sample and catalog never share an audio engine.
final sampleRawPlayerFactoryProvider = Provider<RawPlayerFactory>(
  (ref) => JustAudioPlayer.new,
);

/// The only account-free reader entry. No caller-supplied catalog identifier.
class SampleReaderScreen extends ConsumerWidget {
  const SampleReaderScreen({super.key, this.replay = false});
  final bool replay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      key: ValueKey(ref.watch(readingOwnerProvider)),
      overrides: [
        readerLaunchAccessProvider.overrideWithValue(
          const ReaderCapabilities(access: ReaderAccess.sample),
        ),
        audioEngineProvider.overrideWith((ref) {
          final engine = AudioEngine(
            playerFactory: ref.watch(sampleRawPlayerFactoryProvider),
          );
          ref.onDispose(engine.dispose);
          return engine;
        }),
        readerExperienceEffectsProvider.overrideWithValue(
          const NoopReaderExperienceEffects(),
        ),
      ],
      child: ReaderScreen(bookId: sampleBookId, replay: replay),
    );
  }
}
