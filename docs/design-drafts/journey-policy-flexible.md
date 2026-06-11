# Journey Policy — Design B: Maximize Flexibility ("Journey as Data")

**Author:** fullstack (squad design draft)
**Status:** Design draft — no code changed
**Module location (proposed):** `lib/src/journey/` (pure Dart core) + `lib/src/routing/journey_providers.dart` (Riverpod edge)

---

## 0. Design thesis

The current redirect closure in `app_router.dart` is a single 100-line decision
tree that hand-encodes three orthogonal things at once:

1. **What the journey is** — which steps exist, in what order, for which track
   (Supabase auth vs App Review bypass).
2. **How journey state maps to routing** — redirect / allow / stay-put.
3. **Loading semantics** — `reviewFlow not ready` = allow everything;
   `profile selection loading` = stay put.

Design B separates (1) from (2)+(3). The journey itself becomes **declarative
data** — an ordered list of tracks, each an ordered list of steps, each step a
pair of small predicates over a plain snapshot. The resolver core is ~50 lines
of generic walking logic that **never changes** when the journey changes.

Adding an email-verification step, a second onboarding variant, a new track, a
conditional step, or reordering steps = editing one declaration file
(`storia_journey.dart`). The resolver, the router redirect, and the screens are
untouched.

---

## 1. Interface signature (pure Dart, no Flutter/Riverpod/Supabase/go_router imports)

### 1.1 Facts & snapshot — the extensible input surface

Instead of a fixed snapshot class whose fields must grow every time a step
needs new state, the snapshot is a typed **fact bag**. New steps bring new
facts; the snapshot type never changes.

```dart
// lib/src/journey/journey_snapshot.dart

/// A typed key identifying one piece of journey-relevant state.
final class FactKey<T> {
  const FactKey(this.name);
  final String name; // for debugging / explain()
  @override
  String toString() => 'Fact($name)';
}

/// Every fact is tri-state: absent, loading, or ready(value).
/// "Loading" is how async edges (AsyncValue, not-yet-loaded prefs)
/// are represented WITHOUT the core knowing about AsyncValue.
sealed class FactState<T> {
  const FactState();
}

final class FactLoading<T> extends FactState<T> {
  const FactLoading();
}

final class FactReady<T> extends FactState<T> {
  const FactReady(this.value);
  final T value;
}

/// Immutable, synchronous, plain-Dart input to every policy decision.
final class JourneySnapshot {
  const JourneySnapshot(this._facts);
  final Map<FactKey<Object?>, FactState<Object?>> _facts;

  /// Ready value, or null when loading/absent.
  T? value<T>(FactKey<T> key);

  /// Ready value with a fallback (the common predicate helper).
  T valueOr<T>(FactKey<T> key, T fallback);

  bool isLoading<T>(FactKey<T> key);
  bool has<T>(FactKey<T> key);
}

/// Mutable builder used only at the edge (provider layer).
final class JourneySnapshotBuilder {
  void ready<T>(FactKey<T> key, T value);
  void loading<T>(FactKey<T> key);
  JourneySnapshot build();
}
```

The facts Storia needs **today** are declared alongside the journey definition
(not inside the core — the core is fact-agnostic):

```dart
// lib/src/journey/storia_facts.dart

abstract final class StoriaFacts {
  /// True when a Supabase session exists.
  static const supabaseSession = FactKey<bool>('supabaseSession');

  /// True when the App Review bypass is enabled.
  /// LOADING until AppReviewFlowState.isReady — this drives the boot hold.
  static const reviewBypass = FactKey<bool>('reviewBypass');

  /// Parent birth year captured during the review flow (null = not captured).
  static const parentBirthYear = FactKey<int?>('parentBirthYear');

  /// True when the review onboarding profile has been saved.
  static const reviewOnboardingDone = FactKey<bool>('reviewOnboardingDone');

  /// Active child profile id; LOADING while prefs are being read.
  /// (Mirrors AsyncValue<String?> from activeChildProfileIdStateProvider.)
  static const activeChildProfileId = FactKey<String?>('activeChildProfileId');
}
```

