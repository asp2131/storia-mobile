import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Loratone/src/core/widgets/gate_lockout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GateLockout', () {
    test('starts unlocked with zero failures', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      expect(lockout.isLocked, isFalse);
      expect(lockout.remainingSeconds, 0);
    });

    test('first failure → 30s short lockout', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      lockout.recordFailure();
      expect(lockout.isLocked, isTrue);
      expect(lockout.remainingSeconds, 30);
    });

    test('second failure → still 30s short lockout', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      lockout.recordFailure();
      lockout.recordFailure();
      expect(lockout.isLocked, isTrue);
      expect(lockout.remainingSeconds, 30);
    });

    test('third failure → escalates to 120s long lockout', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      lockout.recordFailure();
      lockout.recordFailure();
      lockout.recordFailure();
      expect(lockout.isLocked, isTrue);
      expect(lockout.remainingSeconds, 120);
    });

    test('recordSuccess resets failures and clears lockout', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      lockout.recordFailure();
      lockout.recordFailure();
      expect(lockout.isLocked, isTrue);

      lockout.recordSuccess();
      expect(lockout.isLocked, isFalse);
      expect(lockout.remainingSeconds, 0);

      lockout.recordFailure();
      expect(lockout.remainingSeconds, 30);
    });

    test('isLocked self-clears after expiry', () {
      var now = DateTime(2024, 1, 1, 12);
      final lockout = GateLockout(now: () => now);

      lockout.recordFailure();
      expect(lockout.isLocked, isTrue);

      now = now.add(const Duration(seconds: 31));
      expect(lockout.isLocked, isFalse);
      expect(lockout.remainingSeconds, 0);
    });

    test('remainingSeconds decreases as time passes', () {
      var now = DateTime(2024, 1, 1, 12);
      final lockout = GateLockout(now: () => now);

      lockout.recordFailure();
      expect(lockout.remainingSeconds, 30);

      now = now.add(const Duration(seconds: 10));
      expect(lockout.remainingSeconds, 20);

      now = now.add(const Duration(seconds: 29));
      expect(lockout.remainingSeconds, 0);
    });

    test('reset clears in-memory state', () {
      final lockout = GateLockout(now: () => DateTime(2024, 1, 1, 12));
      lockout.recordFailure();
      lockout.recordFailure();
      lockout.recordFailure();

      lockout.reset();
      expect(lockout.isLocked, isFalse);
      expect(lockout.remainingSeconds, 0);

      lockout.recordFailure();
      expect(lockout.remainingSeconds, 30);
    });

    test('persisted lockout survives instance recreation', () async {
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2024, 1, 1, 12);

      final lockout1 = GateLockout(now: () => now, prefs: prefs);
      lockout1.recordFailure();
      lockout1.recordFailure();
      lockout1.recordFailure();
      expect(lockout1.remainingSeconds, 120);

      final lockout2 = GateLockout(now: () => now, prefs: prefs);
      expect(lockout2.isLocked, isTrue);
      expect(lockout2.remainingSeconds, 120);
    });

    test('persisted failures survive instance recreation', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2024, 1, 1, 12);

      final lockout1 = GateLockout(now: () => now, prefs: prefs);
      lockout1.recordFailure();
      lockout1.recordFailure();

      final lockout2 = GateLockout(now: () => now, prefs: prefs);
      expect(lockout2.isLocked, isTrue);
      lockout2.recordFailure();
      expect(lockout2.remainingSeconds, 120);
    });

    test('reset clears persisted state', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2024, 1, 1, 12);

      final lockout1 = GateLockout(now: () => now, prefs: prefs);
      lockout1.recordFailure();
      lockout1.recordFailure();
      lockout1.recordFailure();

      lockout1.reset();

      final lockout2 = GateLockout(now: () => now, prefs: prefs);
      expect(lockout2.isLocked, isFalse);
      lockout2.recordFailure();
      expect(lockout2.remainingSeconds, 30);
    });

    test('expired persisted lockout self-clears on load', () async {
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime(2024, 1, 1, 12);

      final lockout1 = GateLockout(now: () => now, prefs: prefs);
      lockout1.recordFailure();

      now = now.add(const Duration(seconds: 31));

      final lockout2 = GateLockout(now: () => now, prefs: prefs);
      expect(lockout2.isLocked, isFalse);
    });
  });
}
