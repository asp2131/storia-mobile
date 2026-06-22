# Design A — Journey Policy, Minimal Interface

**Author:** architect (squad)
**Status:** Design draft — no code changes
**Module location (proposed):** `lib/src/routing/journey/journey_policy.dart` (pure Dart, single file)
**Edge adapter (proposed):** `lib/src/routing/journey_snapshot_provider.dart` (Riverpod, hand-written)

---

## 0. Design thesis

The entire user journey — intro → auth → app-review birth-year → app-review
onboarding → supabase profile-picker → library, across two tracks (real
Supabase auth vs App Review bypass), with two distinct loading semantics —
collapses into **one value type and two pure functions**:

```
JourneySnapshot  (input: 6 plain fields)
JourneyPolicy.redirect(snapshot, location) → String?    // for go_router
JourneyPolicy.nextLocation(snapshot)       → String     // for screens
```

That is the whole public surface. **Total entry points: 2 functions + 1 input
type.** Everything else — the journey graph, track selection, stage ordering,
admissible-location sets, loading semantics — is private.

The key internal insight that makes a 2-function interface possible: every
question the router or a screen can ask reduces to *"which stage of the
journey is this user in?"* A private `_JourneyStage` enum is computed once
from the snapshot; both public functions are trivial projections of it.

---

## 1. Interface signature (Dart)

```dart
// lib/src/routing/journey/journey_policy.dart
//
// PURE DART. Imports nothing but dart core. No Riverpod, no Flutter,
// no Supabase, no go_router. Fully unit-testable with table-driven tests.

/// Three-state answer to "has the user picked a child profile?"
/// Modeled as an enum (not two booleans) so the illegal state
/// (not-loaded but selected) is unrepresentable.
enum ProfileSelection { loading, none, selected }

/// Plain snapshot of everything the journey policy needs to decide.
/// Assembled at the edge (see §4). Immutable, ==/hashCode by value,
/// trivially constructible in tests.
class JourneySnapshot {
  const JourneySnapshot({
    required this.reviewFlowReady,        // AppReviewFlowState.isReady
    required this.hasSupabaseSession,     // AuthViewState.isAuthenticated
    required this.hasReviewBypass,        // AppReviewFlowState.hasReviewBypass
    required this.hasParentBirthYear,     // AppReviewFlowState.hasParentBirthYear
    required this.hasCompletedReviewOnboarding, // .hasCompletedOnboarding
    required this.profileSelection,       // from AsyncValue<String?> (see §4)
  });

  final bool reviewFlowReady;
  final bool hasSupabaseSession;
  final bool hasReviewBypass;
  final bool hasParentBirthYear;
  final bool hasCompletedReviewOnboarding;
  final ProfileSelection profileSelection;

  // ==, hashCode, toString by value (hand-written, no codegen).
}

/// The deep module. Stateless; both entry points are pure synchronous
/// functions over a snapshot — safe to call from go_router's sync redirect.
abstract final class JourneyPolicy {
  /// ENTRY POINT 1 — for the router.
  ///
  /// Returns the location to redirect to, or null to stay put.
  /// `location` is GoRouterState.matchedLocation. Null is also returned
  /// for every location while the journey state is indeterminate
  /// (reviewFlow not ready, or backend profile selection still loading)
  /// — callers never see those rules, they just get null.
  static String? redirect(JourneySnapshot snapshot, String location);

  /// ENTRY POINT 2 — for screens ("what's next?").
  ///
  /// Returns the canonical location for the user's current journey
  /// stage: the place a screen should `context.go(...)` to after
  /// completing its step. When the journey is complete this is
  /// '/library'. When state is indeterminate it returns '/' (the
  /// AuthGate), which is always safe: the redirect re-resolves the
  /// moment state settles. Screens never hardcode a route again.
  static String nextLocation(JourneySnapshot snapshot);
}
```

### Private internals (NOT exported — shown to demonstrate depth)

```dart
/// Computed once per call; both entry points project from it.
enum _JourneyStage {
  indeterminate,     // reviewFlow not ready → allow everything
  unauthenticated,   // → /intro (public: /, /intro, /sign-in, /sign-up)
  parentBirthYear,   // bypass track, no birth year → /parent-birth-year only
  reviewOnboarding,  // bypass track, birth year done → /onboarding only
  profileLoading,    // supabase track, selection loading → stay put everywhere
  profilePicker,     // supabase track, no active profile → /profiles/select (+ /profiles/new)
  complete,          // → /library; terminal routes pass through
}

_JourneyStage _stageOf(JourneySnapshot s) { ... }          // the journey graph
Set<String> _admissibleLocations(_JourneyStage stage) { ... }
String _canonicalLocation(_JourneyStage stage) { ... }
```

`redirect` = *"is `location` admissible for the stage? null : canonical
location (with the gating-screen kick-forward rules folded in)"*.
`nextLocation` = *"canonical location of the stage"*. One graph, two views.