### 1.2 Steps — the unit of journey progress

```dart
// lib/src/journey/journey_step.dart

extension type const StepId(String value) {}

/// What a step reports about the current snapshot.
enum StepStatus {
  /// Step doesn't apply under this snapshot (conditional steps).
  notApplicable,

  /// The facts this step needs are still loading → resolver holds (stay put).
  loading,

  /// Step applies and is not yet done → user must be sent to [route].
  incomplete,

  /// Step is done.
  complete,
}

final class JourneyStep {
  const JourneyStep({
    required this.id,
    required this.route,
    required this.status,
    this.alsoAllowedWhilePending = const <String>{},
    this.exitWhenComplete = true,
  });

  final StepId id;

  /// Where the user is sent while this step is incomplete.
  final String route;

  /// The entire behavior of the step: a sync, pure function of the snapshot.
  final StepStatus Function(JourneySnapshot s) status;

  /// Extra locations the user may visit while this step is pending
  /// (e.g. '/profiles/new' is fine while the profile-select step is pending).
  final Set<String> alsoAllowedWhilePending;

  /// When true: once the whole journey is complete, landing on this step's
  /// route bounces to home. When false the route stays reachable forever
  /// (e.g. '/profiles/select' for switching profiles later).
  final bool exitWhenComplete;
}
```

### 1.3 Tracks — conditionally included step groups

```dart
// lib/src/journey/journey_track.dart

extension type const TrackId(String value) {}

/// A track is a named, conditionally active group of steps.
/// IMPORTANT: tracks are NOT mutually exclusive. All active tracks
/// contribute their steps, concatenated in declaration order. This is how
/// the App Review track's steps (birth year, onboarding) run BEFORE the
/// Supabase track's profile-selection step when both are active.
final class JourneyTrack {
  const JourneyTrack({
    required this.id,
    required this.isActive,
    required this.steps,
  });

  final TrackId id;
  final bool Function(JourneySnapshot s) isActive;
  final List<JourneyStep> steps;
}
```

### 1.4 The journey definition — everything routing-policy-shaped, as data

```dart
// lib/src/journey/journey_definition.dart

final class JourneyDefinition {
  const JourneyDefinition({
    required this.tracks,
    required this.entryRoute,
    required this.homeRoute,
    required this.unauthenticatedRoute,
    required this.publicRoutes,
    required this.bootHold,
  });

  /// Ordered. Active tracks' steps are concatenated in this order.
  /// No active track == "unauthenticated".
  final List<JourneyTrack> tracks;

  /// The splash/gate route ('/') that always forwards somewhere.
  final String entryRoute;

  /// Where a completed journey lands ('/library').
  final String homeRoute;

  /// Where unauthenticated users are sent ('/intro').
  final String unauthenticatedRoute;

  /// Routes reachable without any active track ('/intro', '/sign-in', ...).
  /// Once the journey is COMPLETE these bounce to [homeRoute].
  final Set<String> publicRoutes;

  /// When true, the app hasn't booted far enough to make ANY decision →
  /// resolver allows everything (current: !appReviewState.isReady).
  final bool Function(JourneySnapshot s) bootHold;
}
```

### 1.5 The resolver — the generic, closed core

