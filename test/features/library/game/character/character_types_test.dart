import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/character/character_types.dart';

void main() {
  const idle = FacingResult(Facing.front, false);

  group('facingFromVelocity', () {
    test('zero velocity keeps last facing', () {
      expect(facingFromVelocity(Vector2.zero(), idle), idle);
    });
    test('down (screen +y) is front, not mirrored', () {
      expect(facingFromVelocity(Vector2(0, 1), idle),
          const FacingResult(Facing.front, false));
    });
    test('up (screen -y) is back', () {
      expect(facingFromVelocity(Vector2(0, -1), idle),
          const FacingResult(Facing.back, false));
    });
    test('left is side, not mirrored', () {
      expect(facingFromVelocity(Vector2(-1, 0), idle),
          const FacingResult(Facing.side, false));
    });
    test('right is side, mirrored', () {
      expect(facingFromVelocity(Vector2(1, 0), idle),
          const FacingResult(Facing.side, true));
    });
    test('down-right is frontDiag mirrored', () {
      expect(facingFromVelocity(Vector2(1, 1), idle),
          const FacingResult(Facing.frontDiag, true));
    });
    test('up-left is backDiag not mirrored', () {
      expect(facingFromVelocity(Vector2(-1, -1), idle),
          const FacingResult(Facing.backDiag, false));
    });
  });

  test('CharacterLayer z-order: body bottom, accessory top', () {
    expect(CharacterLayer.body.index, 0);
    expect(CharacterLayer.accessory.index,
        CharacterLayer.values.length - 1);
  });
}
