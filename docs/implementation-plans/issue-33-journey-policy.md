# Implementation Plan — Issue #33: Deepen the user-journey policy

**RFC:** https://github.com/asp2131/storia-mobile/issues/33
**Design basis:** hybrid of `docs/design-drafts/journey-policy-minimal.md` (pure core) + `docs/design-drafts/journey-policy-caller.md` (action verbs)
**Invariant for every phase:** `./bin/verify.sh` green (flutter analyze zero warnings + full test suite) before moving on. Each phase is independently landable and revertable; the router redirect backstop keeps unmigrated screens correct throughout.

Pre-work (repo rules): read `.wolf/buglog.json` and `.wolf/cerebrum.md` before writing code.

---

## File layout (target)

```
lib/src/routing/journey/
  journey_policy.dart        # PURE: ProfileSelection, JourneySnapshot, JourneyRoutes,
                             #       JourneyPolicy, private _JourneyStage + tables
  journey_providers.dart     # edge: journeySnapshotProvider (Riverpod 2.6, hand-written)
  journey_actions.dart       # verbs: continueJourney, backOutOfJourneyStep,
                             #        restartJourney, enterAuth, pushAddProfile
test/routing/journey/
  journey_policy_test.dart           # golden-master truth table (redirect)
  journey_next_location_test.dart    # nextLocation per stage + self-consistency invariant
  journey_back_target_test.dart      # backTarget lookup table
  journey_snapshot_provider_test.dart# ProviderContainer projection tests
  journey_actions_test.dart          # widget tests: mounted guard, restart ordering
  auth_auto_advance_regression_test.dart  # added in Phase 4
```

No codegen anywhere. Pure core imports `package:meta` at most.

---

## Phase 1 — Pure core + golden-master truth table (no behavior change, no callers)

**Add** `lib/src/routing/journey/journey_policy.dart`:

1. `enum ProfileSelection { loading, none, selected }`
2. `class JourneySnapshot` — 6 fields, const ctor, value `==`/`hashCode`/`toString` (hand-written).
3. `abstract final class JourneyRoutes` — every path literal, incl. `reader(bookId)`.
4. Private `enum _JourneyStage { indeterminate, unauthenticated, parentBirthYear, reviewOnboarding, profileLoading, profilePicker, complete }` + `_stageOf(snapshot)`.
   - Stage precedence must replicate the **general-branch ordering** of the current closure: unauthenticated → birthYear → onboarding → profileLoading → profilePicker → complete. (The closure's `/`-branch checks profiles before onboarding; that divergence only matters for session+bypass users, which product flows never produce. Golden master encodes general-branch ordering — note this in the test file header.)
5. Private per-stage tables: `_admissibleLocations(stage)`, `_canonicalLocation(stage)`, the kick-forward set (`/intro`, `/sign-in`, `/sign-up`, `/parent-birth-year`, `/onboarding` bounce to canonical when stage == complete), `/profiles/new` detour while `profilePicker`, `/profiles/select` + `/profiles/new` remain admissible at `complete` (profile switching), terminal pass-through (`/settings`, `/aac-music-demo`, prefix `/reader/`).
6. Public: `redirect(s, location)`, `nextLocation(s)`, `backTarget(location)`, `restartTarget`.

**Add** `test/routing/journey/journey_policy_test.dart` — golden-master table derived from the current closure, **written before the implementation** of `_stageOf`. Minimum rows:

- Boot hold: `reviewFlowReady=false` → null for every location sampled.
- Unauthenticated: `/`→`/intro`; public locations pass; protected (`/library`, `/settings`, `/reader/x`, `/profiles/select`) → `/intro`.
- Bypass track: bypass w/o birthYear → everything except `/parent-birth-year` redirects there; bypass+birthYear w/o onboarding → kicked to `/onboarding`; bypass complete → auth/gate screens bounce to `/library`, terminals pass.
- Supabase track: session + profile `loading` → null everywhere (incl. `/`); session + `none` → `/profiles/select` from `/`, `/library`, `/settings`; `/profiles/new` allowed; session + `selected` → `/`→`/library`, auth screens bounce, terminals pass, `/profiles/select` still allowed.
- Dual-track (session+bypass): review steps outrank profile selection.

**Add** `journey_next_location_test.dart`: canonical location per stage **plus the invariant** — for every ready snapshot in the table, `redirect(s, nextLocation(s)) == null`.

**Add** `journey_back_target_test.dart`: `/sign-in`→`/intro`, `/sign-up`→`/intro`, `/profiles/new`→`/profiles/select`, anything else→`/`.

**Gate:** new tests pass with `flutter test test/routing/journey/`; nothing else touched.

## Phase 2 — Edge provider + router swap (first behavior-bearing change)

1. **Add** `journey_providers.dart`: `journeySnapshotProvider` exactly as specified in the RFC (AsyncValue flattened via switch; error→`loading`). Co-locate a comment binding the provider's watch list to the router's `Listenable.merge` list.
2. **Edit** `app_router.dart`: replace the 100-line closure with
   `redirect: (context, state) => JourneyPolicy.redirect(ref.read(journeySnapshotProvider), state.matchedLocation)`.
   Keep `refreshListenable: Listenable.merge([...])` byte-identical. Route table: swap path literals to `JourneyRoutes.*` constants (mechanical).
3. **Add** `journey_snapshot_provider_test.dart`: ProviderContainer with overrides — verify the three-way `ProfileSelection` mapping (data-with-id, data-empty/whitespace, loading, error) and the boolean projections.

**Gate:** `./bin/verify.sh` green. Manual smoke: `flutter run -d chrome`, walk the App Review flow (`Start your journey → app-review@storia.kids → 1980 → onboarding → library`) — identical behavior expected.

**Risk note:** this is the highest-risk diff in the plan. If any golden-master row was guessed wrong, this phase surfaces it. Land Phases 1+2 as one PR so the table and the swap review together.

## Phase 3 — Action verbs + migrate the 5 success-forward sites

1. **Add** `journey_actions.dart` with the five verbs (RFC signatures). `continueJourney` and `restartJourney` own the `context.mounted` guard; `restartJourney` sequences `clearReviewFlow()` then navigates to `JourneyPolicy.restartTarget`.
2. **Migrate success-forward sites** (state mutation must precede the call — verify each):
   - `sign_up_screen.dart:~180` (`/parent-birth-year`) → `continueJourney(ref, context)`
   - `parent_birth_year_screen.dart:~447` (`/onboarding`) → `continueJourney`
   - `review_onboarding_screen.dart:~175` (`/library`) → `continueJourney` ← **fixes double-hop #1** (authed user w/o profile now goes straight to `/profiles/select`)
   - `profile_picker_screen.dart:~63` (`/library`) → `continueJourney`
   - `add_child_screen.dart:~398` (`/library`) → `continueJourney`
3. **Add** `journey_actions_test.dart`: widget test that `continueJourney` no-ops when unmounted; test `restartJourney` calls `clearReviewFlow` before navigating (fake notifier + observer).

**Gate:** `./bin/verify.sh` green; existing screen widget tests (`add_child_screen_test.dart` etc.) untouched and passing.

## Phase 4 — Delete the auto-advance listeners (fixes double-hop #2)

1. **Delete** the `ref.listen(authViewStateProvider, …)` blocks: `sign_up_screen.dart:~35-45`, `sign_in_screen.dart:~52-62`. The redirect backstop (auth notifier already in `refreshListenable`) now owns post-auth advancement.
2. **Add** `auth_auto_advance_regression_test.dart`: pump the real `appRouterProvider` router with overridden auth/review/profile providers; start on `/sign-in`; flip auth state; assert navigation lands per policy (`/profiles/select` when no profile, `/library` when profile active) **without** any screen-side listener. This is the safety net the deletion depends on.

**Gate:** `./bin/verify.sh` green + the new regression test. Manual smoke: magic-link/OAuth sign-in path on chrome if feasible.

## Phase 5 — Migrate remaining 11 sites + literal sweep

| Site | Today | Verb |
|---|---|---|
| `sign_up_screen.dart:~53` | onBack → `/intro` | `backOutOfJourneyStep(context)` |
| `sign_in_screen.dart:~70` | onBack → `/intro` | `backOutOfJourneyStep` |
| `add_child_screen.dart:~71` | → `/profiles/select` | `backOutOfJourneyStep` |
| `parent_birth_year_screen.dart:~467` | `_startOver` | `restartJourney(ref, context)` |
| `review_onboarding_screen.dart:~195` | `_startOver` (copy-paste) | `restartJourney` |
| `sign_up_screen.dart:~67` | → `/sign-in` | `enterAuth(context, AuthEntry.signIn)` |
| `sign_in_screen.dart:~84` | → `/sign-up` | `enterAuth(…signUp)` |
| `intro_screen.dart:~280` | → `/sign-up` | `enterAuth(…signUp)` |
| `intro_screen.dart:~288` | → `/sign-in` | `enterAuth(…signIn)` |
| `profile_picker_screen.dart:~149` | push `/profiles/new` | `pushAddProfile(context)` |
| `profile_picker_screen.dart:~324` | push `/profiles/new` | `pushAddProfile` |

Then the sweep — must return empty outside `journey_policy.dart` + GoRoute table:

```bash
grep -rn "'/\(intro\|sign-in\|sign-up\|parent-birth-year\|onboarding\|profiles\|library\)'" \
  lib/src/features lib/src/core
```

(Non-journey nav like `/settings` from library chrome may remain as `JourneyRoutes.settings` references — constants, not literals.)

**Gate:** `./bin/verify.sh` green + empty sweep.

## Phase 6 — Proof + handoff

1. `./bin/verify.sh` — final full gate, zero analyzer warnings.
2. **Playwright WebM proof** (mandatory: this is browser-verifiable routing/auth/onboarding behavior). Canonical App Review flow per AGENTS.md → `recordings/<ticket-id>-proof.webm`. If a Supabase test account exists, capture a second clip of sign-in → profile-picker advancement (the deleted-listener path).
3. Append `.wolf/buglog.json` entries for the two fixed double-hop bugs (`error_message`, `root_cause`, `fix`, `tags: ["routing","go_router","journey"]`).
4. PR referencing #33; include before/after redirect-closure line counts and the call-site table above.

---

## Sequencing & sizing

| Phase | PR | Est. diff | Risk |
|---|---|---|---|
| 1+2 | PR 1 | ~450 lines core+tests, −100/+10 router | **High-leverage, highest care** — golden master is the safety mechanism |
| 3 | PR 2 | ~120 lines verbs+tests, 5 call sites | Low — backstop corrects mistakes |
| 4 | PR 3 | −20 lines, +1 regression test | Medium — depends entirely on the regression test |
| 5+6 | PR 4 | 11 mechanical call sites + sweep + proof | Low |

## Known traps

- **Stale snapshot**: verbs must be called *after* the state mutation lands in the notifier (all current sites already await first — keep it that way).
- **`GoRouterState.of(context)`** in `backOutOfJourneyStep` requires the call site be under the router — all 3 sites are; the widget test should cover the fallback (`else → '/'`).
- **Merge-list drift**: any future provider added to `journeySnapshotProvider` must also join the router's `Listenable.merge` — enforced by comment + the Phase 4 regression test.
- **Do not change** `aac_music_demo` or reader deep-link behavior; they are pass-through terminals only.