```dart
// lib/src/journey/journey_policy.dart

/// What the router should do for (snapshot, location).
sealed class JourneyDecision {
  const JourneyDecision();
}

/// Let navigation proceed (go_router redirect returns null).
final class Allow extends JourneyDecision { const Allow(); }

/// Hold the current location while something loads (also null at the edge,
/// but semantically distinct — and distinguishable in tests/explain()).
final class StayPut extends JourneyDecision { const StayPut(); }

/// Send the user elsewhere.
final class Redirect extends JourneyDecision {
  const Redirect(this.location);
  final String location;
}

final class JourneyPolicy {
  const JourneyPolicy(this.definition);
  final JourneyDefinition definition;

  /// THE routing entry point. Pure, synchronous, total.
  JourneyDecision resolve(JourneySnapshot s, String location);

  /// THE screen entry point: "where should the user be right now?"
  /// null = hold (something is loading; don't navigate yet).
  /// Screens call this instead of hardcoding '/parent-birth-year' etc.
  String? nextLocation(JourneySnapshot s);

  /// The next pending step, for screens that want richer info
  /// (e.g. progress indicators). null = journey complete or holding.
  JourneyStep? nextStep(JourneySnapshot s);

  /// True when every applicable step is complete (terminal routes pass).
  bool isComplete(JourneySnapshot s);

  /// Debug/test aid: per-step evaluation trace for a snapshot+location.
  JourneyExplanation explain(JourneySnapshot s, String location);
}

/// One row per consulted track/step, plus the final decision. Makes the
/// declarative engine debuggable ("why did I get redirected?").
final class JourneyExplanation {
  final List<({TrackId track, bool active})> tracks;
  final List<({StepId step, StepStatus status})> steps;
  final JourneyDecision decision;
}
```

**Resolver algorithm** (the whole core — it never changes when steps change):

```dart
JourneyDecision resolve(JourneySnapshot s, String location) {
  // 1. Boot hold: too early to decide anything → allow all.
  if (definition.bootHold(s)) return const Allow();

  // 2. Collect steps from all active tracks, in declaration order.
  final active = definition.tracks.where((t) => t.isActive(s));
  if (active.isEmpty) {
    // Unauthenticated: public routes pass, everything else → /intro.
    if (location != definition.entryRoute &&
        definition.publicRoutes.contains(location)) {
      return const Allow();
    }
    return location == definition.unauthenticatedRoute
        ? const Allow()
        : Redirect(definition.unauthenticatedRoute);
  }
  final steps = [for (final t in active) ...t.steps];

  // 3. Walk steps in order; first blocker wins.
  for (final step in steps) {
    switch (step.status(s)) {
      case StepStatus.notApplicable || StepStatus.complete:
        continue;
      case StepStatus.loading:
        return const StayPut(); // e.g. profile selection still loading
      case StepStatus.incomplete:
        final allowedHere = location == step.route ||
            step.alsoAllowedWhilePending.contains(location);
        return allowedHere ? const Allow() : Redirect(step.route);
    }
  }

  // 4. Journey complete: pre-journey routes bounce home, all else passes
  //    (terminal routes /reader/:bookId, /settings, /aac-music-demo
  //    were never claimed by any step or public set → Allow).
  final isPreJourney = location == definition.entryRoute ||
      definition.publicRoutes.contains(location) ||
      steps.any((st) => st.exitWhenComplete && st.route == location);
  return isPreJourney ? Redirect(definition.homeRoute) : const Allow();
}
```

### 1.6 Storia's journey, declared

This file is the **only** file edited when the journey changes:

