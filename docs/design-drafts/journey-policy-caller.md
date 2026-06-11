# Design C: Journey Policy Optimized for the Most Common Caller

**Author:** frontend (Design C of 3)
**Status:** Draft — design document only, no code changes
**Module:** `lib/src/routing/journey/` (proposed; nothing created yet)

---

## 0. The caller census (what we're optimizing for)

There are exactly **18 navigation call sites** across the 7 journey screens
(16 `context.go(...)` + 2 `context.push(...)`). Audited and classified:

| # | Pattern | Sites | Today | Frequency |
|---|---------|-------|-------|-----------|
| 1 | **Success-forward** — "I finished my step, take me onward" | `sign_up_screen.dart:180` → `/parent-birth-year` · `parent_birth_year_screen.dart:447` → `/onboarding` · `review_onboarding_screen.dart:175` → `/library` · `profile_picker_screen.dart:63` → `/library` · `add_child_screen.dart:398` → `/library` | hardcoded next-route string, preceded by an `if (!mounted) return;` guard | **5 sites** |
| 2 | **Reactive auto-advance** — `ref.listen(authViewStateProvider, ...)` that re-implements the redirect by hand | `sign_up_screen.dart:43` · `sign_in_screen.dart:60` (both: "if now authenticated and still on an auth screen, go `/library`") | duplicated 8-line listener per screen, duplicating redirect logic | **2 sites** |
| 3 | **Back-exit** — "leave this step toward its static parent" | `sign_up_screen.dart:53` → `/intro` · `sign_in_screen.dart:70` → `/intro` · `add_child_screen.dart:71` → `/profiles/select` | hardcoded parent route | **3 sites** |
| 4 | **Start-over** — "abandon the review flow entirely" | `parent_birth_year_screen.dart:467` · `review_onboarding_screen.dart:195` (both: `clearReviewFlow()` then `/sign-in`) | identical 5-line `_startOver` method copy-pasted in two screens | **2 sites** |
| 5 | **Lateral auth switch** — peer choice between sign-in/sign-up | `sign_up_screen.dart:67` → `/sign-in` · `sign_in_screen.dart:84` → `/sign-up` · `intro_screen.dart:280` → `/sign-up` · `intro_screen.dart:288` → `/sign-in` | hardcoded route literal | **4 sites** |
| 6 | **Detour push** — sub-flow on the nav stack | `profile_picker_screen.dart:149` · `:324` → push `/profiles/new` | hardcoded push | **2 sites** |

**The key observation:** in pattern 1 — the most common *dynamic* pattern — the
destination is not actually the screen's decision. "After sign-up bypass comes
birth-year" is journey policy, currently smeared across 5 screens as string
literals that must be kept consistent with the 100-line redirect closure by
hand. Pattern 2 is the same policy re-implemented a *third* time, reactively.

This design makes pattern 1 a single call — `continueJourney(ref, context)` —
that asks the policy "what's next?", with the router redirect as the
enforcement backstop. Every other pattern also becomes a one-liner. Pattern 2
**is deleted outright** (the backstop already covers it — see §2.3).

Net effect on call sites: 18 sites → 16 one-liners + 2 deletions, **zero route
string literals left in any screen**.

---

## 1. Interface signatures

### 1.1 Layer 1 — pure decision core

File: `lib/src/routing/journey/journey_policy.dart` (+ `journey_snapshot.dart`)

Pure Dart. **No imports** of Riverpod, go_router, Flutter, or Supabase.
Table-testable with `package:test` alone.

