import 'dart:ui' as ui;
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/character/character_types.dart';
import 'package:storia_kids/src/features/library/game/character/layer_sprite_set.dart';

/// Build a blank in-memory image of the given size (no asset bundle needed).
Future<ui.Image> _blankImage(int w, int h) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  return recorder.endRecording().toImage(w, h);
}

void main() {
  test('columns derived from width / 460', () async {
    final img = await _blankImage(460 * 6, 460 * 5); // 6-col walk sheet
    final set = LayerSpriteSet.fromImage(img);
    expect(set.columns, 6);
  });

  test('framesFor returns one sprite per column on the right row', () async {
    final img = await _blankImage(460 * 4, 460 * 5); // 4-col run sheet
    final set = LayerSpriteSet.fromImage(img);
    final frames = set.framesFor(Facing.side); // row index 2
    expect(frames.length, 4);
    expect(frames.first.srcPosition, Vector2(0, 460 * Facing.side.index.toDouble()));
    expect(frames.first.srcSize, Vector2(460, 460));
    expect(frames.last.srcPosition, Vector2(460 * 3, 460 * Facing.side.index.toDouble()));
  });
}