```dart
// lib/src/journey/storia_journey.dart

final parentBirthYearStep = JourneyStep(
  id: const StepId('parent-birth-year'),
  route: '/parent-birth-year',
  status: (s) {
    if (s.isLoading(StoriaFacts.parentBirthYear)) return StepStatus.loading;
    return s.value(StoriaFacts.parentBirthYear) != null
        ? StepStatus.complete
        : StepStatus.incomplete;
  },
);

final reviewOnboardingStep = JourneyStep(
  id: const StepId('review-onboarding'),
  route: '/onboarding',
  status: (s) {
    if (s.isLoading(StoriaFacts.reviewOnboardingDone)) return StepStatus.loading;
    return s.valueOr(StoriaFacts.reviewOnboardingDone, false)
        ? StepStatus.complete
        : StepStatus.incomplete;
  },
);

final selectChildProfileStep = JourneyStep(
  id: const StepId('select-child-profile'),
  route: '/profiles/select',
  // Users revisit the picker to switch profiles after the journey is done:
  exitWhenComplete: false,
  // Adding a profile is a legitimate detour while selection is pending:
  alsoAllowedWhilePending: const {'/profiles/new'},
  status: (s) {
    if (s.isLoading(StoriaFacts.activeChildProfileId)) {
      return StepStatus.loading; // ← "profile selection loading = stay put"
    }
    final id = s.value(StoriaFacts.activeChildProfileId);
    return (id != null && id.trim().isNotEmpty)
        ? StepStatus.complete
        : StepStatus.incomplete;
  },
);

final storiaJourney = JourneyDefinition(
  entryRoute: '/',
  homeRoute: '/library',
  unauthenticatedRoute: '/intro',
  publicRoutes: const {'/intro', '/sign-in', '/sign-up'},
  // "reviewFlow not ready = allow all":
  bootHold: (s) => s.isLoading(StoriaFacts.reviewBypass),
  tracks: [
    // Declared FIRST so its steps run before profile selection when a
    // user somehow has both bypass and a Supabase session (matches the
    // dominant branch ordering of the current closure).
    JourneyTrack(
      id: const TrackId('app-review'),
      isActive: (s) => s.valueOr(StoriaFacts.reviewBypass, false),
      steps: [parentBirthYearStep, reviewOnboardingStep],
    ),
    JourneyTrack(
      id: const TrackId('supabase'),
      isActive: (s) => s.valueOr(StoriaFacts.supabaseSession, false),
      steps: [selectChildProfileStep],
    ),
  ],
);
```