```dart
// ── journey_snapshot.dart ────────────────────────────────────────────────

/// How far child-profile selection has progressed.
/// Collapses AsyncValue<String?> into the only three facts policy cares about.
enum ProfileSelection { loading, none, active }

/// Plain immutable projection of everything the journey policy needs.
/// No Session, no AsyncValue, no notifiers — just booleans and one enum.
@immutable // from package:meta, not Flutter
class JourneySnapshot {
  const JourneySnapshot({
    required this.isReady,                // appReviewState.isReady
    required this.isAuthenticated,        // backend Supabase session exists
    required this.hasReviewBypass,        // App Review bypass active
    required this.hasParentBirthYear,
    required this.hasCompletedOnboarding,
    required this.profileSelection,
  });

  final bool isReady;
  final bool isAuthenticated;
  final bool hasReviewBypass;
  final bool hasParentBirthYear;
  final bool hasCompletedOnboarding;
  final ProfileSelection profileSelection;

  // Derived facts (mirror the locals of today's redirect closure):
  bool get isSignedIn => isAuthenticated || hasReviewBypass;
  bool get needsParentBirthYear => hasReviewBypass && !hasParentBirthYear;
  bool get needsReviewOnboarding =>
      hasReviewBypass && hasParentBirthYear && !hasCompletedOnboarding;
  /// Only backend-auth accounts require a real child profile.
  bool get requiresBackendProfile => isAuthenticated;
  bool get needsProfileSelection =>
      requiresBackendProfile && profileSelection == ProfileSelection.none;
  bool get profileSelectionPending =>
      requiresBackendProfile && profileSelection == ProfileSelection.loading;
}

// ── journey_policy.dart ──────────────────────────────────────────────────

/// Single home for every route path string. Screens import nothing else.
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
  static String reader(String bookId) => '/reader/$bookId';
}

abstract final class JourneyPolicy {
  /// THE core question, asked by the most common caller:
  /// "given this snapshot, where should the user be?"
  ///
  /// Returns the canonical next waypoint. While profile selection is still
  /// loading, returns JourneyRoutes.root (the AuthGate splash) — the redirect
  /// backstop holds there and re-resolves when data lands.
  static String nextWaypoint(JourneySnapshot s) {
    if (!s.isSignedIn) return JourneyRoutes.intro;
    if (s.needsParentBirthYear) return JourneyRoutes.parentBirthYear;
    if (s.needsReviewOnboarding) return JourneyRoutes.onboarding;
    if (s.profileSelectionPending) return JourneyRoutes.root; // hold at gate
    if (s.needsProfileSelection) return JourneyRoutes.profilePicker;
    return JourneyRoutes.library;
  }

  /// The enforcement backstop: the entire go_router redirect, as a pure
  /// sync function. Returns null = stay put. Replaces the 100-line closure.
  static String? redirect(JourneySnapshot s, String location);

  /// Static back edge for a journey step (pattern 3). Pure lookup table.
  static String backTarget(String location);
  //   '/sign-in'      → '/intro'
  //   '/sign-up'      → '/intro'
  //   '/profiles/new' → '/profiles/select'
  //   anything else   → '/'   (defensive: root re-resolves via redirect)

  /// Where "start over" lands (pattern 4).
  static const restartTarget = JourneyRoutes.signIn;
}
```

`redirect` is `nextWaypoint` plus a route-classification table — the only
extra knowledge it needs is *which locations are acceptable to remain on* for
a given journey stage:

```dart
// Internal route classification (private to journey_policy.dart):
//
//   _public    = {/, /intro, /sign-in, /sign-up}     reachable signed-out
//   _gates     = {/parent-birth-year, /onboarding}    review-flow steps
//   _profiles  = {/profiles/select, /profiles/new}    profile steps
//   _terminal  = /settings, /aac-music-demo, and any  pass through when the
//                location starting with '/reader/'    journey is complete
//
// redirect algorithm (sync, total, no I/O):
//   1. !s.isReady                        → null (splash hold, matches today)
//   2. next = nextWaypoint(s)
//   3. next == root (selection loading)  → null (hold wherever we are)
//   4. location "satisfies" next         → null
//      - location == next
//      - next == library  && location is _terminal or _profiles  (terminal
//        pass-through; picker/add stay reachable for profile switching)
//      - next == profilePicker && location == addProfile (detour allowed)
//   5. otherwise                         → next
```

Step 4's "satisfies" table is the entire subtlety of the old closure, made
explicit and enumerable. A table test is one `(snapshot, location, expected)`
tuple per row — no ProviderContainer, no widgets, no pumping.

### 1.2 Layer 2 — ergonomic wrapper (the screen-facing API)

