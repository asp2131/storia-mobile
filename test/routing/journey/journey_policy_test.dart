// Golden-master truth table for JourneyPolicy.redirect.
//
// Every expectation in this file was derived row-by-row from the legacy
// 100-line redirect closure in lib/src/routing/app_router.dart before the
// swap (issue #33). Behavior changes must be opt-in: if you edit the policy
// and a row here fails, you are changing app-entry behavior — update the row
// only with intent.
//
// KNOWN, INTENTIONAL DIVERGENCE from the legacy closure: at `/` the legacy
// code checked profile selection before review onboarding, while every other
// location checked onboarding first. The orderings only diverge for a user
// holding BOTH a Supabase session and an active review bypass (product flows
// never produce one). This policy normalizes on the general-branch ordering:
// review steps outrank profile selection everywhere. See the dual-track
// group below.

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

/// Every interesting location, including terminals and a deep link.
const allLocations = [
  '/',
  '/intro',
  '/sign-in',
  '/sign-up',
  '/parent-birth-year',
  '/onboarding',
  '/profiles/select',
  '/profiles/new',
  '/library',
  '/settings',
  '/aac-music-demo',
  '/reader/book-1',
];

void expectTable(JourneySnapshot s, Map<String, String?> expected) {
  expect(
    expected.keys.toSet(),
    allLocations.toSet(),
    reason: 'table must cover every sampled location',
  );
  for (final location in allLocations) {
    expect(
      JourneyPolicy.redirect(s, location),
      expected[location],
      reason: 'redirect($s, $location)',
    );
  }
}