> **Fidelity note:** the current closure has one internal inconsistency — at
> `/` it checks profile selection *before* review onboarding, but on every
> other route it checks onboarding first. The two orderings only diverge for
> a user with both a Supabase session **and** an active review bypass, which
> the product flows never produce (bypass users don't sign in). Design B
> normalizes on the general-branch ordering: review steps → profile step.

---

## 2. Usage examples

### 2.1 New `app_router.dart` redirect closure

The 100-line closure shrinks to a snapshot read + a `switch`:

```dart
// lib/src/routing/app_router.dart  (illustrative — NOT applied)

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);
  final appReviewNotifier = ref.watch(appReviewFlowNotifierProvider);
  final childProfileNotifier = ref.watch(childProfileRouterRefreshProvider);
  const policy = JourneyPolicy(storiaJourney);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      authNotifier,
      appReviewNotifier,
      childProfileNotifier,
    ]),
    redirect: (context, state) {
      // ref.read (not watch): refreshListenable already re-runs redirect
      // on every relevant change; reading avoids rebuilding the GoRouter
      // itself (a latent churn issue in the current implementation).
      final snapshot = ref.read(journeySnapshotProvider);
      return switch (policy.resolve(snapshot, state.matchedLocation)) {
        Redirect(:final location) => location,
        Allow() || StayPut() => null,
      };
    },
    routes: [ /* unchanged — same GoRoute table */ ],
  );
});
```

### 2.2 A screen asking "what's next" instead of hardcoding routes

`sign_up_screen.dart` currently hardcodes `/library` (in the auth listener)
and `/parent-birth-year` (after enabling the review bypass). Both become
`journeyNextLocationProvider` reads:

```dart
// Riverpod edge (lib/src/routing/journey_providers.dart) — see §4 for
// journeySnapshotProvider. Hand-written providers, no codegen.

final journeyPolicyProvider =
    Provider<JourneyPolicy>((ref) => const JourneyPolicy(storiaJourney));

/// "Where should the user be right now?" — null means hold (loading).
final journeyNextLocationProvider = Provider<String?>((ref) {
  final policy = ref.watch(journeyPolicyProvider);
  final snapshot = ref.watch(journeySnapshotProvider);
  return policy.nextLocation(snapshot);
});
```

```dart
// sign_up_screen.dart (illustrative — NOT applied)

@override
Widget build(BuildContext context) {
  // BEFORE: listened to authViewStateProvider, compared matchedLocation
  // against a hardcoded {'/sign-up','/sign-in','/intro'} set, then
  // context.go('/library').
  // AFTER: one listener, zero hardcoded destinations:
  ref.listen<String?>(journeyNextLocationProvider, (previous, next) {
    if (!mounted || next == null) return;
    final here = GoRouterState.of(context).matchedLocation;
    if (next != here) context.go(next);
  });
  // ... rest of build unchanged
}

Future<void> _submitAppReviewBypass(String email) async {
  // ...
  await ref.read(appReviewFlowNotifierProvider).enableReviewBypass(email: email);
  if (!mounted) return;
  // BEFORE: context.go('/parent-birth-year');   ← hardcoded journey knowledge
  // AFTER: the journey decides; today it answers '/parent-birth-year',
  // and if a step is ever inserted before it, this line stays correct.
  final next = ref.read(journeyNextLocationProvider);
  if (next != null) context.go(next);
  // ...
}
```

The same pattern retires all 18 `context.go(` journey-destination call sites
across the 7 screens (back-navigation like `context.go('/intro')` from a
public screen is UI chrome, not journey policy, and may stay literal).

### 2.3 Adding a hypothetical email-verification step

Three edits, **zero resolver/core/screen changes**:

```dart
// 1. New fact (storia_facts.dart):
static const emailVerified = FactKey<bool>('emailVerified');

// 2. New step, inserted into the Supabase track BEFORE profile selection
//    (storia_journey.dart):
final verifyEmailStep = JourneyStep(
  id: const StepId('verify-email'),
  route: '/verify-email',
  status: (s) {
    // Conditional-step example: only applies to sessions created after
    // the feature ships — older sessions skip it entirely.
    if (!s.valueOr(StoriaFacts.requiresEmailVerification, false)) {
      return StepStatus.notApplicable;
    }
    if (s.isLoading(StoriaFacts.emailVerified)) return StepStatus.loading;
    return s.valueOr(StoriaFacts.emailVerified, false)
        ? StepStatus.complete
        : StepStatus.incomplete;
  },
);

JourneyTrack(
  id: const TrackId('supabase'),
  isActive: (s) => s.valueOr(StoriaFacts.supabaseSession, false),
  steps: [verifyEmailStep, selectChildProfileStep],   // ← one-line insert
),

// 3. Feed the facts at the edge (journey_providers.dart):
//    b.ready(StoriaFacts.emailVerified, auth.session?.user.emailConfirmedAt != null);
//    ...and register GoRoute('/verify-email', ...) in the route table.
```

Every screen that uses `journeyNextLocationProvider` automatically routes
through `/verify-email` at the right moment. A **second onboarding variant**
is the same move at track granularity: add a
`JourneyTrack(id: 'onboarding-v2', isActive: (s) => s.valueOr(onboardingVariant, 'v1') == 'v2', steps: [...])`
and gate the old track's `isActive` on `== 'v1'`. **Reordering** is literally
reordering a Dart list literal.

---

## 3. Complexity hidden inside the module

| Hidden concern | How it's hidden |
|---|---|
| **Two tracks (Supabase vs App Review bypass)** | Callers never see `hasReviewBypass` or `session != null`. Tracks are internal data; screens and the router only see `resolve()` / `nextLocation()`. "Authenticated" is derived: *any track active*. |
| **Simultaneous-track interleaving** | The current closure's subtle property — review steps outrank profile selection when both tracks apply — is encoded once as track declaration order, not re-derived per branch. |
| **Boot loading semantics** (`!appReviewState.isReady` → allow all) | `bootHold` predicate + the `FactLoading` state on review facts. Callers never check `isReady`. |
| **Profile-selection loading semantics** (AsyncValue loading → stay put) | `StepStatus.loading` → `StayPut`. The `AsyncValue` tri-state is flattened into a `FactState` at the edge; the core has no Riverpod types. |
| **Pending-step detours** (`/profiles/new` allowed while picking) | `alsoAllowedWhilePending` per step, instead of the closure's special-cased `isAddProfile` boolean. |
| **Post-completion bounce rules** (auth/onboarding screens → `/library`, but `/profiles/select` stays reachable for switching) | `exitWhenComplete` per step + `publicRoutes` bounce. The closure's hardcoded 5-route `location == ...` chain disappears. |
| **Terminal pass-through** (`/reader/:bookId`, `/settings`, `/aac-music-demo`) | By construction: routes not claimed by any step, not public, not entry → `Allow` when the journey is complete. No allowlist to maintain. |
| **"Why did I get redirected?"** | `explain()` returns the full track/step evaluation trace — the declarative engine's answer to the debuggability of an imperative `if` chain. |

The core is **closed for modification, open for extension**: new steps,
tracks, facts, conditions, and orderings live entirely in
`storia_journey.dart` + the snapshot edge.

---

## 4. Dependency strategy (in-process; snapshot assembly at the edge)

The core takes **zero dependencies** — it only ever sees a `JourneySnapshot`.
All translation from app state to facts happens in one hand-written Riverpod
provider at the edge (Riverpod 2.6, no codegen):

```dart
// lib/src/routing/journey_providers.dart (illustrative — NOT applied)

final journeySnapshotProvider = Provider<JourneySnapshot>((ref) {
  final auth = ref.watch(authViewStateProvider);          // AuthViewState
  final review = ref.watch(appReviewFlowProvider);        // AppReviewFlowState
  final profile = ref.watch(activeChildProfileIdStateProvider); // AsyncValue<String?>

  final b = JourneySnapshotBuilder();

  b.ready(StoriaFacts.supabaseSession, auth.isAuthenticated);

  if (!review.isReady) {
    // Boot hold encoded as loading facts — the ONLY place isReady appears.
    b.loading(StoriaFacts.reviewBypass);
    b.loading(StoriaFacts.parentBirthYear);
    b.loading(StoriaFacts.reviewOnboardingDone);
  } else {
    b.ready(StoriaFacts.reviewBypass, review.hasReviewBypass);
    b.ready(StoriaFacts.parentBirthYear, review.parentBirthYear);
    b.ready(StoriaFacts.reviewOnboardingDone, review.hasCompletedOnboarding);
  }

  // AsyncValue → FactState flattening. Error is mapped to loading, which
  // preserves the current behavior (hasValue == false → stay put).
  switch (profile) {
    case AsyncData(:final value):
      b.ready(StoriaFacts.activeChildProfileId, value);
    default:
      b.loading(StoriaFacts.activeChildProfileId);
  }

  return b.build();
});
```

Key points:

- **In-process, synchronous.** The provider recomputes whenever any watched
  source changes; `refreshListenable` (unchanged from today) re-runs the
  redirect, which `ref.read`s the freshly cached snapshot. The go_router
  sync-redirect constraint is satisfied because all async work already
  happened upstream in the notifiers.
- **One translation site.** Supabase's `Session`, `AppReviewFlowState`, and
  `AsyncValue` each appear exactly once, here. Swapping Supabase for another
  auth provider, or prefs for a server flag, touches only this file.
- **Testing.** Core tests construct snapshots directly via the builder — no
  ProviderContainer, no fakes, no async: `expect(policy.resolve(snap, '/settings'), isA<Allow>())`.
  A table-driven test over (facts × locations) covers the entire policy.

Proposed layout:

```
lib/src/journey/                 # pure Dart, zero Flutter imports
  journey_snapshot.dart          # FactKey, FactState, JourneySnapshot(+Builder)
  journey_step.dart              # StepId, StepStatus, JourneyStep
  journey_track.dart             # TrackId, JourneyTrack
  journey_definition.dart        # JourneyDefinition
  journey_policy.dart            # JourneyDecision, JourneyPolicy, explain()
  storia_facts.dart              # Storia's fact keys
  storia_journey.dart            # ← the only file edited when the journey changes
lib/src/routing/
  journey_providers.dart         # snapshot assembly + policy/nextLocation providers
  app_router.dart                # thin redirect (≈10 lines)
```

---

## 5. Trade-offs of the flexible approach (honest accounting)

**Costs:**

1. **Concept count.** One closure becomes six concepts: `FactKey`,
   `JourneySnapshot`, `JourneyStep`, `JourneyTrack`, `JourneyDefinition`,
   `JourneyDecision`. A newcomer must learn the mini-framework before reading
   the journey. The imperative closure, for all its flaws, reads top-to-bottom.
2. **Fact bag sacrifices compile-time safety.** A fixed snapshot class
   (`snapshot.hasActiveProfile`) fails at compile time when a field is
   missing; a `FactKey` the edge forgot to populate fails at *runtime* (reads
   as absent/loading → silent stay-put, the worst failure mode: a stuck
   screen). Mitigation — `JourneyDefinition` can declare
   `requiredFacts: Set<FactKey>` and the policy can assert-throw in debug
   builds when a snapshot is missing one — but that's more machinery to carry.
3. **Behavior is implicit in data ordering.** "Birth year before onboarding"
   is a list position, not an `if` you can read. Subtle bugs become
   *declaration* bugs (wrong list order, wrong `exitWhenComplete` flag) which
   are harder to spot in review than a wrong conditional. `explain()` and a
   table-driven test suite are not optional extras here — they're the price
   of admission.
4. **Speculative generality (YAGNI risk).** Today's journey is 2 tracks and
   3 steps. We're buying open-ended extensibility (N tracks, conditional
   steps, reordering) against *one* hypothetical future step. If the journey
   never grows past ~5 steps, Design A's handful of plain functions would
   carry the same behavior at a third of the surface area.
