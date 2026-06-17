import 'dart:ui' as ui;

import 'package:flame/cache.dart';

import 'character_types.dart';

/// Resolves (animation, layer file) -> decoded image. The seam sub-project 2
/// reimplements against Supabase Storage; this default reads bundled assets.
typedef CharacterImageLoader =
    Future<ui.Image> Function(CharacterAnimation anim, String layerFile);

/// Bundled subfolder per animation (under assets/images/characters/default/).
const Map<CharacterAnimation, String> kAnimDir = {
  CharacterAnimation.idle: 'idle',
  CharacterAnimation.walk: 'walk',
  CharacterAnimation.run: 'run',
  CharacterAnimation.interact: 'interact',
  CharacterAnimation.sit: 'sit',
  CharacterAnimation.getUp: 'getup',
};

CharacterImageLoader bundledLoader(Images images) {
  return (anim, layerFile) =>
      images.load('characters/default/${kAnimDir[anim]}/$layerFile.png');
}
