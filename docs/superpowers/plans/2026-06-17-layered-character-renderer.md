# Layered Character Renderer + Movement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the library map's flat single-sheet `PlayerComponent` with a layered, customizable character rig (idle/walk/run/interact/sit/getUp, 5-direction facing) driven by a bundled default outfit, keeping the existing public API so `library_game.dart` is a drop-in swap.

**Architecture:** A `PlayerComponent` (PositionComponent container) owns one dumb `SpriteComponent` child per visible layer, z-ordered. The parent owns a single frame clock and, each tick, assigns every child the sprite for the current (animation, facing, frame) — guaranteeing lockstep with zero ticker drift. Horizontal mirroring is done with `scale.x = -1` on the parent so all layers flip together and stay aligned. Sprite slicing is isolated in `LayerSpriteSet`; byte loading is isolated behind a `CharacterImageLoader` function (the seam sub-project 2 swaps for Supabase).

**Tech Stack:** Flutter, Flame ^1.21.0, Dart, `flutter_test`. Package name `storia_kids`.

## Global Constraints

- Frame cell is **460×460 px**; every sheet is `cols × 5 rows`; rows are facings; cols = `image.width / 460`. Never hardcode column counts — derive them.
- Public API of `PlayerComponent` must stay identical: constructor `PlayerComponent({required Vector2 startPosition})`, `set targetX(double?)`, `setWaypoints(List<Vector2>)`, `bool get isMoving`, `int get horizontalDirection` (-1/0/1), `bool get hasArrived`, and inherited `position`.
- Flame `Images` prefix is `assets/images/`; load paths are relative to it.
- Movement constants stay as-is: speed `150.0` px/s, arrival threshold `4.0` px, player height `72.0` px.
- Animation set for v1: `idle, walk, run, interact, sit, getUp`. No tool/combat anims.
- TDD: every non-trivial unit gets a failing test first. Commit after each task.

---

### Task 1: Character type primitives (enums + facing math)

**Files:**
- Create: `lib/src/features/library/game/character/character_types.dart`
- Test: `test/features/library/game/character/character_types_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum CharacterAnimation { idle, walk, run, interact, sit, getUp }`
  - `enum Facing { front, frontDiag, side, backDiag, back }` (the 5 rows; index = row).
  - `class FacingResult { final Facing facing; final bool mirrored; const FacingResult(this.facing, this.mirrored); }` with `==`/`hashCode`.
  - `FacingResult facingFromVelocity(Vector2 v, FacingResult last)` — returns `last` when `v.length2` is ~0; else maps the velocity angle to a facing + mirror.
  - `enum CharacterLayer { body, face, bodySuit, pants, shoes, torso, sleeves, necklace, bag, scarf, bowtie, head, accessory }` — declaration order **is** z-order (bottom→top); use `.index` as z.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/library/game/character/character_types_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/library/game/character/character_types_test.dart`
Expected: FAIL — `character_types.dart` does not exist / symbols undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/library/game/character/character_types.dart
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
```

> Note: the `0.4142` thresholds are `tan(22.5°)` — they split the circle into the 8 sectors (front, frontDiag, side, backDiag, back × mirror). `// ponytail: 8-way bucketing from 5 rows + mirror; finer angles only if movement looks wrong.`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/library/game/character/character_types_test.dart`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/library/game/character/character_types.dart test/features/library/game/character/character_types_test.dart
git commit -m "feat(character): add character type primitives + facing math"
```

---

### Task 2: CharacterSelection value type

**Files:**
- Create: `lib/src/features/library/game/character/character_selection.dart`
- Test: `test/features/library/game/character/character_selection_test.dart`