---

## 2. Usage examples

### 2a. New `app_router.dart` redirect closure

The 100-line closure becomes three lines. The provider keeps its existing
`refreshListenable` wiring (unchanged — change-detection stays at the edge).

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);
  final appReviewNotifier = ref.watch(appReviewFlowNotifierProvider);
  final childProfileNotifier = ref.watch(childProfileRouterRefreshProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      authNotifier,
      appReviewNotifier,
      childProfileNotifier,
    ]),
    redirect: (context, state) => JourneyPolicy.redirect(
      ref.read(journeySnapshotProvider),   // sync read; see §4
      state.matchedLocation,
    ),
    routes: [ /* unchanged */ ],
  );
});
```

Note `ref.read` (not `watch`) inside the closure: the `refreshListenable`
already triggers re-evaluation; reading the snapshot provider at redirect
time guarantees the freshest values without rebuilding the router.

### 2b. `sign_up_screen.dart` — both call sites

Today the screen hardcodes two journey decisions: `/library` after auth and
`/parent-birth-year` after enabling the review bypass. Both become the same
question — *"what's next?"*:

```dart
// Site 1: auth listener (replaces the hardcoded '/library' + location check)
ref.listen<AuthViewState>(authViewStateProvider, (previous, next) {
  if (!mounted || !next.isAuthenticated) return;
  final location = GoRouterState.of(context).matchedLocation;
  if (location == '/sign-up' || location == '/sign-in' || location == '/intro') {
    context.go(JourneyPolicy.nextLocation(ref.read(journeySnapshotProvider)));
  }
});

