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
