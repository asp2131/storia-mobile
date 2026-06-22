import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Loratone/src/core/widgets/gate_controller.dart';
import 'package:Loratone/src/core/widgets/gate_lockout.dart';
import 'package:Loratone/src/core/widgets/gate_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  GateController newController({
    Random? random,
    GateLockout? lockout,
    int solveSeconds = 30,
  }) {
    final now = DateTime(2024, 1, 1, 12);
    return GateController(
      random: random ?? Random(42),
      lockout: lockout ?? GateLockout(now: () => now),
      solveSeconds: solveSeconds,
      autoTick: false,
    );
  }

  int answerOf(GateController c) {
    final s = c.value as GateChallenging;
    return s.answer;
  }

  group('GateController init', () {
    test('starts in GateChallenging when not locked', () {
      final c = newController();
      expect(c.value, isA<GateChallenging>());
      final s = c.value as GateChallenging;
      expect(s.question, isNotEmpty);
      expect(s.answer, greaterThan(0));
      expect(s.solveSecondsLeft, 30);
      expect(s.error, isNull);
    });

    test('starts in GateLocked when lockout is active', () {
      var now = DateTime(2024, 1, 1, 12);
      final lockout = GateLockout(now: () => now);
      lockout.recordFailure();

      final c = GateController(
        random: Random(42),
        lockout: lockout,
        autoTick: false,
      );
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 30);
    });
  });

  group('GateController tick', () {
    test('countdown decrements then triggers lockout on timeout', () {
      final c = newController(solveSeconds: 3);
      expect((c.value as GateChallenging).solveSecondsLeft, 3);

      c.tick();
      expect((c.value as GateChallenging).solveSecondsLeft, 2);
      c.tick();
      expect((c.value as GateChallenging).solveSecondsLeft, 1);
      c.tick();
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 30);
    });

    test('lockout countdown decrements then regenerates challenge', () {
      final c = newController(solveSeconds: 1);
      c.tick();
      expect(c.value, isA<GateLocked>());

      final lockSecs = (c.value as GateLocked).lockoutSecondsLeft;
      for (var i = 0; i < lockSecs; i++) {
        c.tick();
      }
      expect(c.value, isA<GateChallenging>());
      expect((c.value as GateChallenging).solveSecondsLeft, 1);
    });

    test('tick is no-op on GatePassed', () {
      final c = newController();
      c.submitAnswer('${answerOf(c)}');
      expect(c.value, isA<GatePassed>());
      c.tick();
      expect(c.value, isA<GatePassed>());
    });

    test('tick is no-op on GateCancelled', () {
      final c = newController();
      c.cancel();
      expect(c.value, isA<GateCancelled>());
      c.tick();
      expect(c.value, isA<GateCancelled>());
    });
  });

  group('GateController submitAnswer', () {
    test('correct answer → GatePassed + lockout reset', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      final c = newController(lockout: lockout);
      final answer = answerOf(c);

      c.submitAnswer('$answer');

      expect(c.value, isA<GatePassed>());
      expect(lockout.isLocked, isFalse);
    });

    test('wrong answer → GateLocked', () {
      final c = newController();
      c.submitAnswer('99999');
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 30);
    });

    test('non-numeric input → error in GateChallenging', () {
      final c = newController();
      c.submitAnswer('abc');
      expect(c.value, isA<GateChallenging>());
      expect((c.value as GateChallenging).error, isNotNull);
    });

    test('empty input → error in GateChallenging', () {
      final c = newController();
      c.submitAnswer('');
      expect(c.value, isA<GateChallenging>());
      expect((c.value as GateChallenging).error, isNotNull);
    });

    test('clearError wipes error', () {
      final c = newController();
      c.submitAnswer('abc');
      expect((c.value as GateChallenging).error, isNotNull);
      c.clearError();
      expect((c.value as GateChallenging).error, isNull);
    });

    test('submitAnswer is no-op when locked', () {
      final c = newController();
      final answer = answerOf(c);
      c.submitAnswer('99999');
      expect(c.value, isA<GateLocked>());
      c.submitAnswer('$answer');
      expect(c.value, isA<GateLocked>());
    });

    test('submitAnswer is no-op when passed', () {
      final c = newController();
      c.submitAnswer('${answerOf(c)}');
      expect(c.value, isA<GatePassed>());
      c.submitAnswer('99999');
      expect(c.value, isA<GatePassed>());
    });
  });

  group('GateController cancel', () {
    test('cancel → GateCancelled', () {
      final c = newController();
      c.cancel();
      expect(c.value, isA<GateCancelled>());
    });

    test('cancel from locked state → GateCancelled', () {
      final c = newController();
      c.submitAnswer('99999');
      expect(c.value, isA<GateLocked>());
      c.cancel();
      expect(c.value, isA<GateCancelled>());
    });
  });

  group('GateController progressive lockout', () {
    test('three failures escalate to long lockout', () {
      var now = DateTime(2024, 1, 1, 12);
      final lockout = GateLockout(now: () => now);
      final c = newController(lockout: lockout, solveSeconds: 1);

      c.tick();
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 30);

      now = now.add(const Duration(seconds: 31));
      final lockSecs = (c.value as GateLocked).lockoutSecondsLeft;
      for (var i = 0; i < lockSecs; i++) {
        c.tick();
      }

      c.tick();
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 30);

      now = now.add(const Duration(seconds: 31));
      final lockSecs2 = (c.value as GateLocked).lockoutSecondsLeft;
      for (var i = 0; i < lockSecs2; i++) {
        c.tick();
      }

      c.tick();
      expect(c.value, isA<GateLocked>());
      expect((c.value as GateLocked).lockoutSecondsLeft, 120);
    });
  });

  group('GateController notifies listeners', () {
    test('value changes notify listeners', () {
      final c = newController();
      var notified = 0;
      c.addListener(() => notified++);

      c.tick();
      expect(notified, greaterThan(0));
    });
  });
}
