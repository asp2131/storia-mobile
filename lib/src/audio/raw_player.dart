import 'dart:async';

enum RawPlayerState { idle, loading, ready, completed }

enum RawLoopMode { off, one }

abstract class RawPlayer {
  Future<void> setSource(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setLoopMode(RawLoopMode mode);

  bool get isPlaying;
  Duration get position;
  Duration? get duration;
  RawPlayerState get state;

  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<RawPlayerState> get stateStream;

  Future<void> dispose();
}
