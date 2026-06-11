// backTarget: static back edges for journey steps (pure lookup table).

import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/routing/journey/journey_policy.dart';

void main() {
  group('JourneyPolicy.backTarget', () {
    test('sign-in backs out to intro', () {
      expect(JourneyPolicy.backTarget('/sign-in'), '/intro');
    });

    test('sign-up backs out to intro', () {
      expect(JourneyPolicy.backTarget('/sign-up'), '/intro');
    });

    test('add-profile backs out to the picker', () {
      expect(JourneyPolicy.backTarget('/profiles/new'), '/profiles/select');
    });

    test('unknown locations fall back to the AuthGate root', () {
      expect(JourneyPolicy.backTarget('/library'), '/');
      expect(JourneyPolicy.backTarget('/settings'), '/');
      expect(JourneyPolicy.backTarget('/no-such-route'), '/');
    });
  });

  group('JourneyPolicy.restartTarget', () {
    test('start-over lands on sign-in', () {
      expect(JourneyPolicy.restartTarget, '/sign-in');
    });
  });
}
