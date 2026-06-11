import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/child/data/child_profile_providers.dart';
import '../../features/onboarding/data/app_review_flow_providers.dart';
import 'journey_policy.dart';

/// THE single translation site: reactive provider state → plain
/// [JourneySnapshot]. Supabase's `Session`, `AppReviewFlowState`, and
/// `AsyncValue` each appear exactly once on the journey's input path, here.
///
/// Synchronous projection, no awaits — all asynchrony stays upstream in the
/// notifiers, which is what keeps go_router's sync `redirect` contract
/// honest when it does `ref.read(journeySnapshotProvider)`.
///
/// IMPORTANT — merge-list binding: every state source watched here must
/// have its notifier included in the router's `refreshListenable:
/// Listenable.merge([...])` in `app_router.dart`. A source added to this
/// snapshot but not to the merge list would stall journey advancement
/// (redirect never re-evaluates when that source changes). Current pairing:
///   authViewStateProvider            ← authStateNotifierProvider
///   appReviewFlowProvider            ← appReviewFlowNotifierProvider
///   activeChildProfileIdStateProvider← childProfileRouterRefreshProvider
final journeySnapshotProvider = Provider<JourneySnapshot>((ref) {
  final auth = ref.watch(authViewStateProvider);
  final review = ref.watch(appReviewFlowProvider);
  final selection = ref.watch(activeChildProfileIdStateProvider);

  return JourneySnapshot(
    reviewFlowReady: review.isReady,
    hasSupabaseSession: auth.isAuthenticated,
    hasReviewBypass: review.hasReviewBypass,
    hasParentBirthYear: review.hasParentBirthYear,
    hasCompletedReviewOnboarding: review.hasCompletedOnboarding,
    // AsyncValue → tri-state flattening. Loading AND error both map to
    // `loading` ("stay put"), preserving the legacy closure's
    // `hasValue == false` behavior. If an error stage is ever wanted,
    // only this switch changes.
    profileSelection: switch (selection) {
      AsyncData(:final value) when (value?.trim().isNotEmpty ?? false) =>
        ProfileSelection.selected,
      AsyncData() => ProfileSelection.none,
      _ => ProfileSelection.loading,
    },
  );
});