File: `lib/src/routing/journey/journey_actions.dart`

MAY use Riverpod + BuildContext + go_router (screens live there). Riverpod 2.6
hand-written providers, no codegen. **Five one-liners — one per surviving
caller pattern — plus one snapshot provider.**

```dart
/// Sync projection of the three state sources into the pure snapshot.
/// This is the ONLY place provider types are translated into plain data.
final journeySnapshotProvider = Provider<JourneySnapshot>((ref) {
  final auth = ref.watch(authViewStateProvider);
  final review = ref.watch(appReviewFlowProvider);
  final selection = ref.watch(activeChildProfileIdStateProvider);
  return JourneySnapshot(
    isReady: review.isReady,
    isAuthenticated: auth.isAuthenticated,
    hasReviewBypass: review.hasReviewBypass,
    hasParentBirthYear: review.hasParentBirthYear,
    hasCompletedOnboarding: review.hasCompletedOnboarding,
    profileSelection: switch (selection) {
      AsyncData(:final value) =>
        (value?.trim().isNotEmpty ?? false)
            ? ProfileSelection.active
            : ProfileSelection.none,
      _ => ProfileSelection.loading,
    },
  );
});

// ── The one-liners ───────────────────────────────────────────────────────

/// PATTERN 1 (5 sites). Call after this screen's step succeeded.
/// Reads the *current* snapshot and goes to whatever the policy says is next.
/// Includes the mounted guard the 5 call sites all hand-roll today.
void continueJourney(WidgetRef ref, BuildContext context) {
  if (!context.mounted) return;
  context.go(JourneyPolicy.nextWaypoint(ref.read(journeySnapshotProvider)));
}

/// PATTERN 3 (3 sites). Back-exit to this step's static parent.
void backOutOfJourneyStep(BuildContext context) {
  context.go(JourneyPolicy.backTarget(
      GoRouterState.of(context).matchedLocation));
}

/// PATTERN 4 (2 sites). Abandon the review flow. Absorbs the side effect
/// (clearReviewFlow) + mounted guard + destination that both _startOver
/// methods currently copy-paste.
Future<void> restartJourney(WidgetRef ref, BuildContext context) async {
  await ref.read(appReviewFlowNotifierProvider).clearReviewFlow();
  if (!context.mounted) return;
  context.go(JourneyPolicy.restartTarget);
}

/// PATTERN 5 (4 sites). Lateral switch between auth entry modes.
enum AuthEntry { signIn, signUp }
void enterAuth(BuildContext context, AuthEntry mode) {
  context.go(mode == AuthEntry.signIn
      ? JourneyRoutes.signIn
      : JourneyRoutes.signUp);
}

/// PATTERN 6 (2 sites). Detour onto the add-profile sub-flow (stacked).
void pushAddProfile(BuildContext context) {
  context.push(JourneyRoutes.addProfile);
}
```

**Pattern 2 has no one-liner because it ceases to exist.** The two
`ref.listen(authViewStateProvider, …)` blocks in sign_up/sign_in are a manual
re-implementation of the redirect: `authStateNotifierProvider` is already in
the router's `refreshListenable`, so when auth flips, the redirect backstop
fires and `JourneyPolicy.redirect` moves the user off the auth screen to the
correct waypoint (which today's listeners get *wrong*, incidentally — they
hardcode `/library`, skipping the profile-picker gate; the redirect then
corrects them, causing a double hop. Deleting them removes the bug.)

---

## 2. Usage examples

### 2.1 New `app_router.dart` redirect closure (the backstop)

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch ONLY the notifiers (stable Listenable identities for merge);
  // the snapshot is read fresh inside the redirect at evaluation time.
  final refresh = Listenable.merge([
    ref.watch(authStateNotifierProvider),
    ref.watch(appReviewFlowNotifierProvider),
    ref.watch(childProfileRouterRefreshProvider),
  ]);

  return GoRouter(
    initialLocation: JourneyRoutes.root,
    refreshListenable: refresh,
    redirect: (context, state) => JourneyPolicy.redirect(
      ref.read(journeySnapshotProvider),   // sync read — constraint (1) holds
      state.matchedLocation,
    ),
    routes: [ /* unchanged */ ],
  );
});
```

100 lines of inline branching → 4 lines. `ref.read` (not `watch`) inside the
closure guarantees the snapshot is current at every redirect evaluation and
avoids rebuilding the GoRouter itself when state changes — `refreshListenable`
is what triggers re-evaluation, exactly as today.

### 2.2 `sign_up_screen.dart` success path (pattern 1)

```dart
// BEFORE (line ~170-180):
await ref.read(appReviewFlowNotifierProvider)
    .enableReviewBypass(email: email);