**Interfaces:**
- Consumes: `CharacterLayer` from Task 1.
- Produces:
  - `class CharacterSelection` — immutable wrapper over `Map<CharacterLayer, String?>` where value is a layer **file name without extension** (e.g. `"Layer5_Shirt_Blue"`) or `null` = empty slot.
    - `const CharacterSelection(this._layers)` (private map field, copied defensively in factory).
    - `factory CharacterSelection.from(Map<CharacterLayer, String?> layers)`
    - `factory CharacterSelection.defaults()` — the bundled default outfit (see Task 5 asset list).
    - `String? operator [](CharacterLayer layer)`
    - `CharacterSelection copyWith(CharacterLayer layer, String? value)`
    - `Iterable<MapEntry<CharacterLayer, String?>> get equipped` — non-null entries, in z-order.
    - `==` / `hashCode` over the map.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/library/game/character/character_selection_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/character/character_types.dart';
import 'package:storia_kids/src/features/library/game/character/character_selection.dart';

void main() {
  test('defaults equips body + face at minimum', () {
    final s = CharacterSelection.defaults();
    expect(s[CharacterLayer.body], isNotNull);
    expect(s[CharacterLayer.face], isNotNull);
  });

  test('copyWith replaces one layer, leaves others', () {
    final s = CharacterSelection.defaults();
    final body = s[CharacterLayer.body];
    final s2 = s.copyWith(CharacterLayer.torso, 'Layer5_Shirt_Red');
    expect(s2[CharacterLayer.torso], 'Layer5_Shirt_Red');
    expect(s2[CharacterLayer.body], body);
    expect(s[CharacterLayer.torso], isNot('Layer5_Shirt_Red')); // immutable
  });

  test('copyWith with null clears a slot', () {
    final s = CharacterSelection.defaults().copyWith(CharacterLayer.head, null);
    expect(s[CharacterLayer.head], isNull);
    expect(s.equipped.any((e) => e.key == CharacterLayer.head), isFalse);
  });

  test('equipped is in z-order', () {
    final s = CharacterSelection.from({
      CharacterLayer.head: 'h',
      CharacterLayer.body: 'b',
    });
    expect(s.equipped.map((e) => e.key).toList(),
        [CharacterLayer.body, CharacterLayer.head]);
  });

  test('value equality', () {
    expect(CharacterSelection.defaults(), CharacterSelection.defaults());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/library/game/character/character_selection_test.dart`
Expected: FAIL — `character_selection.dart` missing.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/library/game/character/character_selection.dart
import 'character_types.dart';

class CharacterSelection {
  const CharacterSelection._(this._layers);

  factory CharacterSelection.from(Map<CharacterLayer, String?> layers) =>
      CharacterSelection._(Map.unmodifiable({...layers}));

  /// Bundled default outfit. Asset files for these keys are copied in Task 5.
  factory CharacterSelection.defaults() => CharacterSelection.from(const {
        CharacterLayer.body: 'Layer0_Body_Skin1',
        CharacterLayer.face: 'Layer1_Face_Regular',
        CharacterLayer.pants: 'Layer3_Pants_Blue',
        CharacterLayer.shoes: 'Layer4_Shoes_Brown',
        CharacterLayer.torso: 'Layer5_Shirt_Blue',
        CharacterLayer.head: 'Layer11_ShortHair_Color1',
      });

  final Map<CharacterLayer, String?> _layers;

  String? operator [](CharacterLayer layer) => _layers[layer];

  CharacterSelection copyWith(CharacterLayer layer, String? value) {
    final next = {..._layers};
    next[layer] = value;
    return CharacterSelection.from(next);
  }

  /// Non-null entries in z-order (CharacterLayer declaration order).
  Iterable<MapEntry<CharacterLayer, String?>> get equipped =>
      CharacterLayer.values
          .where((l) => _layers[l] != null)
          .map((l) => MapEntry(l, _layers[l]));

  @override
  bool operator ==(Object other) {
    if (other is! CharacterSelection) return false;
    if (other._layers.length != _layers.length) return false;
    for (final l in CharacterLayer.values) {
      if (other._layers[l] != _layers[l]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hashAll(CharacterLayer.values.map((l) => _layers[l]));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/library/game/character/character_selection_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/library/game/character/character_selection.dart test/features/library/game/character/character_selection_test.dart
git commit -m "feat(character): add CharacterSelection value type"
```

---

### Task 3: LayerSpriteSet (sheet slicing)

**Files:**
- Create: `lib/src/features/library/game/character/layer_sprite_set.dart`
- Test: `test/features/library/game/character/layer_sprite_set_test.dart`

**Interfaces:**
- Consumes: `Facing` from Task 1.
- Produces:
  - `const double kFrameCell = 460.0;` and `const int kFacingRows = 5;`
  - `class LayerSpriteSet`:
    - `LayerSpriteSet.fromImage(ui.Image image)` — validates `width % 460 == 0` and `height == 460*5` (assert in debug; in release clamps to available rows/cols), computes `int get columns => image.width ~/ 460`.
    - `List<Sprite> framesFor(Facing facing)` — the `columns` sprites of that row (row = `facing.index`), left→right. Cached per facing.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/library/game/character/layer_sprite_set_test.dart
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
    expect(frames.first.srcPosition, Vector2(0, 460 * Facing.side.index));
    expect(frames.first.srcSize, Vector2(460, 460));
    expect(frames.last.srcPosition, Vector2(460 * 3, 460 * Facing.side.index));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/library/game/character/layer_sprite_set_test.dart`
Expected: FAIL — `layer_sprite_set.dart` missing.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/library/game/character/layer_sprite_set.dart
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';

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
      final row = facing.index.clamp(0, rows - 1);
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/library/game/character/layer_sprite_set_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/library/game/character/layer_sprite_set.dart test/features/library/game/character/layer_sprite_set_test.dart
git commit -m "feat(character): add LayerSpriteSet sheet slicing"
```

---

### Task 4: Bundle the default outfit assets + image loader seam

**Files:**
- Create (copied PNGs): `assets/images/characters/default/{idle,walk,run,interact,sit,getup}/*.png`
- Create: `lib/src/features/library/game/character/character_image_loader.dart`
- Modify: `pubspec.yaml` (assets list)

**Interfaces:**
- Consumes: `CharacterAnimation` from Task 1.
- Produces:
  - `typedef CharacterImageLoader = Future<ui.Image> Function(CharacterAnimation anim, String layerFile);`
  - `const Map<CharacterAnimation, String> kAnimDir = {...}` mapping anim → bundled subfolder name (`idle`, `walk`, `run`, `interact`, `sit`, `getup`).
  - `CharacterImageLoader bundledLoader(Images images)` — returns a closure that loads `characters/default/<dir>/<layerFile>.png` via Flame `Images`.

This task has no unit test (it's asset wiring + a thin closure); it is verified by Task 5's component load and a manual run. Fold its deliverable into Task 5's gate.

- [ ] **Step 1: Verify the chosen variant files exist in every source anim dir**

```bash
SRC="../Ultimate_Protagonist/AnimationSheets/CustomaizableCharacter"
for d in Idle Walk "Run(HoldingToolOrNot)" Interact Sit GetUp; do
  echo "== $d =="
  for f in Layer0_Body_Skin1 Layer1_Face_Regular Layer3_Pants_Blue \
           Layer4_Shoes_Brown Layer5_Shirt_Blue Layer11_ShortHair_Color1; do
    [ -f "$SRC/$d/$f.png" ] && echo "  ok $f" || echo "  MISSING $f"
  done
done
```
Expected: all `ok`. If any face variant is `MISSING` (some anims use `Closed` not `Regular`), substitute the present face variant for that anim's copied file and note it — the default selection key only needs to match the file you copy.

- [ ] **Step 2: Copy the default outfit into bundled assets**

```bash
SRC="../Ultimate_Protagonist/AnimationSheets/CustomaizableCharacter"
DST="assets/images/characters/default"
declare -A MAP=( [idle]=Idle [walk]=Walk [run]="Run(HoldingToolOrNot)" \
                 [interact]=Interact [sit]=Sit [getup]=GetUp )
FILES="Layer0_Body_Skin1 Layer1_Face_Regular Layer3_Pants_Blue \
       Layer4_Shoes_Brown Layer5_Shirt_Blue Layer11_ShortHair_Color1"
for dest in "${!MAP[@]}"; do
  mkdir -p "$DST/$dest"
  for f in $FILES; do
    cp "$SRC/${MAP[$dest]}/$f.png" "$DST/$dest/$f.png"
  done
done
du -sh "$DST"   # sanity: should be small (<15MB)
```
Expected: copies succeed; `du` shows a small footprint.

- [ ] **Step 3: Register asset dirs in pubspec.yaml**

Add under the existing `flutter: assets:` list (each subdir listed — Flutter asset globs are non-recursive):

```yaml
    - assets/images/characters/default/idle/
    - assets/images/characters/default/walk/
    - assets/images/characters/default/run/
    - assets/images/characters/default/interact/
    - assets/images/characters/default/sit/
    - assets/images/characters/default/getup/
```

- [ ] **Step 4: Write the loader seam**

```dart
// lib/src/features/library/game/character/character_image_loader.dart
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
```

- [ ] **Step 5: Run analyzer (no test for this task)**

Run: `flutter analyze lib/src/features/library/game/character/character_image_loader.dart`
Expected: No issues. (Committed together with Task 5.)

---

### Task 5: Rewrite PlayerComponent as a layered rig

**Files:**
- Rewrite: `lib/src/features/library/game/player_component.dart`
- Test: `test/features/library/game/player_movement_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces (public API — unchanged from old component plus additive methods):
  - `PlayerComponent({required Vector2 startPosition, CharacterSelection? selection, CharacterImageLoader? loader})`
  - `set targetX(double?)`, `void setWaypoints(List<Vector2>)`, `bool get isMoving`, `int get horizontalDirection`, `bool get hasArrived`.
  - `void playOneShot(CharacterAnimation anim)` — plays interact/sit/getUp once, then returns to idle. Ignored for looping anims.
  - `@visibleForTesting void stepMovement(double dt)` — advances waypoint following + facing/direction, no rendering. `update()` calls this then syncs frames.

**Animation specs** (loop + per-frame seconds), declared in the file:
```dart
const Map<CharacterAnimation, ({double step, bool loop})> _kAnimSpec = {
  CharacterAnimation.idle:     (step: 0.12, loop: true),
  CharacterAnimation.walk:     (step: 0.09, loop: true),
  CharacterAnimation.run:      (step: 0.06, loop: true),
  CharacterAnimation.interact: (step: 0.08, loop: false),
  CharacterAnimation.sit:      (step: 0.08, loop: false),
  CharacterAnimation.getUp:    (step: 0.08, loop: false),
};
```

- [ ] **Step 1: Write the failing movement test**

```dart
// test/features/library/game/player_movement_test.dart
import 'package:flame/extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/library/game/player_component.dart';

void main() {
  PlayerComponent make() =>
      PlayerComponent(startPosition: Vector2.zero());

  test('starts arrived and not moving', () {
    final p = make();
    expect(p.hasArrived, isTrue);
    expect(p.isMoving, isFalse);
  });

  test('walks toward a single waypoint and arrives', () {
    final p = make()..setWaypoints([Vector2(100, 0)]);
    expect(p.isMoving, isTrue);
    // 150 px/s; 100px needs ~0.67s. Step 2s in 20 ticks.
    for (var i = 0; i < 20; i++) {
      p.stepMovement(0.1);
    }
    expect(p.hasArrived, isTrue);
    expect(p.isMoving, isFalse);
    expect(p.position.x, closeTo(100, 0.5));
  });

  test('horizontalDirection is +1 moving right, -1 moving left', () {
    final p = make()..setWaypoints([Vector2(50, 0)]);
    p.stepMovement(0.05);
    expect(p.horizontalDirection, 1);
    final q = make()..setWaypoints([Vector2(-50, 0)]);
    q.stepMovement(0.05);
    expect(q.horizontalDirection, -1);
  });

  test('targetX setter to null clears movement', () {
    final p = make()..setWaypoints([Vector2(100, 0)]);
    p.targetX = null;
    expect(p.hasArrived, isTrue);
    expect(p.isMoving, isFalse);
  });

  test('follows multiple waypoints in order', () {
    final p = make()..setWaypoints([Vector2(30, 0), Vector2(30, 30)]);
    for (var i = 0; i < 30; i++) {
      p.stepMovement(0.1);
    }
    expect(p.hasArrived, isTrue);
    expect(p.position.x, closeTo(30, 0.5));
    expect(p.position.y, closeTo(30, 0.5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/library/game/player_movement_test.dart`
Expected: FAIL — old `PlayerComponent` has no `stepMovement` / new constructor.

- [ ] **Step 3: Rewrite the implementation**

```dart
// lib/src/features/library/game/player_component.dart
import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';

import 'character/character_image_loader.dart';
import 'character/character_selection.dart';
import 'character/character_types.dart';
import 'character/layer_sprite_set.dart';
import 'library_game.dart';

const double _kMoveSpeed = 150.0;
const double _kArrivalThreshold = 4.0;
const double _kPlayerHeight = 72.0;

const Map<CharacterAnimation, ({double step, bool loop})> _kAnimSpec = {
  CharacterAnimation.idle: (step: 0.12, loop: true),
  CharacterAnimation.walk: (step: 0.09, loop: true),
  CharacterAnimation.run: (step: 0.06, loop: true),
  CharacterAnimation.interact: (step: 0.08, loop: false),
  CharacterAnimation.sit: (step: 0.08, loop: false),
  CharacterAnimation.getUp: (step: 0.08, loop: false),
};

/// Layered, customizable player. A container that keeps one [SpriteComponent]
/// per equipped layer in lockstep via a single parent-owned frame clock.
class PlayerComponent extends PositionComponent
    with HasGameReference<LibraryGame> {
  PlayerComponent({
    required Vector2 startPosition,
    CharacterSelection? selection,
    CharacterImageLoader? loader,
  })  : _startPosition = startPosition,
        _selection = selection ?? CharacterSelection.defaults(),
        _loader = loader,
        super(anchor: Anchor.bottomCenter);

  final Vector2 _startPosition;
  CharacterSelection _selection;
  CharacterImageLoader? _loader;

  // ── Movement state (ported from the old component) ──
  List<Vector2> _waypoints = [];
  int _currentWaypointIndex = 0;
  bool _arrived = true;
  int _lastDirection = 0;

  bool get hasArrived => _arrived;
  bool get isMoving => _waypoints.isNotEmpty && !_arrived;
  int get horizontalDirection => _lastDirection;

  void setWaypoints(List<Vector2> waypoints) {
    _waypoints = waypoints;
    _currentWaypointIndex = 0;
    _arrived = false;
  }

  set targetX(double? value) {
    if (value == null) {
      _waypoints = [];
      _currentWaypointIndex = 0;
      _arrived = true;
      return;
    }
    setWaypoints([Vector2(value, position.y)]);
  }

  // ── Animation state ──
  // sprites[anim][layer] -> LayerSpriteSet
  final Map<CharacterAnimation, Map<CharacterLayer, LayerSpriteSet>> _sets = {};
  final Map<CharacterLayer, SpriteComponent> _children = {};
  CharacterAnimation _anim = CharacterAnimation.idle;
  FacingResult _facing = const FacingResult(Facing.front, false);
  double _frameTimer = 0;
  int _frameIndex = 0;
  CharacterAnimation? _oneShotReturn; // set while a one-shot plays

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _loader ??= bundledLoader(game.images);
    size = Vector2.all(_kPlayerHeight);

    // Load every equipped layer for every animation.
    for (final anim in CharacterAnimation.values) {
      final byLayer = <CharacterLayer, LayerSpriteSet>{};
      for (final entry in _selection.equipped) {
        try {
          final img = await _loader!(anim, entry.value!);
          byLayer[entry.key] = LayerSpriteSet.fromImage(img);
        } catch (e) {
          // Missing sheet for this layer/anim: skip it, keep the rest.
          debugPrint('character: missing ${entry.value} for $anim ($e)');
        }
      }
      _sets[anim] = byLayer;
    }

    // Create one child SpriteComponent per equipped layer, in z-order.
    for (final entry in _selection.equipped) {
      final child = SpriteComponent(
        size: Vector2.all(_kPlayerHeight),
        anchor: Anchor.topLeft,
      )..priority = entry.key.index;
      _children[entry.key] = child;
      await add(child);
    }

    position = _startPosition.clone();
    _applyFrame(); // seed sprites
  }

  // ── Update loop ──
  @override
  void update(double dt) {
    super.update(dt);
    stepMovement(dt);
    _advanceAnimation(dt);
  }

  @visibleForTesting
  void stepMovement(double dt) {
    // Pick the active anim from movement (one-shots take priority).
    if (_oneShotReturn == null) {
      _setAnim(isMoving ? CharacterAnimation.walk : CharacterAnimation.idle);
    }

    if (_waypoints.isEmpty || _arrived) return;
    if (_currentWaypointIndex >= _waypoints.length) {
      _arrived = true;
      return;
    }
    final target = _waypoints[_currentWaypointIndex];
    final delta = target - position;
    final distance = delta.length;
    if (distance < _kArrivalThreshold) {
      position.setFrom(target);
      _currentWaypointIndex++;
      if (_currentWaypointIndex >= _waypoints.length) _arrived = true;
      return;
    }
    final dir = delta.normalized();
    position.add(dir * _kMoveSpeed * dt);

    final hDir = delta.x.sign.toInt();
    if (hDir != 0) _lastDirection = hDir;
    _setFacing(facingFromVelocity(delta, _facing));
  }

  /// Play a non-looping anim once, then return to idle.
  void playOneShot(CharacterAnimation anim) {
    final spec = _kAnimSpec[anim]!;
    if (spec.loop) return;
    _oneShotReturn = CharacterAnimation.idle;
    _setAnim(anim, force: true);
  }

  // ── Internal animation helpers ──
  void _setAnim(CharacterAnimation anim, {bool force = false}) {
    if (!force && anim == _anim) return;
    _anim = anim;
    _frameTimer = 0;
    _frameIndex = 0;
    _applyFrame();
  }

  void _setFacing(FacingResult facing) {
    if (facing == _facing) return;
    _facing = facing;
    scale.x = facing.mirrored ? -1 : 1;
    _applyFrame();
  }

  void _advanceAnimation(double dt) {
    final spec = _kAnimSpec[_anim]!;
    final frames = _frameCountForCurrent();
    if (frames <= 1) return;
    _frameTimer += dt;
    while (_frameTimer >= spec.step) {
      _frameTimer -= spec.step;
      _frameIndex++;
      if (_frameIndex >= frames) {
        if (spec.loop) {
          _frameIndex = 0;
        } else {
          _frameIndex = frames - 1;
          // One-shot finished -> drop back to idle.
          if (_oneShotReturn != null) {
            final back = _oneShotReturn!;
            _oneShotReturn = null;
            _setAnim(back, force: true);
            return;
          }
        }
      }
      _applyFrame();
    }
  }

  int _frameCountForCurrent() {
    final byLayer = _sets[_anim];
    if (byLayer == null || byLayer.isEmpty) return 0;
    // All layers of one anim share the same column count; read any.
    return byLayer.values.first.framesFor(_facing.facing).length;
  }

  void _applyFrame() {
    final byLayer = _sets[_anim];
    if (byLayer == null) return;
    for (final entry in _children.entries) {
      final set = byLayer[entry.key];
      if (set == null) {
        entry.value.sprite = null;
        continue;
      }
      final frames = set.framesFor(_facing.facing);
      if (frames.isEmpty) continue;
      entry.value.sprite = frames[_frameIndex.clamp(0, frames.length - 1)];
    }
  }
}
```

> `// ponytail: single parent clock drives dumb SpriteComponent children — no per-layer tickers to desync. Movement uses walk; run is loaded and switchable via _setAnim but not auto-triggered yet.`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/library/game/player_movement_test.dart`
Expected: PASS (5 tests). `stepMovement` runs without a mounted game because it touches no rendering.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze lib/src/features/library/game/`
Expected: No issues.

```bash
git add lib/src/features/library/game/character/ lib/src/features/library/game/player_component.dart \
        test/features/library/game/player_movement_test.dart pubspec.yaml assets/images/characters/
git commit -m "feat(character): layered customizable PlayerComponent with bundled default outfit"
```

---

### Task 6: Trigger interact on book arrival + manual verification

**Files:**
- Modify: `lib/src/features/library/game/library_game.dart` (the arrival branch around line 604)

**Interfaces:**
- Consumes: `PlayerComponent.playOneShot` (Task 5), `CharacterAnimation` (Task 1).

This is a tiny additive wire-up; it has no isolated unit test (it depends on the live game loop). It is gated by a manual run.

- [ ] **Step 1: Read the arrival branch**

Run: `grep -n "hasArrived\|_pendingBookTargetX\|import " lib/src/features/library/game/library_game.dart | head`
Confirm there is a block that fires once when `_player.hasArrived` becomes true after a book tap (around line 604).

- [ ] **Step 2: Add the import**

Add near the other game imports:
```dart
import 'character/character_types.dart';
```

- [ ] **Step 3: Play interact on arrival**

In the branch that runs when the player has just arrived at a tapped book (the existing `if (_player.hasArrived) { ... }` that opens the book preview), add as the first line inside the arrival action:
```dart
        _player.playOneShot(CharacterAnimation.interact);
```
Only add it on the book-arrival path (where `_pendingBookTargetX` was set), not on every idle frame — guard with the same condition the existing code uses to detect a fresh arrival.

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/src/features/library/game/library_game.dart`
Expected: No issues.

- [ ] **Step 5: Manual run + visual check**

Run: `flutter run` (or the project's usual launch), open the library map.
Verify:
- Character renders layered (body + face + shirt + pants + shoes + hair), not a flat sprite.
- Tapping a book walks the character; it faces the travel direction (left/right mirror, up/down rows) and animates walk; returns to idle on stop.
- On reaching a book it plays the interact one-shot, then idles and the preview opens.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/library/game/library_game.dart
git commit -m "feat(character): play interact animation on book arrival"
```

---

## Self-Review

**Spec coverage:**
- Layered renderer (runtime children, lockstep) → Tasks 3, 5. ✓
- Public API drop-in → Task 5 (constructor + getters/setters preserved), Task 6 leaves `library_game` otherwise intact. ✓
- 5-direction facing + mirror → Task 1 (`facingFromVelocity`), Task 5 (`scale.x`). ✓
- Animation set idle/walk/run/interact/sit/getUp → Task 1 enum, Task 4 dirs, Task 5 specs. ✓
- `CharacterSelection` seam for sub-projects 2/3 → Task 2. ✓
- Image-source seam (`CharacterImageLoader`) for sub-project 2 → Task 4. ✓
- Bundled default outfit, small footprint → Task 4. ✓
- Error handling: missing sheet skipped, geometry asserts → Task 3 (asserts), Task 5 (try/catch). ✓
- Contextual interact trigger → Task 6. ✓
- Tests per non-trivial unit → Tasks 1,2,3,5. ✓

**Deferred (documented, not gaps):** run auto-trigger (loaded + switchable, no trigger yet); sit/getUp trigger source (methods exist, no caller yet) — both explicitly v1-optional in the spec.

**Placeholder scan:** none — all steps carry real code/commands.

**Type consistency:** `CharacterImageLoader(anim, layerFile)`, `LayerSpriteSet.fromImage` / `framesFor(Facing)`, `CharacterSelection.equipped` / `copyWith`, `PlayerComponent.stepMovement` / `playOneShot` — names match across Tasks 1–6.
