import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import 'library_game.dart';

/// Movement speed in pixels per second.
const double _kMoveSpeed = 150.0;

/// Distance (in pixels) at which the player is considered "arrived".
const double _kArrivalThreshold = 4.0;

/// Desired player height on screen.
const double _kPlayerHeight = 72.0;

/// Animation states for the player character.
enum PlayerState {
  idleLeft,
  idleFront,
  idleRight,
  runTransition,
  running,
  stopping,
}

/// The player character component.
///
/// Uses two spritesheets:
/// - `idle.png` -- 1 row x 3 columns
/// - `running.png` -- 5 rows x 5 columns (25 frames total)
class PlayerComponent extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<LibraryGame> {
  PlayerComponent({required Vector2 startPosition})
    : _startPosition = startPosition,
      super(current: PlayerState.idleFront, anchor: Anchor.bottomCenter);

  final Vector2 _startPosition;

  /// Tracks the last horizontal movement direction for idle frame selection.
  /// -1 = left, 0 = none (front), 1 = right.
  int _lastDirection = 0;

  /// Current horizontal movement direction while traveling.
  int get horizontalDirection => _lastDirection;

  /// Waypoint queue for 2D route-following movement.
  List<Vector2> _waypoints = [];
  int _currentWaypointIndex = 0;

  bool _arrived = true;

  /// Whether the player has arrived at the final waypoint.
  bool get hasArrived => _arrived;

  bool get isMoving => _waypoints.isNotEmpty && !_arrived;

  /// Set a list of waypoints for the player to follow sequentially.
  /// Each waypoint is a world-space position the player walks to in order.
  void setWaypoints(List<Vector2> waypoints) {
    _waypoints = waypoints;
    _currentWaypointIndex = 0;
    _arrived = false;
  }

  /// For backwards compat: setting targetX clears waypoints and walks
  /// straight to (targetX, current Y).
  set targetX(double? value) {
    if (value == null) {
      _waypoints = [];
      _currentWaypointIndex = 0;
      _arrived = true;
      return;
    }
    setWaypoints([Vector2(value, position.y)]);
  }

  double _idleAspectRatio = 1;
  double _runningAspectRatio = 1;

  void _applySizeForState(PlayerState? state) {
    final aspectRatio = switch (state) {
      PlayerState.idleLeft ||
      PlayerState.idleFront ||
      PlayerState.idleRight => _idleAspectRatio,
      PlayerState.runTransition ||
      PlayerState.running ||
      PlayerState.stopping => _runningAspectRatio,
      null => _idleAspectRatio,
    };

    size = Vector2(_kPlayerHeight * aspectRatio, _kPlayerHeight);
  }

  // ── Loading ──────────────────────────────────────────────────────────

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    // ---- Idle spritesheet (1 row x 3 columns) ----
    // Frames: [0] 3/4 left, [1] front, [2] 3/4 right — each a still frame.
    final idleImage = await game.images.load('idle.png');
    final idleFrameW = idleImage.width / 3;
    final idleFrameH = idleImage.height.toDouble();
    final idleSheet = SpriteSheet(
      image: idleImage,
      srcSize: Vector2(idleFrameW, idleFrameH),
    );
    SpriteAnimation singleFrame(int col) => SpriteAnimation.spriteList([
      idleSheet.getSprite(0, col),
    ], stepTime: double.infinity);
    final idleLeftAnim = singleFrame(0);
    final idleFrontAnim = singleFrame(1);
    final idleRightAnim = singleFrame(2);

    // ---- Running spritesheet (5 rows x 5 columns = 25 frames) ----
    final runImage = await game.images.load('running.png');
    final runFrameW = runImage.width / 5;
    final runFrameH = runImage.height / 5;
    final runSheet = SpriteSheet(
      image: runImage,
      srcSize: Vector2(runFrameW, runFrameH),
    );

    // Helper to get a sprite at a linear frame index (0..24).
    Sprite spriteAt(int index) {
      final row = index ~/ 5;
      final col = index % 5;
      return runSheet.getSprite(row, col);
    }