if (!mounted) return;
context.go('/parent-birth-year');     // screen guesses the next step

// AFTER:
await ref.read(appReviewFlowNotifierProvider)
    .enableReviewBypass(email: email);
continueJourney(ref, context);        // policy decides: birth year is next
```

Why this is correct without coordination: `enableReviewBypass` synchronously
sets `hasReviewBypass = true, parentBirthYear = null` before notifying, so by
the time `continueJourney` reads the snapshot, `nextWaypoint` returns
`/parent-birth-year` — same destination, but now derived from the *same
tables the redirect enforces*. If product later inserts a step between
sign-up and birth-year, this call site doesn't change.

Also in this screen: the `ref.listen` auto-advance block (lines 35–45) is
**deleted** — backstop covers it (§1.2). `onBack: () => context.go('/intro')`
becomes `onBack: () => backOutOfJourneyStep(context)`. The "Sign in" footer
link becomes `enterAuth(context, AuthEntry.signIn)`.

### 2.3 `review_onboarding_screen.dart` back-to-sign-in (pattern 4)

```dart
// BEFORE (lines 190-196, duplicated verbatim in parent_birth_year_screen):
Future<void> _startOver() async {
  await ref.read(appReviewFlowNotifierProvider).clearReviewFlow();
  if (!mounted) return;
  context.go('/sign-in');
}

// AFTER — the entire method body is the one-liner:
Future<void> _startOver() => restartJourney(ref, context);
```

And the success path in the same screen (line 175):

```dart
// BEFORE:                              // AFTER:
if (!mounted) return;
context.go('/library');                 continueJourney(ref, context);
```

Note `continueJourney` here is *more correct* than the hardcode: a
backend-authenticated user without an active child profile gets sent to
`/profiles/select`, not `/library` — the destination today's hardcode picks
and the redirect immediately overrides (visible double navigation).

---

## 3. What complexity the module hides

From the **screens** (the common caller):

1. **Destination computation.** No screen knows what comes after it. The
   gate ordering (auth → birth year → onboarding → profile → library) lives
   in exactly one function, `nextWaypoint`, consumed by both layers.
2. **The mounted dance.** Every async success path today hand-rolls
   `if (!mounted) return;`. `continueJourney`/`restartJourney` own it.
3. **AsyncValue semantics.** Screens never see `AsyncValue<String?>`; the
   snapshot provider collapses loading/error/data into `ProfileSelection`
   (error conservatively maps to `loading` → redirect holds, no crash loop).
4. **The clearReviewFlow side effect** + its sequencing with navigation
   (pattern 4's copy-pasted method becomes library code).
5. **Reactive advancement.** Screens no longer listen to auth state to move
   themselves; the refreshListenable + backstop does it. Two 8-line listeners
   (and their latent wrong-destination bug) are deleted.
6. **Route strings.** Zero literals in screens; `JourneyRoutes` is the single
   spelling authority, so a path rename touches one file.

From the **router**: all branching. The redirect closure shrinks to a
delegation; the "satisfies" table (which locations may remain for which
stage, including terminal pass-through for `/reader/:bookId`, `/settings`,
`/aac-music-demo` when the journey is complete) is private to the core and
fully covered by table tests.

---

## 4. Dependency strategy: in-process core, snapshot assembly

**Everything is in-process; the core has zero dependencies** (pure Dart +
`package:meta`). Layering:

```
screens ──► journey_actions.dart ──► journey_policy.dart  (pure core)
                 │  (Riverpod+context)      ▲
                 ▼                          │ plain JourneySnapshot
        journeySnapshotProvider ────────────┘
                 │ watches (sync projection, no awaits)
                 ▼
   authViewStateProvider · appReviewFlowProvider · activeChildProfileIdStateProvider
