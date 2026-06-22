import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/data/aac_board.dart';

void main() {
  const json = '''
  {
    "palette": {"root": "c", "scale": "majorPentatonic", "baseOctave": 4},
    "tagDefaults": {"pronoun": {"kind": "note", "degree": 0}},
    "words": [
      {"id": "i", "label": "I", "row": 0, "col": 0, "tags": ["pronoun"]},
      {"id": "want", "label": "want", "row": 0, "col": 1,
       "musicalRole": {"kind": "note", "degree": 3}},
      {"id": "go", "label": "go", "row": 0, "col": 2}
    ]
  }
  ''';

  test('parses palette, tag defaults, and words from JSON', () {
    final board = AacBoard.fromJsonString(json);

    expect(board.palette.root, PitchClass.c);
    expect(board.palette.scale, Scale.majorPentatonic);
    expect(board.musicConfig.tagDefaults['pronoun']!.degree, 0);

    expect(board.words.length, 3);
    expect(board.words[0].tags, ['pronoun']);
    expect(board.words[0].musicalRole, isNull); // tag-driven, not override
    expect(board.words[1].musicalRole!.kind, MusicalRoleKind.note);
    expect(board.words[1].musicalRole!.degree, 3);
    expect(board.words[2].isMusical, isFalse);
  });
}
