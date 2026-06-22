import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Loratone/src/core/widgets/parental_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  GateController newController({int solveSeconds = 30}) {
    final now = DateTime(2024, 1, 1, 12);
    return GateController(
      random: Random(42),
      lockout: GateLockout(now: () => now),
      solveSeconds: solveSeconds,
      autoTick: false,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: child,
          ),
        ),
      ),
    );
  }

  group('GateChallengeCard', () {
    testWidgets('renders challenge state with question and input', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Parents only',
            showCancel: false,
          ),
        ),
      );

      expect(find.text('Parents only'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('shows Cancel button when showCancel is true', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Grown-ups only',
            showCancel: true,
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Grown-ups only'), findsOneWidget);
    });

    testWidgets('correct answer transitions to GatePassed', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);

      final state = controller.value as GateChallenging;

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Parents only',
            showCancel: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '${state.answer}');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(controller.value, isA<GatePassed>());
    });

    testWidgets('wrong answer transitions to GateLocked', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Parents only',
            showCancel: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '99999');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(controller.value, isA<GateLocked>());
      expect(find.text('Please wait'), findsOneWidget);
      expect(find.text('Please try again in'), findsOneWidget);
    });

    testWidgets('non-numeric input shows error', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Parents only',
            showCancel: false,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(controller.value, isA<GateChallenging>());
      expect(find.text('Please enter a number.'), findsOneWidget);
    });

    testWidgets('cancel button calls onCancel', (tester) async {
      final controller = newController();
      addTearDown(controller.dispose);
      var cancelled = false;

      await tester.pumpWidget(
        wrap(
          GateChallengeCard(
            controller: controller,
            header: const SizedBox(height: 48),
            title: 'Grown-ups only',
            showCancel: true,
            onCancel: () => cancelled = true,
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(cancelled, isTrue);
    });
  });

  group('ParentalGate.verify', () {
    testWidgets('shows modal and returns false on cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await ParentalGate.verify(context);
                  },
                  child: const Text('Open gate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open gate'));
      await tester.pumpAndSettle();

      expect(find.text('Grown-ups only'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('shows modal and returns true on correct answer', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await ParentalGate.verify(context);
                  },
                  child: const Text('Open gate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open gate'));
      await tester.pumpAndSettle();

      expect(find.text('Grown-ups only'), findsOneWidget);

      final state =
          (find.byType(GateChallengeCard).evaluate().single.widget as GateChallengeCard)
              .controller
              .value as GateChallenging;

      await tester.enterText(find.byType(TextField), '${state.answer}');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
