// Riverpod StateNotifier for the demo screen. Owns the utterance, the active
// MusicMode, and bridges UI taps to the sequencer. Hand-written providers
// (no codegen, per repo convention).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/flutter_tts_speech_synth.dart';
import '../adapters/midi_audio_backend.dart';
import '../data/aac_board.dart';
import '../data/aac_board_loader.dart';
import '../domain/consonance_engine.dart';
import '../domain/role_resolver.dart';
import '../domain/sequencer.dart';
import '../domain/word_model.dart';

@immutable
class AacMusicDemoState {
  const AacMusicDemoState({
    required this.board,
    required this.utteranceLabels,
    required this.mode,
  });

  final AacBoard board;
  final List<String> utteranceLabels;
  final MusicMode mode;

  AacMusicDemoState copyWith({
    List<String>? utteranceLabels,
    MusicMode? mode,
  }) {
    return AacMusicDemoState(
      board: board,
      utteranceLabels: utteranceLabels ?? this.utteranceLabels,
      mode: mode ?? this.mode,
    );
  }
}

class AacMusicDemoController extends StateNotifier<AacMusicDemoState> {
  AacMusicDemoController({
    required AacBoard board,
    required UtteranceSequencer sequencer,
  })  : _sequencer = sequencer,
        super(AacMusicDemoState(
          board: board,
          utteranceLabels: const [],
          mode: sequencer.config.mode,
        ));

  final UtteranceSequencer _sequencer;

  Future<void> warmUp() => _sequencer.backend.warmUp();

  Future<void> selectWord(AacWord word) async {
    await _sequencer.onWordSelected(word);
    state = state.copyWith(
      utteranceLabels: _sequencer.utterance.map((w) => w.label).toList(),
    );
  }

  Future<void> send() => _sequencer.onSend();

  void clearUtterance() {
    _sequencer.clear();
    state = state.copyWith(utteranceLabels: const []);
  }

  void setMode(MusicMode mode) {
    _sequencer.config = SequencerConfig(
      mode: mode,
      musicHeadroom: _sequencer.config.musicHeadroom,
      stepMs: _sequencer.config.stepMs,
      bloomOnSend: _sequencer.config.bloomOnSend,
      speakSentenceOnSend: _sequencer.config.speakSentenceOnSend,
    );
    state = state.copyWith(mode: mode);
  }
}

/// Async provider that loads the board, builds the sequencer with real
/// adapters, and exposes the controller. The demo screen watches this.
final aacMusicDemoControllerProvider =
    FutureProvider.autoDispose<AacMusicDemoController>((ref) async {
  final board = await const AacBoardLoader().load();
  final sequencer = UtteranceSequencer(
    speech: FlutterTtsSpeechSynth(),
    backend: MidiAudioBackend(),
    engine: ConsonanceEngine(board.palette),
    resolver: RoleResolver(board.musicConfig),
  );
  final controller = AacMusicDemoController(board: board, sequencer: sequencer);
  await controller.warmUp();
  return controller;
});
