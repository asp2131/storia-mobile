// journeySnapshotProvider: the single translation site from reactive
// provider state to the plain JourneySnapshot. These tests pin the
// projection rules — especially the AsyncValue -> ProfileSelection
// flattening (loading AND error both mean "stay put").

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/auth/data/auth_providers.dart';
import 'package:storia_kids/src/features/auth/domain/auth_state.dart';
import 'package:storia_kids/src/features/child/data/child_profile_providers.dart';
import 'package:storia_kids/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:storia_kids/src/features/onboarding/domain/review_onboarding_profile.dart';
import 'package:storia_kids/src/routing/journey/journey_policy.dart';
import 'package:storia_kids/src/routing/journey/journey_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

class _FakeActiveChildProfileIdNotifier extends ActiveChildProfileIdNotifier {
  _FakeActiveChildProfileIdNotifier(AsyncValue<String?> initial)
    : super(userId: 'user-1') {
    state = initial;
  }
}

Session _fakeSession() => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00.000Z',
  ),
);

const _readyNoBypass = AppReviewFlowState(
  isReady: true,
  hasReviewBypass: false,
  parentBirthYear: null,
  onboardingProfile: null,
);

ProviderContainer _container({
  AuthViewState auth = const AuthViewState(session: null),
  AppReviewFlowState review = _readyNoBypass,
  AsyncValue<String?> selection = const AsyncValue.data(null),
}) {
  final container = ProviderContainer(
    overrides: [
      authViewStateProvider.overrideWithValue(auth),
      appReviewFlowProvider.overrideWithValue(review),
      activeChildProfileIdStateProvider.overrideWith(
        (ref) => _FakeActiveChildProfileIdNotifier(selection),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('boolean projections', () {
    test('signed-out, ready, no bypass', () {
      final snapshot = _container().read(journeySnapshotProvider);
      expect(
        snapshot,
        const JourneySnapshot(
          reviewFlowReady: true,
          hasSupabaseSession: false,
          hasReviewBypass: false,
          hasParentBirthYear: false,
          hasCompletedReviewOnboarding: false,
          profileSelection: ProfileSelection.none,
        ),
      );
    });

    test('supabase session maps to hasSupabaseSession', () {
      final snapshot = _container(
        auth: AuthViewState(session: _fakeSession()),
      ).read(journeySnapshotProvider);
      expect(snapshot.hasSupabaseSession, isTrue);
    });

    test('review flow state maps ready/bypass/birthYear/onboarding', () {
      const profile = ReviewOnboardingProfile(
        childNickname: 'Kai',
        childAgeRange: ChildAgeRange.age4to6,
        parentBirthYear: 1980,
        parentGoal: ParentGoal.lovesReading,
      );
      final snapshot = _container(
        review: const AppReviewFlowState(
          isReady: true,
          hasReviewBypass: true,
          parentBirthYear: 1980,
          onboardingProfile: profile,
        ),
      ).read(journeySnapshotProvider);
      expect(snapshot.hasReviewBypass, isTrue);
      expect(snapshot.hasParentBirthYear, isTrue);
      expect(snapshot.hasCompletedReviewOnboarding, isTrue);
    });

    test('review flow not ready maps to reviewFlowReady=false', () {
      final snapshot = _container(
        review: const AppReviewFlowState(
          isReady: false,
          hasReviewBypass: false,
          parentBirthYear: null,
          onboardingProfile: null,
        ),
      ).read(journeySnapshotProvider);
      expect(snapshot.reviewFlowReady, isFalse);
    });
  });

  group('AsyncValue -> ProfileSelection flattening', () {
    JourneySnapshot snapshotFor(AsyncValue<String?> selection) =>
        _container(selection: selection).read(journeySnapshotProvider);

    test('data with a non-empty id -> selected', () {
      expect(
        snapshotFor(const AsyncValue.data('child-1')).profileSelection,
        ProfileSelection.selected,
      );
    });

    test('data with null -> none', () {
      expect(
        snapshotFor(const AsyncValue.data(null)).profileSelection,
        ProfileSelection.none,
      );
    });

    test('data with empty/whitespace id -> none', () {
      expect(
        snapshotFor(const AsyncValue.data('')).profileSelection,
        ProfileSelection.none,
      );
      expect(
        snapshotFor(const AsyncValue.data('   ')).profileSelection,
        ProfileSelection.none,
      );
    });

    test('loading -> loading', () {
      expect(
        snapshotFor(const AsyncValue.loading()).profileSelection,
        ProfileSelection.loading,
      );
    });

    test('error -> loading (stay put, never crash-loop)', () {
      expect(
        snapshotFor(
          AsyncValue.error(StateError('prefs failed'), StackTrace.empty),
        ).profileSelection,
        ProfileSelection.loading,
      );
    });
  });
}