// Site 2: App Review bypass submission (replaces '/parent-birth-year')
Future<void> _submitAppReviewBypass(String email) async {
  ...
  await ref.read(appReviewFlowNotifierProvider).enableReviewBypass(email: email);
  if (!mounted) return;
  context.go(JourneyPolicy.nextLocation(ref.read(journeySnapshotProvider)));
  ...
}
```

Site 2 is the payoff: after `enableReviewBypass`, the snapshot (read fresh
via `ref.read`) shows `hasReviewBypass: true, hasParentBirthYear: false`,
so `nextLocation` returns `/parent-birth-year` — the screen no longer knows
the journey order. If a step is later inserted between sign-up and
birth-year, **zero screens change**. The same pattern replaces the journey
hops in `sign_in_screen`, `parent_birth_year_screen` (→ `/onboarding`),
`review_onboarding_screen` (→ `/library`), `profile_picker_screen` and
`add_child_screen` (→ `/library`). Lateral, non-journey navigation
(`/intro` ↔ `/sign-in` ↔ `/sign-up`, back buttons, `/profiles/new`)
legitimately stays as `context.go('/sign-in')` etc. — those are UI choices,
not journey policy, and the redirect guard still validates them.

---

## 3. Complexity hidden inside the module

Everything below is invisible to all callers:

1. **The journey graph and its ordering** — intro → auth → birth-year →
   onboarding → profile-picker → library, including the precedence rules
   (birth-year outranks onboarding outranks profile-picker) currently
   spread across 6 sequential `if` blocks.
2. **Track selection** — "authenticated" means `session OR bypass`;
   "needs a backend profile" means `session` specifically; the bypass
   track skips the profile-picker entirely. Callers never see two tracks.
3. **Both loading semantics** — `reviewFlowReady == false` ⇒ stage
   `indeterminate` ⇒ `redirect` returns null for *every* location
   ("allow all, decide later"); profile selection loading ⇒ stage
   `profileLoading` ⇒ null too ("stay put"). The two semantics are
   currently expressed three separate times in the closure (`location ==
   '/'` branch, the kick-forward branch, and the top guard).
4. **Admissible-location sets per stage** — which locations are public,
   which gating screens get kicked forward once passed (`/intro`,
   `/sign-in`, `/sign-up`, `/parent-birth-year`, `/onboarding` →
   `/library` when complete), and which terminal routes (`/reader/:bookId`
   matched location, `/settings`, `/aac-music-demo`, `/profiles/*`) pass
   through when the journey is complete.
5. **The `'/'` AuthGate dispatch** — root is just "no location preference":
   redirect to the canonical location of the stage. The current special
   25-line `location == '/'` branch disappears as a special case.
6. **Empty/whitespace profile-id normalization** — folded into the edge
   mapping to `ProfileSelection` (§4), so the policy never sees strings.

Depth ratio: ~7 stages × ~12 locations × 2 tracks × 2 loading states of
internal decision space, exposed through 2 functions with 2 parameters
total. This is also the unit-test surface: the policy becomes a pure
table — `(snapshot, location) → expectation` — covering all of today's
**zero** tested redirect lines.

---

## 4. Dependency strategy — snapshot assembly at the edge

This is an in-process module; no service boundary. The pure core never
imports providers. Instead a single thin Riverpod adapter (hand-written,
no codegen) flattens the three reactive sources into the value type:

```dart
// lib/src/routing/journey_snapshot_provider.dart  (edge — Riverpod allowed)
final journeySnapshotProvider = Provider<JourneySnapshot>((ref) {
  final auth = ref.watch(authViewStateProvider);          // AuthViewState
  final review = ref.watch(appReviewFlowProvider);         // AppReviewFlowState
  final selection = ref.watch(activeChildProfileIdStateProvider); // AsyncValue<String?>

  return JourneySnapshot(
    reviewFlowReady: review.isReady,
    hasSupabaseSession: auth.isAuthenticated,
    hasReviewBypass: review.hasReviewBypass,
    hasParentBirthYear: review.hasParentBirthYear,
    hasCompletedReviewOnboarding: review.hasCompletedOnboarding,
    profileSelection: switch (selection) {
      AsyncData(:final value) when (value?.trim().isNotEmpty ?? false) =>
        ProfileSelection.selected,
      AsyncData() => ProfileSelection.none,
      _ => ProfileSelection.loading, // loading AND error both mean "stay put"
    },
  );
});
```

Properties of this strategy:

- **One adapter, one direction.** Supabase types (`Session`),
  `AsyncValue`, and `ChangeNotifier`s are dissolved here; only plain
  booleans and an enum cross into the core. The core compiles in a
  `dart test` VM with zero Flutter deps.
- **Change-detection stays where it is.** The router's existing
  `refreshListenable: Listenable.merge([...])` is untouched; the snapshot
  provider is read (not watched) inside the redirect, so the router
  object itself never rebuilds on state churn.
- **Screens use the same edge.** `ref.read(journeySnapshotProvider)` at
  the moment of navigation — fresh by construction because the upstream
  notifiers update their state synchronously before notifying.
- **`AsyncError` is a policy decision made at the edge**: mapped to
  `loading` (stay put) to preserve today's behavior (`hasValue == false`).
  If we later want an error stage, only the adapter changes.

---

## 5. Trade-offs of the minimal approach

**What we win**

- *Deep module, tiny surface:* 2 functions to learn, mock, and test. The
  redirect closure drops from ~100 lines to 3; the journey order leaves
  7 screens.
- *Testability:* pure sync `(value, string) → string?` — exhaustive
  table-driven tests with no ProviderContainer, no widgets, no fakes.
- *Change-resilience:* inserting a journey step touches exactly one file
  (the policy) — no screen, no router edits.
- *Unrepresentable illegal states:* `ProfileSelection` enum kills the
  `hasLoaded && hasActive` boolean pair drift.

**What we pay**

1. **`nextLocation` is opinionated.** It returns *one* canonical location
   per stage. A screen that wants a non-canonical legal destination
   (e.g. `add_child_screen`'s back-link to `/profiles/select` while in
   `profilePicker` stage) can't ask the policy "is X allowed?" — that
   query doesn't fit the 2-entry-point budget. Such lateral hops stay
   hardcoded in screens, guarded by `redirect`. Acceptable: they are UI
   layout decisions, not journey policy. (Design B will likely expose an
   `isAllowed(snapshot, location)` — that's the flexibility trade.)
2. **No explanation channel.** `redirect` says *where*, never *why*. If
   product later wants "you were redirected because…" messaging or
   analytics on journey blocks, the interface must grow (return a small
   result object instead of `String?`) — a breaking change to both entry
   points, though a mechanical one.
3. **Stale-snapshot foot-gun on the screen side.** `nextLocation` is only
   as fresh as the snapshot passed in. Reading *before* an await that
   mutates journey state gives yesterday's answer. Mitigation: convention
   of `ref.read(journeySnapshotProvider)` inline at the `context.go` call
   site (as in §2b), and the router redirect as the safety net — a stale
   `go` target gets re-redirected immediately, so the failure mode is a
   flicker, not a wrong screen.
4. **The snapshot is journey-shaped, not domain-shaped.** Six booleans/
   enums chosen specifically for this policy. New policy inputs (e.g.
   subscription state) mean touching snapshot + adapter + policy. That's
   the cost of keeping the core dependency-free; it's three edits in two
   files, all in `lib/src/routing/journey/`.
5. **Route strings are owned by the policy.** The policy returns
   `'/parent-birth-year'` etc., so route path literals live in two places
   (policy + GoRoute table). Mitigation: a private `_Routes` constants
   class inside the journey folder that `app_router.dart` also imports —
   constants are not an entry point.

**Risk assessment:** Low. The module is a pure refactor target with
identical observable behavior; the table tests can be written *first*
against the current closure's behavior (golden-master style), then the
closure swapped. No migration ordering constraints — screens can adopt
`nextLocation` incrementally while the redirect guard keeps them honest.
