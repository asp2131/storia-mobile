import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gooey/gooey.dart';

import 'package:storia_kids/src/features/reader/reader_screen.dart';

Future<void> _noop() async {}

Widget _harness() {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          // Sibling that fills the screen — represents the PageView area
          // that the original bug routed taps to when the pill missed hits.
          const Positioned.fill(child: ColoredBox(color: Color(0xFF111111))),
          AudioControlsPill(
            hasNarration: true,
            hasSoundscape: true,
            isNarrationPlaying: false,
            isSoundscapePlaying: false,
            isPracticeActive: false,
            isListening: false,
            isVisible: true,
            showGrip: true,
            onToggleNarration: _noop,
            onToggleSoundscape: _noop,
            onTogglePractice: _noop,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('idle pill does not mount a gooey wobble overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(GooeyZone), findsNothing);
  });

  testWidgets(
    'dragging the pill mounts a gooey wobble overlay while in motion',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final pillFinder = find
          .byWidgetPredicate(
            (w) => w is SizedBox && w.width == 120 && w.height == 120,
          )
          .first;
      final pillCenter = tester.getCenter(pillFinder);

      final gesture = await tester.startGesture(pillCenter);
      // Allow the pointer down to register, then move clearly past the
      // pan-slop threshold so onPanStart fires before we assert.
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));

      // During an active drag the gooey wobble overlay should be mounted.
      expect(find.byType(GooeyZone), findsAtLeastNWidgets(1));
      expect(find.byType(GooeyBlob), findsAtLeastNWidgets(2));

      // Regression: the trail blob must protrude beyond the pill radius.
      // Otherwise the gooey overlay is mounted but completely hidden under
      // the opaque 120px pill body.
      final trailBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('audio-controls-gooey-trail')),
      );
      final trailTransform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('audio-controls-gooey-trail')),
              matching: find.byType(Transform),
            )
            .first,
      );
      final matrix = trailTransform.transform.storage;
      final trailOffset = Offset(matrix[12], matrix[13]);
      final trailProtrusion = trailOffset.distance + (trailBox.width! / 2);
      expect(trailProtrusion, greaterThan(60.0));

      await gesture.up();
      await tester.pumpAndSettle();

      // After the release outro completes the overlay unmounts.
      expect(find.byType(GooeyZone), findsNothing);
    },
  );

  testWidgets('pie can be dragged consecutively from its current position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Locate the actual pill RenderBox: the 120x120 SizedBox that visually
    // represents the circle. AudioControlsPill itself is Positioned.fill, so
    // its center is the screen center, not the pill — we need the inner box.
    final pillFinder = find
        .byWidgetPredicate(
          (w) => w is SizedBox && w.width == 120 && w.height == 120,
        )
        .first;

    final initialCenter = tester.getCenter(pillFinder);

    // Drag 1: move pill up-left by (-150, -200).
    await tester.timedDragFrom(
      initialCenter,
      const Offset(-150, -200),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    final centerAfterDrag1 = tester.getCenter(pillFinder);
    expect(
      centerAfterDrag1,
      isNot(equals(initialCenter)),
      reason: 'Drag 1 should move the pill',
    );

    // Drag 2: from new pill center, move right by (250, 100).
    await tester.timedDragFrom(
      centerAfterDrag1,
      const Offset(250, 100),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();

    final centerAfterDrag2 = tester.getCenter(pillFinder);
    expect(
      centerAfterDrag2,
      isNot(equals(centerAfterDrag1)),
      reason: 'Drag 2 should move the pill from its new position',
    );
  });
}
