import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';

/// Renders the isometric TMX ground map inside the Flame world,
/// repeating it horizontally to cover the full [worldWidth].
class IsometricGroundComponent extends PositionComponent {
  IsometricGroundComponent({
    required this.groundBaselineY,
    required this.worldWidth,
    required this.screenHeight,
  });

  final double groundBaselineY;
  final double worldWidth;
  final double screenHeight;

  @override
  Future<void> onLoad() async {
    try {
      const int mapCols = 32;
      const int mapRows = 32;

      // Scale tiles so one map instance spans a reasonable width.
      // Using a fixed tile size so the art looks consistent regardless of world width.
      final destTileW = 2 * screenHeight * 0.6 / (mapCols + mapRows);
      final destTileH = destTileW / 2;

      final mapPixelWidth = (mapCols + mapRows) * destTileW / 2;
      final mapPixelHeight = (mapCols + mapRows) * destTileH / 2;

      // How many copies needed to cover the full world width (plus padding).
      final copies = (worldWidth / mapPixelWidth).ceil() + 1;

      final offsetY = groundBaselineY - mapPixelHeight * 0.34;

      for (var i = 0; i < copies; i++) {
        final tiledMap = await TiledComponent.load(
          'storia_ground.tmx',
          Vector2(destTileW, destTileH),
        );

        tiledMap.position = Vector2(i * mapPixelWidth, offsetY);
        add(tiledMap);
      }

      debugPrint(
        'TMX tiled: $copies copies, '
        'tileSize=${destTileW.toStringAsFixed(1)}x${destTileH.toStringAsFixed(1)}, '
        'mapWidth=${mapPixelWidth.toStringAsFixed(0)}, '
        'worldWidth=${worldWidth.toStringAsFixed(0)}',
      );
    } catch (e, st) {
      debugPrint('IsometricGroundComponent FAILED: $e');
      debugPrint('$st');
    }
  }
}
