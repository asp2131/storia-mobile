import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
