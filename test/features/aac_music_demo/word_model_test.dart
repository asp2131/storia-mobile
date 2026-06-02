import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';

void main() {
  test('AacWord without a role is not musical', () {
    const word = AacWord(id: 'go', label: 'go', row: 0, col: 0);
    expect(word.isMusical, isFalse);
    expect(word.tags, isEmpty);
  });

  test('AacWord with a note role is musical', () {
    const word = AacWord(
      id: 'i',
      label: 'I',
      row: 1,
      col: 0,
      tags: ['pronoun'],
      musicalRole: MusicalRole.note(0),
    );
    expect(word.isMusical, isTrue);
    expect(word.musicalRole!.kind, MusicalRoleKind.note);
    expect(word.musicalRole!.degree, 0);
    expect(word.tags, ['pronoun']);
  });

  test('chord role carries voice count', () {
    const role = MusicalRole.chord(0, voices: 3);
    expect(role.kind, MusicalRoleKind.chord);
    expect(role.voices, 3);
  });
}
