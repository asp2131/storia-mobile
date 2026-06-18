import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/character/character_image_loader.dart';
import 'package:storia_kids/src/features/library/game/character/character_types.dart';

void main() {
  test('builds Supabase character asset paths', () {
    expect(kCharacterAssetsBucket, 'character assets');
    expect(
      characterAssetPath(CharacterAnimation.idle, 'Layer5_Shirt_Blue'),
      'CustomaizableCharacter/Idle/Layer5_Shirt_Blue.png',
    );
    expect(
      characterAssetPath(CharacterAnimation.run, 'Layer5_Shirt_Blue'),
      'CustomaizableCharacter/Run(HoldingToolOrNot)/Layer5_Shirt_Blue.png',
    );
    expect(
      characterAssetPath(CharacterAnimation.getUp, 'Layer0_Body_Skin1'),
      'CustomaizableCharacter/GetUp/Layer0_Body_Skin1.png',
    );
  });
}