```

**How snapshots are assembled:** `journeySnapshotProvider` is a hand-written
Riverpod 2.6 `Provider` (no codegen) that synchronously projects the three
existing state providers into the plain struct. It performs *no* I/O and *no*
awaiting — every upstream source already exposes a synchronous current value
(`AuthViewState`, `AppReviewFlowState`, the `AsyncValue` current state).
Asynchrony stays where it already is: in the notifiers that load
SharedPreferences/Supabase and call `notifyListeners()`. That keeps
constraint (1) honest — the redirect calls `ref.read(journeySnapshotProvider)`
and gets a fresh plain value with zero suspension points.

Two consumption modes of the same snapshot:
- **Backstop (pull):** redirect reads it on every evaluation, re-triggered by
  the merged `refreshListenable` — unchanged trigger topology from today.
- **Ergonomic (pull-at-action):** `continueJourney` reads it at the moment
  the screen finishes its step. Both modes evaluate the same `nextWaypoint`,
  so they cannot disagree; if a wrapper call ever raced a state write, the
  backstop corrects it on the next refresh tick.

**Testing:** `test/routing/journey/journey_policy_test.dart` is a flat table:

```dart
for (final (snap, location, expected) in cases) {
  test('$location / $snap → $expected', () {
    check(JourneyPolicy.redirect(snap, location)).equals(expected);
  });
}
```

No ProviderContainer, no GoRouter, no widget pumping for the decision logic.
The thin wrapper layer gets a handful of widget tests (mounted guard,
clearReviewFlow ordering); the snapshot provider gets a few
ProviderContainer-with-overrides tests.

---

## 5. Trade-offs

**Costs / risks**

- **Implicit destinations.** `continueJourney(ref, context)` doesn't say
  where it goes; a reader must consult the policy. Mitigation: `nextWaypoint`
  is a 6-line, exhaustively table-tested function — *one* place to look
  instead of today's three (call site, listener, redirect).
- **Five entry points, not one.** Design A (minimal) will likely beat this on
  surface count. We pay that to make every one of the 16 surviving call
  sites a true one-liner with no arguments to get wrong. The pattern census
  (§0) is the evidence the five verbs are real, stable categories — not
  speculative API.
- **`restartJourney` mixes a state mutation into a nav helper.** Slightly
  impure for the wrapper layer, but it replaces two identical copy-pasted
  methods; the mutation stays in the notifier, the wrapper only sequences it.
- **Backstop dependency for deleted listeners.** Deleting the two
  auto-advance listeners assumes every relevant state source is in the
  `Listenable.merge`. True today; a future state source added to the
  snapshot but not the merge would stall advancement. Mitigation: co-locate
  the merge list and the snapshot provider in the journey module with a
  comment binding them, and add a widget test for the magic-link sign-in
  auto-advance path.
- **Two evaluation moments.** Wrapper navigates eagerly, backstop verifies on
  refresh. In a race the user could see one corrected hop — but that's
  strictly better than today, where patterns 1–2 *systematically* hardcode
  destinations the redirect then overrides.

**Wins**

- The most common caller (5 success-forward sites) drops from ~4 lines +
  a policy guess each to one argument-free-ish call that cannot drift from
  the redirect, because both consult the same pure function.
- 2 call sites and a latent double-navigation bug deleted outright.
- The 100-line untested closure becomes a pure, table-testable function with
  an enumerable "satisfies" matrix — terminal-route pass-through included.
- Zero route string literals in feature code.
- New journey step = edit `nextWaypoint` + the satisfies table + add table
  rows. No screen changes for downstream steps.

**Comparison hooks for the bake-off:** vs Design A (minimal surface): we
trade 5 verbs for zero per-call-site thinking; vs Design B (flexible): we
trade extensibility machinery for the smallest possible diff at the 18 sites
that actually exist.
