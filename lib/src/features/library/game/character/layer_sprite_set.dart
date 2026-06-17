import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';

import 'character_types.dart';

const double kFrameCell = 460.0;
const int kFacingRows = 5;

/// Slices one animation+layer+variant sheet into per-facing frame lists.
/// The only place that knows sheet geometry. Source bytes come from the
/// injected loader (Task 4) — this class only slices a [ui.Image].
class LayerSpriteSet {
  LayerSpriteSet.fromImage(this._image)
      : columns = _image.width ~/ kFrameCell.toInt() {
    assert(
      _image.width % kFrameCell == 0,
      'sheet width ${_image.width} not a multiple of $kFrameCell',
    );
    assert(
      _image.height == kFrameCell * kFacingRows,
      'sheet height ${_image.height} != ${kFrameCell * kFacingRows}',
    );
  }

  final ui.Image _image;
  final int columns;
  final Map<Facing, List<Sprite>> _cache = {};

  List<Sprite> framesFor(Facing facing) {
    return _cache.putIfAbsent(facing, () {
      final rows = _image.height ~/ kFrameCell.toInt();
      // Guard against degenerate sheets: in release mode, asserts don't run.
      // If rows <= 0, clamp would throw (Invalid argument(s)), so default to row 0.
      final row = rows <= 0 ? 0 : facing.index.clamp(0, rows - 1);
      return List.generate(
        columns,
        (col) => Sprite(
          _image,
          srcPosition: Vector2(col * kFrameCell, row * kFrameCell),
          srcSize: Vector2(kFrameCell, kFrameCell),
        ),
        growable: false,
      );
    });
  }
}
