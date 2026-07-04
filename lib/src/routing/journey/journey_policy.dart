/// Pure journey policy for Storia's user-entry flow.
///
/// PURE DART — this file must never import Flutter, Riverpod, go_router,
/// or Supabase. The router redirect and the screen-facing action verbs both
/// consult this module via plain value snapshots, so the entire journey
/// truth table stays unit-testable without widgets or providers.
///
/// Design: docs/implementation-plans/issue-33-journey-policy.md
/// RFC: https://github.com/asp2131/storia-mobile/issues/33
library;

/// How far child-profile selection has progressed.
///
/// Collapses the `AsyncValue<String?>` of
/// `activeChildProfileIdStateProvider` into the only three facts the policy
/// cares about. Modeled as an enum (not two booleans) so the illegal state
/// "not loaded but selected" is unrepresentable.
enum ProfileSelection {
  /// Selection (or an error treated as loading) is still resolving.
  loading,

  /// Selection resolved: no active child profile.
  none,

  /// Selection resolved: an active child profile exists.
  selected,
}

/// Plain immutable projection of everything the journey policy needs.
///
/// Assembled at the edge by `journeySnapshotProvider`; trivially
/// constructible in tests.
class JourneySnapshot {
  const JourneySnapshot({
    required this.reviewFlowReady,
    required this.hasSupabaseSession,
    required this.hasReviewBypass,
    required this.hasParentBirthYear,
    required this.hasCompletedReviewOnboarding,
    required this.profileSelection,
  });

  /// `AppReviewFlowState.isReady` — SharedPreferences loaded.
  final bool reviewFlowReady;

  /// A backend Supabase session exists (`AuthViewState.isAuthenticated`).
  final bool hasSupabaseSession;

  /// The App Review bypass track is active.
  final bool hasReviewBypass;

  /// Parent birth year captured (App Review track step).
  final bool hasParentBirthYear;

  /// Review onboarding completed (App Review track step).
  final bool hasCompletedReviewOnboarding;

  /// Child-profile selection progress (Supabase track step).
  final ProfileSelection profileSelection;

  @override
  bool operator ==(Object other) =>
      other is JourneySnapshot &&
      other.reviewFlowReady == reviewFlowReady &&
      other.hasSupabaseSession == hasSupabaseSession &&
      other.hasReviewBypass == hasReviewBypass &&
      other.hasParentBirthYear == hasParentBirthYear &&
      other.hasCompletedReviewOnboarding == hasCompletedReviewOnboarding &&
      other.profileSelection == profileSelection;

  @override
  int get hashCode => Object.hash(
    reviewFlowReady,
    hasSupabaseSession,
    hasReviewBypass,
    hasParentBirthYear,
    hasCompletedReviewOnboarding,
    profileSelection,
  );

  @override
  String toString() =>
      'JourneySnapshot('
      'ready: $reviewFlowReady, '
      'session: $hasSupabaseSession, '
      'bypass: $hasReviewBypass, '
      'birthYear: $hasParentBirthYear, '
      'onboarded: $hasCompletedReviewOnboarding, '
      'profile: ${profileSelection.name})';
}

/// Single spelling authority for every route path.
///
/// Screens must reference these constants (via the action verbs) instead of
/// route string literals; `app_router.dart` builds its `GoRoute` table from
/// the same constants so policy and routes cannot drift.
abstract final class JourneyRoutes {
  static const root = '/';
  static const intro = '/intro';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const parentBirthYear = '/parent-birth-year';
  static const onboarding = '/onboarding';
  static const profilePicker = '/profiles/select';
  static const addProfile = '/profiles/new';
  static const library = '/library';
  static const settings = '/settings';
  static const aacMusicDemo = '/aac-music-demo';

  /// Book-finished celebration, pushed over the reader. Terminal pass-through
  /// (no journey stage claims it) and requires a summary via `extra`.
  static const bookCelebration = '/celebration';

  static String reader(String bookId) => '/reader/$bookId';
}

/// Which stage of the journey a snapshot resolves to.
///
/// Computed once per call; both [JourneyPolicy.redirect] and
/// [JourneyPolicy.nextLocation] are projections of it. Precedence follows
/// the general-branch ordering of the legacy redirect closure:
/// unauthenticated → birth year → onboarding → profile loading → profile
/// picker → complete. (The legacy `/` branch checked profile selection
/// before onboarding; the orderings only diverge for a user holding BOTH a
/// Supabase session and an active review bypass, which product flows never
/// produce. This module normalizes on review steps outranking profile
/// selection everywhere.)
enum _JourneyStage {
  /// Review flow prefs not loaded yet → allow everything (no flicker).
  indeterminate,

  /// No session and no bypass → public locations only.
  unauthenticated,

  /// Bypass track: birth year not captured.
  parentBirthYear,

  /// Bypass track: birth year captured, onboarding pending.
  reviewOnboarding,

  /// Supabase track: profile selection still loading → stay put.
  profileLoading,

  /// Supabase track: no active child profile → picker (add allowed).
  profilePicker,

  /// Every applicable step complete → home; terminals pass through.
  complete,
}

