import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

// Smoke test for the SVG->Lottie celebration asset + the newly-wired `lottie`
// package. Confirms the Flutter Lottie renderer (not just lottie-web) parses
// assets/lottie/book_celebration.json without error.
void main() {
  testWidgets('book_celebration.json loads and parses via lottie pkg',
      (tester) async {
    LottieComposition? loaded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Lottie.asset(
              'assets/lottie/book_celebration.json',
              animate: false, // avoid an infinite ticker so the tree settles
              onLoaded: (composition) => loaded = composition,
            ),
          ),
        ),
      ),
    );
    // let the async asset load + JSON parse resolve
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(loaded, isNotNull, reason: 'Lottie composition failed to load');
    // 90 frames @ 60fps == 1.5s
    expect(loaded!.duration.inMilliseconds, greaterThan(0));
    expect(find.byType(Lottie), findsOneWidget);
  });
}
