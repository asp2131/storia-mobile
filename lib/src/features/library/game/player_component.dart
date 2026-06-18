import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'character/character_image_loader.dart';
import 'character/character_selection.dart';
import 'character/character_types.dart';
import 'character/layer_sprite_set.dart';

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
class PlayerComponent extends PositionComponent with HasGameReference {
  PlayerComponent({
    required Vector2 startPosition,
    CharacterSelection? selection,
    CharacterImageLoader? loader,
    this.loadAllAnimations = true,
  })  : _startPosition = startPosition,
        _selection = selection ?? activeSelection ?? CharacterSelection.defaults(),
        _loader = loader,
        super(anchor: Anchor.bottomCenter);

  /// When false, only the idle animation is loaded (e.g. the editor preview,
  /// which never moves). Saves loading the other 5 animation sheets.
  final bool loadAllAnimations;

  /// The latest persisted look, set by the selection store. Used as the
  /// fallback when no explicit [selection] is passed, so the library map
  /// picks up the player's saved character on (re)build.
  /// ponytail: a static, single-avatar shortcut — avoids threading selection
  /// through the engine port. Revisit if multiple distinct characters appear.
  static CharacterSelection? activeSelection;

  final Vector2 _startPosition;
  final CharacterSelection _selection;
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
    _loader ??= supabaseLoader();
    size = Vector2.all(_kPlayerHeight);

    // Load idle first (the initial visible anim) so the character appears
    // without waiting on the other sheets.
    await _loadAnim(CharacterAnimation.idle);

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

    // Stream the remaining animations in the background — not blocking display.
    if (loadAllAnimations) unawaited(_loadRemainingAnims());
  }

  /// Fetch every equipped layer for one animation concurrently, then slice.
  Future<void> _loadAnim(CharacterAnimation anim) async {
    if (_sets.containsKey(anim)) return;
    final entries = _selection.equipped.toList();
    final imgs = await Future.wait(
      entries.map(
        (e) => _loader!(anim, e.value!).then<ui.Image?>(
          (img) => img,
          onError: (Object err) {
            // Missing sheet for this layer/anim: skip it, keep the rest.
            debugPrint('character: missing ${e.value} for $anim ($err)');
            return null;
          },
        ),
      ),
    );
    final byLayer = <CharacterLayer, LayerSpriteSet>{};
    for (var i = 0; i < entries.length; i++) {
      final img = imgs[i];
      if (img != null) byLayer[entries[i].key] = LayerSpriteSet.fromImage(img);
    }
    _sets[anim] = byLayer;
    // If the active anim just finished loading, paint it now.
    if (anim == _anim) _applyFrame();
  }

  Future<void> _loadRemainingAnims() async {
    for (final anim in CharacterAnimation.values) {
      if (anim == CharacterAnimation.idle) continue;
      await _loadAnim(anim);
    }
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
    final step = _kMoveSpeed * dt;
    // Clamp to the remaining distance so a large dt can't overshoot and
    // oscillate around the target forever.
    if (step >= distance) {
      position.setFrom(target);
      _currentWaypointIndex++;
      if (_currentWaypointIndex >= _waypoints.length) _arrived = true;
    } else {
      position.add(dir * step);
    }

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

  /// The sprite set to actually render: the current anim if it loaded with
  /// frames, otherwise fall back to idle so the character never blanks while
  /// an anim is still streaming in or its sheets are missing remotely.
  Map<CharacterLayer, LayerSpriteSet>? _renderSet() {
    final byLayer = _sets[_anim];
    if (byLayer != null && byLayer.isNotEmpty) return byLayer;
    return _sets[CharacterAnimation.idle];
  }

  int _frameCountForCurrent() {
    final byLayer = _renderSet();
    if (byLayer == null || byLayer.isEmpty) return 0;
    // All layers of one anim share the same column count; read any.
    return byLayer.values.first.framesFor(_facing.facing).length;
  }

  void _applyFrame() {
    final byLayer = _renderSet();
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