void main() {
  group('boot hold (review flow not ready)', () {
    test('allows every location regardless of other state', () {
      for (final s in [
        snap(ready: false),
        snap(ready: false, session: true, profile: ProfileSelection.loading),
        snap(ready: false, bypass: true),
        snap(
          ready: false,
          session: true,
          bypass: true,
          birthYear: true,
          onboarded: true,
          profile: ProfileSelection.selected,
        ),
      ]) {
        for (final location in allLocations) {
          expect(
            JourneyPolicy.redirect(s, location),
            isNull,
            reason: 'boot hold must allow $location for $s',
          );
        }
      }
    });
  });

  group('unauthenticated (no session, no bypass)', () {
    test('public locations pass; everything else, including /, goes to intro',
        () {
      expectTable(snap(), {
        '/': '/intro',
        '/intro': null,
        '/sign-in': null,
        '/sign-up': null,
        '/parent-birth-year': '/intro',
        '/onboarding': '/intro',
        '/profiles/select': '/intro',
        '/profiles/new': '/intro',
        '/library': '/intro',
        '/settings': '/intro',
        '/aac-music-demo': '/intro',
        '/reader/book-1': '/intro',
      });
    });

    test('profile selection loading does not outrank unauthenticated', () {
      expectTable(snap(profile: ProfileSelection.loading), {
        '/': '/intro',
        '/intro': null,
        '/sign-in': null,
        '/sign-up': null,
        '/parent-birth-year': '/intro',
        '/onboarding': '/intro',
        '/profiles/select': '/intro',
        '/profiles/new': '/intro',
        '/library': '/intro',
        '/settings': '/intro',
        '/aac-music-demo': '/intro',
        '/reader/book-1': '/intro',
      });
    });
  });

  group('app-review bypass track', () {
    test('birth year pending: everything funnels to /parent-birth-year', () {
      expectTable(snap(bypass: true), {
        '/': '/parent-birth-year',
        '/intro': '/parent-birth-year',
        '/sign-in': '/parent-birth-year',
        '/sign-up': '/parent-birth-year',
        '/parent-birth-year': null,
        '/onboarding': '/parent-birth-year',
        '/profiles/select': '/parent-birth-year',
        '/profiles/new': '/parent-birth-year',
        '/library': '/parent-birth-year',
        '/settings': '/parent-birth-year',
        '/aac-music-demo': '/parent-birth-year',
        '/reader/book-1': '/parent-birth-year',
      });
    });

    test('onboarding pending: everything funnels to /onboarding', () {
      expectTable(snap(bypass: true, birthYear: true), {
        '/': '/onboarding',
        '/intro': '/onboarding',
        '/sign-in': '/onboarding',
        '/sign-up': '/onboarding',
        '/parent-birth-year': '/onboarding',
        '/onboarding': null,
        '/profiles/select': '/onboarding',
        '/profiles/new': '/onboarding',
        '/library': '/onboarding',
        '/settings': '/onboarding',
        '/aac-music-demo': '/onboarding',
        '/reader/book-1': '/onboarding',
      });
    });

    test(
        'bypass complete: pre-journey locations bounce to /library, '
        'terminals and profile routes pass (no backend profile required)',
        () {
      expectTable(snap(bypass: true, birthYear: true, onboarded: true), {
        '/': '/library',
        '/intro': '/library',
        '/sign-in': '/library',
        '/sign-up': '/library',
        '/parent-birth-year': '/library',
        '/onboarding': '/library',
        '/profiles/select': null,
        '/profiles/new': null,
        '/library': null,
        '/settings': null,
        '/aac-music-demo': null,
        '/reader/book-1': null,
      });
    });
  });

  group('supabase track', () {
    test('profile selection loading: stay put everywhere (all null)', () {
      expectTable(snap(session: true, profile: ProfileSelection.loading), {
        for (final location in allLocations) location: null,
      });
    });

    test('no active profile: everything except picker/add goes to picker',
        () {
      expectTable(snap(session: true), {
        '/': '/profiles/select',
        '/intro': '/profiles/select',
        '/sign-in': '/profiles/select',
        '/sign-up': '/profiles/select',
        '/parent-birth-year': '/profiles/select',
        '/onboarding': '/profiles/select',
        '/profiles/select': null,
        '/profiles/new': null,
        '/library': '/profiles/select',
        '/settings': '/profiles/select',
        '/aac-music-demo': '/profiles/select',
        '/reader/book-1': '/profiles/select',
      });
    });

    test(
        'profile selected: pre-journey bounces to /library; terminals and '
        'profile routes stay reachable (profile switching)', () {
      expectTable(snap(session: true, profile: ProfileSelection.selected), {
        '/': '/library',
        '/intro': '/library',
        '/sign-in': '/library',
        '/sign-up': '/library',
        '/parent-birth-year': '/library',
        '/onboarding': '/library',
        '/profiles/select': null,
        '/profiles/new': null,
        '/library': null,
        '/settings': null,
        '/aac-music-demo': null,
        '/reader/book-1': null,
      });
    });
  });

  group('dual track (session + bypass) — review steps outrank profiles', () {
    test('birth year pending wins over profile loading', () {
      expectTable(
        snap(session: true, bypass: true, profile: ProfileSelection.loading),
        {
          for (final location in allLocations)
            location:
                location == '/parent-birth-year' ? null : '/parent-birth-year',
        },
      );
    });

    test(
        'onboarding pending wins over missing profile '
        '(normalized divergence from legacy `/` branch)', () {
      expectTable(
        snap(session: true, bypass: true, birthYear: true),
        {
          for (final location in allLocations)
            location: location == '/onboarding' ? null : '/onboarding',
        },
      );
    });

    test('both tracks complete behaves like supabase-complete', () {
      expectTable(
        snap(
          session: true,
          bypass: true,
          birthYear: true,
          onboarded: true,
          profile: ProfileSelection.selected,
        ),
        {
          '/': '/library',
          '/intro': '/library',
          '/sign-in': '/library',
          '/sign-up': '/library',
          '/parent-birth-year': '/library',
          '/onboarding': '/library',
          '/profiles/select': null,
          '/profiles/new': null,
          '/library': null,
          '/settings': null,
          '/aac-music-demo': null,
          '/reader/book-1': null,
        },
      );
    });

    test('dual complete but profile pending still gates on the picker', () {
      expectTable(
        snap(session: true, bypass: true, birthYear: true, onboarded: true),
        {
          '/': '/profiles/select',
          '/intro': '/profiles/select',
          '/sign-in': '/profiles/select',
          '/sign-up': '/profiles/select',
          '/parent-birth-year': '/profiles/select',
          '/onboarding': '/profiles/select',
          '/profiles/select': null,
          '/profiles/new': null,
          '/library': '/profiles/select',
          '/settings': '/profiles/select',
          '/aac-music-demo': '/profiles/select',
          '/reader/book-1': '/profiles/select',
        },
      );
    });
  });

  group('JourneyRoutes', () {
    test('reader() builds parameterized deep links', () {
      expect(JourneyRoutes.reader('abc-123'), '/reader/abc-123');
    });
  });
}
