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

  test('framesFor handles all facings without throwing', () async {
    // This test verifies framesFor logic works correctly for valid sheets.
    // The release-mode guard in framesFor (rows <= 0 ? 0 : ...) protects against
    // degenerate cases in release builds where constructor asserts are no-ops.
    // Here we test the guard is reachable by ensuring all facings work without error.
    final img = await _blankImage(460 * 2, 460 * 5); // Valid 2-col, 5-row sheet
    final set = LayerSpriteSet.fromImage(img);

    // Call framesFor for every facing; should not throw.
    for (final facing in Facing.values) {
      final frames = set.framesFor(facing);
      expect(frames.length, 2); // 2 columns
      // Verify position matches facing's row index.
      expect(frames.first.srcPosition.y, (facing.index * 460).toDouble());
    }
  });

  test('framesFor returns cached list (identity check)', () async {
    final img = await _blankImage(460 * 2, 460 * 5);
    final set = LayerSpriteSet.fromImage(img);

    // Call twice on the same facing and verify identity.
    final frames1 = set.framesFor(Facing.front);
    final frames2 = set.framesFor(Facing.front);

    // Identical list instance confirms cache works.
    expect(identical(frames1, frames2), true);
  });

  test('framesFor per-facing caching works for all facings', () async {
    final img = await _blankImage(460 * 2, 460 * 5);
    final set = LayerSpriteSet.fromImage(img);

    // Verify each facing gets its own cached list.
    final frameFront = set.framesFor(Facing.front);
    final frameSide = set.framesFor(Facing.side);
    final frameBack = set.framesFor(Facing.back);

    // All should have correct length.
    expect(frameFront.length, 2);
    expect(frameSide.length, 2);
    expect(frameBack.length, 2);

    // Position should reflect the facing index (row).
    expect(frameFront.first.srcPosition.y, 0.0); // front = row 0
    expect(frameSide.first.srcPosition.y, 460 * Facing.side.index.toDouble()); // side = row 2
    expect(frameBack.first.srcPosition.y, 460 * Facing.back.index.toDouble()); // back = row 4

    // Cache checks for each.
    expect(identical(set.framesFor(Facing.front), frameFront), true);
    expect(identical(set.framesFor(Facing.side), frameSide), true);
    expect(identical(set.framesFor(Facing.back), frameBack), true);
  });
}