/// The deep module: the entire journey graph behind two questions —
/// "may the user be at [location]?" and "where should the user go next?".
abstract final class JourneyPolicy {
  /// Where "start over" (abandoning the review flow) lands.
  static const restartTarget = JourneyRoutes.signIn;

  /// Locations reachable while signed out. `/` is intentionally absent:
  /// the root AuthGate always forwards to the stage's canonical location.
  static const _unauthenticatedAdmissible = {
    JourneyRoutes.intro,
    JourneyRoutes.signIn,
    JourneyRoutes.signUp,
  };

  /// Locations admissible while the profile-picker step is pending.
  /// Adding a profile is a legitimate detour from the picker.
  static const _profileStepAdmissible = {
    JourneyRoutes.profilePicker,
    JourneyRoutes.addProfile,
  };

  /// Pre-journey locations that bounce home once the journey is complete.
  /// `/profiles/select` and `/profiles/new` are intentionally absent: they
  /// stay reachable after completion for profile switching.
  static const _preJourneyLocations = {
    JourneyRoutes.root,
    JourneyRoutes.intro,
    JourneyRoutes.signIn,
    JourneyRoutes.signUp,
    JourneyRoutes.parentBirthYear,
    JourneyRoutes.onboarding,
  };

  /// ENTRY POINT 1 — the go_router redirect, as a pure sync total function.
  ///
  /// Returns the location to redirect to, or null to stay put. Both loading
  /// semantics surface as null: boot hold (review prefs not ready) allows
  /// everything; profile-selection loading holds the current location.
  /// Terminal routes (`/reader/:bookId`, `/settings`, `/aac-music-demo`)
  /// pass through when the journey is complete because no stage claims them.
  static String? redirect(JourneySnapshot snapshot, String location) {
    switch (_stageOf(snapshot)) {
      case _JourneyStage.indeterminate:
      case _JourneyStage.profileLoading:
        return null;
      case _JourneyStage.unauthenticated:
        return _unauthenticatedAdmissible.contains(location)
            ? null
            : JourneyRoutes.intro;
      case _JourneyStage.parentBirthYear:
        return location == JourneyRoutes.parentBirthYear
            ? null
            : JourneyRoutes.parentBirthYear;
      case _JourneyStage.reviewOnboarding:
        return location == JourneyRoutes.onboarding
            ? null
            : JourneyRoutes.onboarding;
      case _JourneyStage.profilePicker:
        return _profileStepAdmissible.contains(location)
            ? null
            : JourneyRoutes.profilePicker;
      case _JourneyStage.complete:
        return _preJourneyLocations.contains(location)
            ? JourneyRoutes.library
            : null;
    }
  }

  /// ENTRY POINT 2 — "where should the user go next?", for screens.
  ///
  /// Returns the canonical location of the current journey stage: the place
  /// a screen should `context.go(...)` after completing its step. While
  /// state is indeterminate or loading this returns [JourneyRoutes.root]
  /// (the AuthGate), which is always safe: [redirect] re-resolves the moment
  /// state settles. Invariant: `redirect(s, nextLocation(s)) == null`.
  static String nextLocation(JourneySnapshot snapshot) {
    return switch (_stageOf(snapshot)) {
      _JourneyStage.indeterminate => JourneyRoutes.root,
      _JourneyStage.unauthenticated => JourneyRoutes.intro,
      _JourneyStage.parentBirthYear => JourneyRoutes.parentBirthYear,
      _JourneyStage.reviewOnboarding => JourneyRoutes.onboarding,
      _JourneyStage.profileLoading => JourneyRoutes.root,
      _JourneyStage.profilePicker => JourneyRoutes.profilePicker,
      _JourneyStage.complete => JourneyRoutes.library,
    };
  }

  /// Static back edge for a journey step (pure lookup table). Unknown
  /// locations fall back to the root AuthGate, which re-resolves safely.
  static String backTarget(String location) {
    return switch (location) {
      JourneyRoutes.signIn || JourneyRoutes.signUp => JourneyRoutes.intro,
      JourneyRoutes.addProfile => JourneyRoutes.profilePicker,
      _ => JourneyRoutes.root,
    };
  }

  static _JourneyStage _stageOf(JourneySnapshot s) {
    if (!s.reviewFlowReady) {
      return _JourneyStage.indeterminate;
    }
    final isSignedIn = s.hasSupabaseSession || s.hasReviewBypass;
    if (!isSignedIn) {
      return _JourneyStage.unauthenticated;
    }
    if (s.hasReviewBypass && !s.hasParentBirthYear) {
      return _JourneyStage.parentBirthYear;
    }
    if (s.hasReviewBypass && !s.hasCompletedReviewOnboarding) {
      return _JourneyStage.reviewOnboarding;
    }
    // Only backend-auth accounts require a real child profile; the bypass
    // track never blocks on profile selection.
    if (s.hasSupabaseSession &&
        s.profileSelection == ProfileSelection.loading) {
      return _JourneyStage.profileLoading;
    }
    if (s.hasSupabaseSession && s.profileSelection == ProfileSelection.none) {
      return _JourneyStage.profilePicker;
    }
    return _JourneyStage.complete;
  }
}
