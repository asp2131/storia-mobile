import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/character/character_types.dart';
import 'package:storia_kids/src/features/library/game/character/character_selection.dart';

void main() {
  test('defaults equips body + face at minimum', () {
    final s = CharacterSelection.defaults();
    expect(s[CharacterLayer.body], isNotNull);
    expect(s[CharacterLayer.face], isNotNull);
  });

  test('copyWith replaces one layer, leaves others', () {
    final s = CharacterSelection.defaults();
    final body = s[CharacterLayer.body];
    final s2 = s.copyWith(CharacterLayer.torso, 'Layer5_Shirt_Red');
    expect(s2[CharacterLayer.torso], 'Layer5_Shirt_Red');
    expect(s2[CharacterLayer.body], body);
    expect(s[CharacterLayer.torso], isNot('Layer5_Shirt_Red')); // immutable
  });

  test('copyWith with null clears a slot', () {
    final s = CharacterSelection.defaults().copyWith(CharacterLayer.head, null);
    expect(s[CharacterLayer.head], isNull);
    expect(s.equipped.any((e) => e.key == CharacterLayer.head), isFalse);
  });

  test('equipped is in z-order', () {
    final s = CharacterSelection.from({
      CharacterLayer.head: 'h',
      CharacterLayer.body: 'b',
    });
    expect(s.equipped.map((e) => e.key).toList(),
        [CharacterLayer.body, CharacterLayer.head]);
  });

  test('value equality', () {
    expect(CharacterSelection.defaults(), CharacterSelection.defaults());
  });
}
