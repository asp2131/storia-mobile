import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_engine.dart';
import 'just_audio_player.dart';
import 'page_audio.dart';
import 'pronunciation_player.dart';
import 'sfx_bus.dart';

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine(playerFactory: JustAudioPlayer.new);
  ref.onDispose(engine.dispose);
  return engine;
});

final pageAudioProvider = Provider<PageAudio>((ref) {
  return ref.watch(audioEngineProvider);
});

final pronunciationPlayerProvider = Provider<PronunciationPlayer>((ref) {
  return ref.watch(audioEngineProvider);
});

final sfxBusProvider = Provider<SfxBus>((ref) {
  final bus = SfxBus();
  ref.onDispose(() => unawaited(bus.dispose()));
  return bus;
});
