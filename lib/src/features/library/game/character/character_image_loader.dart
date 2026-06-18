import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/resilient_cache_manager.dart';
import 'character_types.dart';

/// Resolves (animation, layer file) -> decoded image.
typedef CharacterImageLoader =
    Future<ui.Image> Function(CharacterAnimation anim, String layerFile);

const String kCharacterAssetsBucket = 'character assets';
const String kCharacterAssetsPrefix = 'CustomaizableCharacter';

/// Supabase Storage folder per animation. Names match the uploaded source dirs.
const Map<CharacterAnimation, String> kRemoteAnimDir = {
  CharacterAnimation.idle: 'Idle',
  CharacterAnimation.walk: 'Walk',
  CharacterAnimation.run: 'Run(HoldingToolOrNot)',
  CharacterAnimation.interact: 'Interact',
  CharacterAnimation.sit: 'Sit',
  CharacterAnimation.getUp: 'GetUp',
};

String characterAssetPath(CharacterAnimation anim, String layerFile) =>
    '$kCharacterAssetsPrefix/${kRemoteAnimDir[anim]}/$layerFile.png';

final Map<String, Future<ui.Image>> _remoteImageCache = {};

CharacterImageLoader supabaseLoader([SupabaseClient? client]) {
  return (anim, layerFile) {
    final path = characterAssetPath(anim, layerFile);
    final cached = _remoteImageCache[path];
    if (cached != null) return cached;

    final future = _loadRemoteImage(client ?? Supabase.instance.client, path)
        .catchError((Object error) {
      _remoteImageCache.remove(path);
      throw error;
    });
    _remoteImageCache[path] = future;
    return future;
  };
}

Future<ui.Image> _loadRemoteImage(SupabaseClient client, String path) async {
  final url = client.storage.from(kCharacterAssetsBucket).getPublicUrl(path);
  final cache = await ResilientCacheManager.getInstance();
  final file = await cache.getSingleFile(url);
  return _decodeImage(await file.readAsBytes());
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
