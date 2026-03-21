import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_engine.dart';
import '../../audio/audio_providers.dart';

class AudioPlaybackState {
  const AudioPlaybackState({
    required this.narrationPosition,
    required this.isNarrationPlaying,
    required this.isSoundscapePlaying,
    this.narrationVolume = 1.0,
    this.soundscapeVolume = 0.6,
  });

  final Duration narrationPosition;
  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final double narrationVolume;
  final double soundscapeVolume;

  AudioPlaybackState copyWith({
    Duration? narrationPosition,
    bool? isNarrationPlaying,
    bool? isSoundscapePlaying,
    double? narrationVolume,
    double? soundscapeVolume,
  }) {
    return AudioPlaybackState(
      narrationPosition: narrationPosition ?? this.narrationPosition,
      isNarrationPlaying: isNarrationPlaying ?? this.isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying ?? this.isSoundscapePlaying,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      soundscapeVolume: soundscapeVolume ?? this.soundscapeVolume,
    );
  }
}

class ReaderAudioStateNotifier extends StateNotifier<AudioPlaybackState> {
  ReaderAudioStateNotifier(this._audioEngine)
      : super(const AudioPlaybackState(
          narrationPosition: Duration.zero,
          isNarrationPlaying: false,
          isSoundscapePlaying: false,
          narrationVolume: 1.0,
          soundscapeVolume: 0.6,
        )) {
    _narrationPositionSubscription =
        _audioEngine.narrationPosition.listen((position) {
      state = state.copyWith(narrationPosition: position);
    });

    _narrationPlayingSubscription =
        _audioEngine.narrationPlaying.listen((playing) {
      state = state.copyWith(isNarrationPlaying: playing);
    });

    _soundscapePlayingSubscription =
        _audioEngine.soundscapePlaying.listen((playing) {
      state = state.copyWith(isSoundscapePlaying: playing);
    });
  }

  final AudioEngine _audioEngine;

  late final StreamSubscription<Duration> _narrationPositionSubscription;
  late final StreamSubscription<bool> _narrationPlayingSubscription;
  late final StreamSubscription<bool> _soundscapePlayingSubscription;

  Future<void> setNarrationVolume(double volume) async {
    await _audioEngine.setNarrationVolume(volume);
    state = state.copyWith(narrationVolume: volume);
  }

  Future<void> setSoundscapeVolume(double volume) async {
    await _audioEngine.setSoundscapeVolume(volume);
    state = state.copyWith(soundscapeVolume: volume);
  }

  @override
  void dispose() {
    _narrationPositionSubscription.cancel();
    _narrationPlayingSubscription.cancel();
    _soundscapePlayingSubscription.cancel();
    super.dispose();
  }
}

final readerAudioStateProvider = StateNotifierProvider.autoDispose<
    ReaderAudioStateNotifier, AudioPlaybackState>(
  (ref) {
    final engine = ref.read(audioEngineProvider);
    return ReaderAudioStateNotifier(engine);
  },
);
