// nextLocation: canonical waypoint per journey stage, plus the policy
// self-consistency invariant — the policy never sends a screen somewhere
// the redirect would immediately bounce from.

import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/routing/journey/journey_policy.dart';

JourneySnapshot snap({
  bool ready = true,
  bool session = false,
  bool bypass = false,
  bool birthYear = false,
  bool onboarded = false,
  ProfileSelection profile = ProfileSelection.none,
}) {
  return JourneySnapshot(
    reviewFlowReady: ready,
    hasSupabaseSession: session,
    hasReviewBypass: bypass,
    hasParentBirthYear: birthYear,
    hasCompletedReviewOnboarding: onboarded,
    profileSelection: profile,
  );
}

/// Exhaustive snapshot space: 2^5 boolean combinations x 3 profile states.
Iterable<JourneySnapshot> allSnapshots() sync* {
  const bools = [false, true];
  for (final ready in bools) {
    for (final session in bools) {
      for (final bypass in bools) {
        for (final birthYear in bools) {
          for (final onboarded in bools) {
            for (final profile in ProfileSelection.values) {
              yield snap(
                ready: ready,
                session: session,
                bypass: bypass,
                birthYear: birthYear,
                onboarded: onboarded,
                profile: profile,
              );
            }
          }
        }
      }
    }
  }
}

void main() {
  group('nextLocation canonical waypoints', () {
    test('indeterminate (boot) holds at the AuthGate root', () {
      expect(JourneyPolicy.nextLocation(snap(ready: false)), '/');
    });

    test('unauthenticated goes to intro', () {
      expect(JourneyPolicy.nextLocation(snap()), '/intro');
    });

    test('bypass without birth year goes to parent birth year', () {
      expect(
        JourneyPolicy.nextLocation(snap(bypass: true)),
        '/parent-birth-year',
      );
    });

    test('bypass with birth year goes to onboarding', () {
      expect(
        JourneyPolicy.nextLocation(snap(bypass: true, birthYear: true)),
        '/onboarding',
      );
    });

    test('session with loading profile holds at the AuthGate root', () {
      expect(
        JourneyPolicy.nextLocation(
          snap(session: true, profile: ProfileSelection.loading),
        ),
        '/',
      );
    });

    test('session without active profile goes to the picker', () {
      expect(
        JourneyPolicy.nextLocation(snap(session: true)),
        '/profiles/select',
      );
    });

    test('completed journeys land on the library', () {
      expect(
        JourneyPolicy.nextLocation(
          snap(session: true, profile: ProfileSelection.selected),
        ),
        '/library',
      );
      expect(
        JourneyPolicy.nextLocation(
          snap(bypass: true, birthYear: true, onboarded: true),
        ),
        '/library',
      );
    });
  });

  group('self-consistency invariant', () {
    test('redirect(s, nextLocation(s)) == null for EVERY snapshot', () {
      var count = 0;
      for (final s in allSnapshots()) {
        final next = JourneyPolicy.nextLocation(s);
        expect(
          JourneyPolicy.redirect(s, next),
          isNull,
          reason: 'policy contradicts itself for $s -> $next',
        );
        count++;
      }
      expect(count, 96, reason: 'expected exhaustive 2^5 * 3 coverage');
    });
  });
}