    // runTransition: frames 10 -> 0 (one-shot, played when starting to run)
    final runTransitionAnim = SpriteAnimation(
      List.generate(11, (i) => SpriteAnimationFrame(spriteAt(10 - i), 0.04)),
    )..loop = false;

    // running: frames 0-9 (looped)
    final runningAnim = SpriteAnimation(
      List.generate(10, (i) => SpriteAnimationFrame(spriteAt(i), 0.06)),
    );

    // stopping: frames 0 -> 10 (one-shot, reverse of transition)
    final stoppingAnim = SpriteAnimation(
      List.generate(11, (i) => SpriteAnimationFrame(spriteAt(i), 0.04)),
    )..loop = false;

    // ---- Configure the animation group ----
    animations = {
      PlayerState.idleLeft: idleLeftAnim,
      PlayerState.idleFront: idleFrontAnim,
      PlayerState.idleRight: idleRightAnim,
      PlayerState.runTransition: runTransitionAnim,
      PlayerState.running: runningAnim,
      PlayerState.stopping: stoppingAnim,
    };

    // ---- Sizing ----
    _idleAspectRatio = idleFrameW / idleFrameH;
    _runningAspectRatio = runFrameW / runFrameH;
    _applySizeForState(PlayerState.idleFront);

    // ---- Start position ----
    position = _startPosition.clone();
    current = PlayerState.idleFront;
  }

  // ── Update ───────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    _handleMovement(dt);
    _handleAnimationTransitions();
  }

  void _handleMovement(double dt) {
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
      if (_currentWaypointIndex >= _waypoints.length) {
        _arrived = true;
      }
      return;
    }

    final direction = delta.normalized();
    position.add(direction * _kMoveSpeed * dt);

    // Flip based on horizontal direction.
    final hDir = delta.x.sign.toInt();
    if (hDir != 0) _lastDirection = hDir;

    // Flip sprite: sprites face left by default.
    // Moving right -> flip (scale.x = -1), moving left -> normal (scale.x = 1).
    if (hDir > 0) {
      if (scale.x != -1) scale.x = -1;
    } else if (hDir < 0) {
      if (scale.x != 1) scale.x = 1;
    }
  }

  /// Access the ticker for a given animation state.
  SpriteAnimationTicker? _tickerFor(PlayerState state) {
    return animationTickers?[state];
  }

  /// Returns the correct idle state based on last movement direction.
  PlayerState get _idleForDirection => switch (_lastDirection) {
    -1 => PlayerState.idleLeft,
    1 => PlayerState.idleRight,
    _ => PlayerState.idleFront,
  };

  void _transitionToIdle() {
    // Reset flip — idle frames already have directional variants.
    scale.x = 1;
    current = _idleForDirection;
    _applySizeForState(current);
  }

  void _handleAnimationTransitions() {
    final isMoving = this.isMoving;

    switch (current) {
      case PlayerState.idleLeft:
      case PlayerState.idleFront:
      case PlayerState.idleRight:
        if (isMoving) {
          current = PlayerState.runTransition;
          _applySizeForState(current);
          _tickerFor(PlayerState.runTransition)?.reset();
        }
        break;

      case PlayerState.runTransition:
        if (!isMoving) {
          // Interrupted before finishing transition -- go straight to stopping.
          current = PlayerState.stopping;
          _applySizeForState(current);
          _tickerFor(PlayerState.stopping)?.reset();
        } else if (_tickerFor(PlayerState.runTransition)?.done() ?? false) {
          current = PlayerState.running;
          _applySizeForState(current);
        }
        break;

      case PlayerState.running:
        if (!isMoving) {
          current = PlayerState.stopping;
          _applySizeForState(current);
          _tickerFor(PlayerState.stopping)?.reset();
        }
        break;

      case PlayerState.stopping:
        if (isMoving) {
          // Player tapped again while stopping -- restart run.
          current = PlayerState.runTransition;
          _applySizeForState(current);
          _tickerFor(PlayerState.runTransition)?.reset();
        } else if (_tickerFor(PlayerState.stopping)?.done() ?? false) {
          _transitionToIdle();
        }
        break;

      case null:
        break;
    }
  }
}
