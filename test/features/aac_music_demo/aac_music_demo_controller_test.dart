import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:loratone/src/features/aac_music_demo/domain/word_model.dart';
import 'package:loratone/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:loratone/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:loratone/src/features/aac_music_demo/domain/sequencer.dart';
import 'package:loratone/src/features/aac_music_demo/data/aac_board.dart';
import 'package:loratone/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart';

class _SilentSpeech implements SpeechSynth {
  @override
  Future<void> speak(String text) async {}
}

class _SilentBackend implements AudioBackend {
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async {}
}

AacMusicDemoController _controller() {
  const board = AacBoard(
    palette: HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic),
    musicConfig: BoardMusicConfig(),
    words: [
      AacWord(id: 'i', label: 'I', row: 0, col: 0, musicalRole: MusicalRole.note(0)),
      AacWord(id: 'more', label: 'more', row: 0, col: 1, musicalRole: MusicalRole.note(4)),
    ],
  );
  final engine = ConsonanceEngine(board.palette);
  final sequencer = UtteranceSequencer(
    speech: _SilentSpeech(),
    backend: _SilentBackend(),
    engine: engine,
    resolver: RoleResolver(board.musicConfig),
  );
  return AacMusicDemoController(board: board, sequencer: sequencer);
}

void main() {
  test('selecting words appends to utterance', () async {
    final c = _controller();
    await c.selectWord(c.state.board.words[0]);
    await c.selectWord(c.state.board.words[1]);
    expect(c.state.utteranceLabels, ['I', 'more']);
  });

  test('clear empties the utterance', () async {
    final c = _controller();
    await c.selectWord(c.state.board.words[0]);
    c.clearUtterance();
    expect(c.state.utteranceLabels, isEmpty);
  });

  test('changing mode updates state and sequencer config', () async {
    final c = _controller();
    c.setMode(MusicMode.phraseOnly);
    expect(c.state.mode, MusicMode.phraseOnly);
  });
}
