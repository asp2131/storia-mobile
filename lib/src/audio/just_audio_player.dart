import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'raw_player.dart';

class JustAudioPlayer implements RawPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setSource(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setLoopMode(RawLoopMode mode) => _player.setLoopMode(
        mode == RawLoopMode.one ? LoopMode.one : LoopMode.off,
      );

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  RawPlayerState get state {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return RawPlayerState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return RawPlayerState.loading;
      case ProcessingState.ready:
        return RawPlayerState.ready;
      case ProcessingState.completed:
        return RawPlayerState.completed;
    }
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<RawPlayerState> get stateStream => _player.processingStateStream.map(
        (ps) {
          switch (ps) {
            case ProcessingState.idle:
              return RawPlayerState.idle;
            case ProcessingState.loading:
            case ProcessingState.buffering:
              return RawPlayerState.loading;
            case ProcessingState.ready:
              return RawPlayerState.ready;
            case ProcessingState.completed:
              return RawPlayerState.completed;
          }
        },
      );

  @override
  Future<void> dispose() => _player.dispose();
}
