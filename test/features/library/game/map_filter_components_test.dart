import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/library/game/map_book_node_component.dart';
import 'package:storia_kids/src/features/library/game/map_route_component.dart';

Book _book(String id) =>
    Book(id: id, title: 'Book $id', pageCount: 10, pages: const []);

TapUpEvent _tapUpEvent() => TapUpEvent(
  1,
  FlameGame(),
  TapUpDetails(
    kind: PointerDeviceKind.touch,
    globalPosition: ui.Offset.zero,
    localPosition: ui.Offset.zero,
  ),
);

void main() {
  group('MapBookNodeComponent filtered visibility', () {
    test('hidden nodes fade toward zero and ignore taps', () {
      var tapCount = 0;
      final node = MapBookNodeComponent(
        book: _book('b1'),
        onBookTapped: (_, _) => tapCount++,
      );

      expect(node.debugVisibility, equals(1));
      expect(node.debugIsInteractable, isTrue);

      node.onTapUp(_tapUpEvent());
      expect(tapCount, equals(1));

      node.isVisible = false;
      node.update(0.20);

      expect(node.debugVisibility, closeTo(0.2, 0.0001));
      expect(node.debugIsInteractable, isFalse);

      node.onTapUp(_tapUpEvent());
      expect(tapCount, equals(1));
    });

    test(
      'nodes reappear and become tappable when filter includes them again',
      () {
        var tapCount = 0;
        final node = MapBookNodeComponent(
          book: _book('b1'),
          isVisible: false,
          onBookTapped: (_, _) => tapCount++,
        );

        expect(node.debugVisibility, equals(0));
        expect(node.debugIsInteractable, isFalse);

        node.isVisible = true;
        node.update(0.25);

        expect(node.debugVisibility, equals(1));
        expect(node.debugIsInteractable, isTrue);

        node.onTapUp(_tapUpEvent());
        expect(tapCount, equals(1));
      },
    );
  });

  group('MapRouteComponent filtered route', () {
    test('rebuilds the dirt road through only visible node positions', () {
      final positions = [
        Vector2(100, 10),
        Vector2(200, 20),
        Vector2(300, 30),
        Vector2(400, 40),
      ];
      final route = MapRouteComponent(nodePositions: positions);

      route.setVisibleNodePositions([positions[0], positions[2], positions[3]]);

      expect(
        route.debugVisibleNodePositions.map((position) => position.x),
        equals([100, 300, 400]),
      );
    });

    test('highlight indexes are relative to the visible route subset', () {
      final positions = [Vector2(100, 10), Vector2(300, 30), Vector2(400, 40)];
      final route = MapRouteComponent(nodePositions: positions);

      route.setVisibleNodePositions(positions);
      route.setHighlightToNodeIndex(1);

      expect(route.debugHighlightTargetProgress, equals(0.5));

      route.setVisibleNodePositions([positions.first]);
      route.setHighlightToNodeIndex(0);

      expect(route.debugHighlightTargetProgress, equals(-1));
    });
  });
}