5. **Two route registries.** Step routes live in `storia_journey.dart`, route
   builders in the `GoRoute` table. They can drift (a step routing to a path
   no `GoRoute` serves). A debug-mode cross-check at router construction
   closes the gap, but it's another seam to maintain.
6. **Generic core resists special cases.** If a future requirement doesn't
   fit "walk steps in order, first blocker wins" (say, a step that must
   re-trigger after completion, or location-dependent step order), the choice
   is to extend the framework (more concepts) or bolt an `if` onto the edge
   (eroding the model). An imperative closure absorbs warts cheaply; a
   declarative engine makes them expensive *and visible* — which is both a
   feature and a cost.

**What the cost buys:**

- Journey changes (the most likely change axis for a kids' app still iterating
  on onboarding/compliance: email verification, COPPA gates, A/B onboarding
  variants, subscription paywalls) become single-file data edits with no risk
  of regressing the resolver.
- The entire policy is exhaustively unit-testable as a pure function —
  something the current closure (entangled with Riverpod and go_router) has
  **zero** tests for today.
- The 18 screen-side hardcoded `context.go()` destinations collapse onto one
  provider, eliminating the class of bug where a screen and the redirect
  disagree about the next step.

**Honest verdict:** this design is the right choice **if** the team believes
the journey will keep growing (more steps/tracks within the next few
quarters). If the journey is essentially frozen, the fact-bag + track engine
is over-engineering, and a fixed-snapshot design with 1–3 entry points
(Design A) delivers the same testability with far less ceremony. The middle
ground worth considering at review time: keep this design's *step list* idea
but with a **fixed, typed snapshot class** instead of the fact bag — that
retains one-line step insertion while restoring compile-time safety, at the
cost of touching the snapshot class whenever a new fact appears.
