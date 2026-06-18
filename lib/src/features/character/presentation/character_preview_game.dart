import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../library/game/character/character_selection.dart';
import '../../library/game/player_component.dart';

/// A tiny transparent Flame game that shows one idle character for the editor
/// preview. Rebuilds the character when the selection changes.
class CharacterPreviewGame extends FlameGame {
  CharacterPreviewGame(this._selection);

  CharacterSelection _selection;
  PlayerComponent? _player;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await _spawn();
  }

  Future<void> _spawn() async {
    _player?.removeFromParent();
    final player = PlayerComponent(
      startPosition: _anchorPoint(),
      selection: _selection,
      loadAllAnimations: false, // static idle preview never moves
    )..scale = Vector2.all(3.5); // static idle preview never mirrors
    _player = player;
    await add(player);
  }

  /// Swap to a new look (called as the user edits slots).
  void updateSelection(CharacterSelection selection) {
    _selection = selection;
    if (isLoaded) _spawn();
  }

  Vector2 _anchorPoint() => Vector2(size.x / 2, size.y * 0.82);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _player?.position = _anchorPoint();
  }
}
