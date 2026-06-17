import 'package:flame/extensions.dart';

enum CharacterAnimation { idle, walk, run, interact, sit, getUp }

/// The 5 sheet rows, top→bottom. Index == row index in the sprite sheet.
enum Facing { front, frontDiag, side, backDiag, back }

/// A resolved facing plus whether to mirror horizontally (scale.x = -1).
class FacingResult {
  const FacingResult(this.facing, this.mirrored);
  final Facing facing;
  final bool mirrored;

  @override
  bool operator ==(Object other) =>
      other is FacingResult &&
      other.facing == facing &&
      other.mirrored == mirrored;

  @override
  int get hashCode => Object.hash(facing, mirrored);

  @override
  String toString() => 'FacingResult($facing, mirrored: $mirrored)';
}

/// Maps a movement velocity to a facing row + mirror flag.
/// Screen space: +y is down (toward viewer) = front; -y is up = back.
/// Canonical sprites face LEFT; moving right mirrors them.
FacingResult facingFromVelocity(Vector2 v, FacingResult last) {
  if (v.length2 < 1e-6) return last;
  final mirrored = v.x > 1e-6; // moving right -> mirror
  final ax = v.x.abs();
  final ay = v.y.abs();

  // Near-vertical: front (down, +y) or back (up, -y).
  if (ax < ay * 0.4142) {
    return FacingResult(v.y >= 0 ? Facing.front : Facing.back, false);
  }
  // Near-horizontal: side.
  if (ay < ax * 0.4142) {
    return FacingResult(Facing.side, mirrored);
  }
  // Diagonal.
  return FacingResult(
      v.y >= 0 ? Facing.frontDiag : Facing.backDiag, mirrored);
}

/// Declaration order is render z-order (bottom→top). Use `.index` as z.
enum CharacterLayer {
  body,
  face,
  bodySuit,
  pants,
  shoes,
  torso, // shirt / dress / armor (exclusive)
  sleeves,
  necklace,
  bag,
  scarf,
  bowtie,
  head, // hair / hat (exclusive)
  accessory, // bow / horns (exclusive)
}
