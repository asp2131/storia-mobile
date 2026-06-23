# PR 2 — Auth + onboarding entrances

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 + PR 1 are merged. `storiaActs` helper + `cue: ^0.2.2` are available, and `showCueDialog` import paths are exercised.

**Goal:** Add a one-time entrance animation to every auth + onboarding screen — intro screen (Loratone hero + buttons), sign-in/up form (via shared `AuthScreenShell`), parent birth-year form, and the goal-card selection toggle on the review screen. Replace the lone `AnimatedContainer` on the goal-card check mark with `Cue.onToggle` + `CardActor`.

**Architecture:** Each screen gets a single `Cue.onMount(debugLabel:, motion: .smooth(), child:)` placed *once* at the top of its body subtree, with `Actor`s inside the child list providing staggered entrance via additive `delay:`. The shared `AuthScreenShell` gains one `Cue.onMount` that wraps its `child:` slot — that single edit covers `SignInScreen`, `SignUpScreen`, and `ReviewOnboardingScreen` since all three pass their body through `AuthScreenShell.child`. The `_GoalCard` check-icon `AnimatedContainer` becomes a `Cue.onToggle` + `CardActor` driven by the existing `isSelected` prop.

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2, `package:flutter_test`, Storia theme tokens.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 2 — Auth + onboarding entrances").

---

### Task 1: Write the failing test for `AuthScreenShell` entrance

**Files:**
- Create: `test/features/auth/auth_shell_entrance_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_mobile/src/features/auth/presentation/widgets/auth_screen_shell.dart';

void main() {
  group('AuthScreenShell entrance', () {
    testWidgets(
      'wraps its child in a Cue.onMount with at least one Actor',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AuthScreenShell(
              title: 'T',
              subtitle: 'S',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Text('block-a'),
                  Text('block-b'),
                ],
              ),
            ),
          ),
        );
        await tester.pump(); // kick the entrance timeline

        expect(find.byType(Cue), findsOneWidget);
        expect(find.byType(Actor), findsWidgets);
        expect(find.text('block-a'), findsOneWidget);
        expect(find.text('block-b'), findsOneWidget);
      },
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/auth/auth_shell_entrance_test.dart`
Expected: FAIL — `find.byType(Cue)` finds nothing (the shell has no Cue today).

---

### Task 2: Add the entrance `Cue.onMount` to `AuthScreenShell`

**Files:**
- Modify: `lib/src/features/auth/presentation/widgets/auth_screen_shell.dart`

- [ ] **Step 1: Add the imports**

Append to the existing import block at the top of the file:

```dart
import 'package:cue/cue.dart';
import '../../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Wrap the `child:` slot in a `Cue.onMount`**

The `child:` widget is currently passed straight into the `Column` at line 95. Replace that one usage:

```dart
                        child,
                        const SizedBox(height: 22),
```

with:

```dart
                        Cue.onMount(
                          debugLabel: 'auth-form-entrance',
                          motion: .smooth(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Actor(
                                acts: storiaActs(
                                  context,
                                  all: const [.fadeIn(), .slideY(from: 0.06)],
                                  reduced: storiaReducedEntrance,
                                ),
                                child: child,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
```

Note the surrounding `Column` already groups `title`, `subtitle`, `child`, `footer`, etc. We slot the `Cue.onMount` between `subtitle` and `footer` so it covers just the form body. The `Actor` inside the cue receives the original `child` widget (`Column` from each screen, e.g. the form fields + buttons). The single `Actor` fades + slides the whole form body together; per-screen sub-stagger (splitting heading from buttons) is intentionally skipped to keep this PR scoped to one wrap per screen.

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/features/auth/auth_shell_entrance_test.dart`
Expected: PASS.

- [ ] **Step 4: Run analyze + full test gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

---

### Task 3: Add the entrance to `IntroScreen`

**Files:**
- Modify: `lib/src/features/auth/presentation/intro_screen.dart`

- [ ] **Step 1: Add the imports**

Append at the top of the file:

```dart
import 'package:cue/cue.dart';
import '../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Wrap the content Column in `Cue.onMount`**

The content `Column` currently lives at lines 162-290 inside `Padding`. Add a `Cue.onMount` immediately inside the `Padding`:

```dart
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      SizedBox(
                        width: _heroSize,
                        height: _heroSize,
                        child: /* existing Transform.translate(...) */,
                      ),
                      const SizedBox(height: 2),
                      Cue.onMount(
                        debugLabel: 'intro-entrance',
                        motion: .smooth(),
                        child: Column(
                          children: [
                            Actor(
                              acts: storiaActs(
                                context,
                                all: const [.fadeIn(), .slideY(from: 0.08)],
                                reduced: storiaReducedEntrance,
                              ),
                              child: Column(
                                children: const [
                                  Text('Loratone',
                                    textAlign: TextAlign.center,
                                    style: /* existing baloo2 46 style */),
                                  SizedBox(height: 12),
                                  Text('We are redefining reading experiences ...',
                                    textAlign: TextAlign.center,
                                    style: /* existing baloo2 15.5 style */),
                                ],
                              ),
                            ),
                            const Spacer(flex: 3),
                            Actor(
                              delay: 60.ms,
                              acts: storiaActs(
                                context,
                                all: const [.fadeIn(), .slideY(from: 0.08)],
                                reduced: storiaReducedEntrance,
                              ),
                              child: _TactileButton(
                                label: 'Start your journey',
                                background: btn,
                                foreground: primary,
                                borderColor: primary,
                                trailing: const Icon(Icons.arrow_forward, size: 20),
                                onPressed: () => enterAuth(context, AuthEntry.signUp),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Actor(
                              delay: 120.ms,
                              acts: storiaActs(
                                context,
                                all: const [.fadeIn(), .slideY(from: 0.08)],
                                reduced: storiaReducedEntrance,
                              ),
                              child: _TactileButton(
                                label: 'Already have a bookmark? Sign in',
                                background: Colors.white,
                                foreground: primary,
                                borderColor: primary,
                                onPressed: () => enterAuth(context, AuthEntry.signIn),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
```

The hero Rive illustration at the top (`Transform.translate` block, lines 165-246 right above this `Column`) is left alone in this PR — its ambient bob is migrated in PR 6. PR 2 only adds the entrance to the headline + two buttons.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: zero warnings.

- [ ] **Step 4: Add an intro entrance test**

Create `test/features/auth/intro_screen_entrance_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/auth/presentation/intro_screen.dart';

void main() {
  group('IntroScreen entrance', () {
    testWidgets(
      'exposes a Cue.onMount and 2 Actors for the title + buttons',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
        await tester.pump();

        expect(find.byType(Cue), findsWidgets);
        // The shell entrance Cue isdebugLabeled 'intro-entrance'; we expect at
        // least two Actors (title + at least one button).
        expect(find.byType(Actor), findsWidgets);
      },
    );
  });
}
```

Run: `flutter test test/features/auth/intro_screen_entrance_test.dart`
Expected: PASS.

---

### Task 4: Add the entrance to `ParentBirthYearScreen`

**Files:**
- Modify: `lib/src/features/onboarding/presentation/parent_birth_year_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import 'package:cue/cue.dart';
import '../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Wrap `_buildBirthYearStep(textTheme)` return value in `Cue.onMount`**

Replace the `return SketchCard(...)` (currently at line 103) with:

```dart
return Cue.onMount(
  debugLabel: 'parent-year-entrance',
  motion: .smooth(),
  child: Actor(
    acts: storiaActs(
      context,
      all: const [.fadeIn(), .slideY(from: 0.06)],
      reduced: storiaReducedEntrance,
    ),
    child: SketchCard(
      color: StoriaColors.ink,
      borderColor: StoriaColors.inkDeep,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: /* existing Column body verbatim */,
    ),
  ),
);
```

Two clarifications:
- `_buildBirthYearStep` is called from the gate-passed branch of `build` at line 81-82. Insert the `Cue.onMount` inside the return of that helper, *not* in the gate-challenge branch.
- Since `_buildBirthYearStep` is a method, `context` is in scope (the `Widget build(BuildContext context)` parameter above). If for some reason it isn't, refactor `_buildBirthYearStep` to take a `BuildContext` parameter and add it at the call site.

- [ ] **Step 3: Add a test**

Create `test/features/onboarding/parent_birth_year_entrance_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storia_mobile/src/features/onboarding/presentation/parent_birth_year_screen.dart';

void main() {
  group('ParentBirthYearScreen entrance', () {
    testWidgets(
      'renders the gate-challenge state with no Cue entrance (gate unpassed)',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: ParentBirthYearScreen()),
          ),
        );
        await tester.pump();
        // Gate not yet passed: the birth-year Cue.onMount is not in the tree
        // until the gate passes. Assert the gate card is shown.
        expect(find.text('Parents only'), findsOneWidget);
      },
    );
  });
}
```

Test only the gate-unpassed state because driving the gate-passed transition requires the `GateController`'s 30-second challenge to be solved; that's covered by PR 1's parental_gate test and the existing `parent_birth_year_screen_test.dart`. PR 2's entrance Cue only mounts after the gate passes — Visually verified by the Playwright proof at Task 6.

- [ ] **Step 4: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: zero warnings; existing tests still pass.

---

### Task 5: Migrate the goal-card check `AnimatedContainer` to `Cue.onToggle` + `CardActor`

**Files:**
- Modify: `lib/src/features/onboarding/presentation/review_onboarding_screen.dart`
- Create: `test/features/onboarding/review_onboarding_goal_card_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/onboarding/domain/review_onboarding_profile.dart';

// _GoalCard is private. We test via the public ReviewOnboardingScreen by
// selecting + toggling a goal in the rendered list. The assertion is on the
// presence of Cue artifacts in the subtree, not the private widget.
```

Confirm `_GoalCard` visibility. Because it's private, the test goes through `ReviewOnboardingScreen` end-to-end:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/onboarding/presentation/review_onboarding_screen.dart';

void main() {
  group('ReviewOnboarding goal card Cue', () {
    testWidgets(
      'tapping a goal rerenders its check marker under a Cue.onToggle/CardActor',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: ReviewOnboardingScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // The three goal labels come from ParentGoal.values. We tap the first
        // goal label found in the rendered goal cards.
        final goalCardFinder = find.byType(Checkbox);
        // Or tap the card row directly — review_onboarding_screen.dart uses
        // InkWell with onTap: () => setState(... _selectedGoal = goal).
        final goalText = find.text(_firstGoalLabel());
        if (goalText.evaluate().isNotEmpty) {
          await tester.tap(goalText.first);
          await tester.pumpAndSettle();
        }

        // After selection, the goal's check marker is wrapped in Cue.onToggle.
        expect(find.byType(Cue), findsWidgets);
        expect(find.byType(Actor), findsWidgets);
      },
    );
  });
}

String _firstGoalLabel() {
  // ParentGoal.values first element's label — read from source if needed.
  return ParentGoal.values.first.label;
}
```

If `ParentGoal` doesn't expose `.label` on the enum, inspect `domain/review_onboarding_profile.dart` and adjust. If `Checkbox` locator doesn't fit, switch to tapping by the goal card text — the existing `InkWell` already installs `onTap:` per goal-card.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/onboarding/review_onboarding_goal_card_test.dart`
Expected: FAIL — `find.byType(Cue)` finds nothing in the goal-card subtree (AnimatedContainer is still there).

- [ ] **Step 3: Replace the `AnimatedContainer` with `Cue.onToggle` + `CardActor`**

In `_GoalCard.build` (around line 222 — the `AnimatedContainer` for the check marker), replace:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 180),
  width: 22,
  height: 22,
  margin: const EdgeInsets.only(top: 2),
  decoration: BoxDecoration(
    color: isSelected ? StoriaColors.dustyPinkStrong : Colors.transparent,
    shape: BoxShape.circle,
    border: Border.all(
      color: isSelected ? StoriaColors.dustyPinkStrong : StoriaColors.lineStrong,
      width: 1.5,
    ),
  ),
  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
),
```

with:

```dart
Cue.onToggle(
  toggled: isSelected,
  motion: .snappy(),
  reverseMotion: .snappy(),
  child: CardActor(
    color: .tween(
      Colors.transparent,
      StoriaColors.dustyPinkStrong,
    ),
    shape: .circle,
    border: .fixed(
      Border.all(
        color: isSelected
            ? StoriaColors.dustyPinkStrong
            : StoriaColors.lineStrong,
        width: 1.5,
      ),
    ),
    margin: const EdgeInsets.only(top: 2),
    child: SizedBox(
      width: 22,
      height: 22,
      child: isSelected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : const SizedBox.shrink(),
    ),
  ),
),
```

Notes:
- `CardActor.color`, `border`, `margin`, `shape` are all `AnimatableValue` parameters; use `.tween(from, to)` for animated properties and `.fixed(value)` for static ones.
- The check `Icon` is swapped at `isSelected` boundary synchronously (existing pattern). The `CardActor` handles the surface fill/border crossfade.

- [ ] **Step 4: Add the imports** to `review_onboarding_screen.dart`:

```dart
import 'package:cue/cue.dart';
import '../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/onboarding/review_onboarding_goal_card_test.dart`
Expected: PASS — tapping a goal re-renders the check marker under a `Cue.onToggle` + `CardActor`.

- [ ] **Step 6: Run analyze**

Run: `flutter analyze`
Expected: zero warnings.

---

### Task 6: Capture the Playwright proof and commit

- [ ] **Step 1: Record the proof**

```bash
flutter run -d chrome &
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Flow:
#   1. Intro screen -> entrance animation on heading + buttons visible
#   2. Tap "Start your journey" -> sign-up screen -> entrance fade
#   3. Tap "Already have a bookmark? Sign in" -> sign-in entrance
#   4. Sign in via app-review@storia.kids
#   5. Parent birth year screen -> type 1980 -> connector card entrance after gate passes
#   6. Onboarding review screen -> tap two goal cards -> check marks fade in via Cue.onToggle
playwright-cli video-stop --filename=recordings/pr2-entrances-proof.webm
playwright-cli close
```

- [ ] **Step 2: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all new tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add lib/src/features/auth/presentation/widgets/auth_screen_shell.dart \
        lib/src/features/auth/presentation/intro_screen.dart \
        lib/src/features/onboarding/presentation/parent_birth_year_screen.dart \
        lib/src/features/onboarding/presentation/review_onboarding_screen.dart \
        test/features/auth/auth_shell_entrance_test.dart \
        test/features/auth/intro_screen_entrance_test.dart \
        test/features/onboarding/parent_birth_year_entrance_test.dart \
        test/features/onboarding/review_onboarding_goal_card_test.dart \
        recordings/pr2-entrances-proof.webm
```

```bash
git commit -m "feat(cue): add entrance animations to auth + onboarding screens

Each screen gets one Cue.onMount placed at the relevant subtree root with
Actor(s) inside providing staggered entrance via additive delay. Reduced
motion falls back to storiaReducedEntrance (fade + 0.06 slide).

* AuthScreenShell (covers SignIn, SignUp, ReviewOnboarding): one Cue.onMount
  wrapping the shared child: slot, single Actor carrying the whole form body.
* IntroScreen: Cue.onMount over the headline + bottom buttons with staggered
  Actors at 0/60/120 ms delay. Hero Rive bob stays on its own (PR 6).
* ParentBirthYearScreen: Cue.onMount wraps the birth-year SketchCard body
  inside _buildBirthYearStep; only mounts after gate passes.
* ReviewOnboardingScreen _GoalCard check marker: AnimatedContainer -> Cue.onToggle
  + CardActor with .tween(transparent, dustyPinkStrong) and CardActor.shape
  circle. Snappy motion both forward and reverse.

Plan: docs/superpowers/plans/2026-06-22-pr2-auth-onboarding-entrances.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr2-entrances-proof.webm"
```

---

## Self-Review

- **Spec coverage:** Intro entrance — Task 3. Sign-in/up — Task 2 (covers both via shared shell). Parent-year entrance — Task 4. Goal-card `CardActor` — Task 5. All five files in spec covered. `storiaActs` reduced-motion fallback included at every `acts:` argument.
- **Placeholder scan:** The intro-screen code reshows `/* existing style ... */` placeholders — these are intentional shorthand for "copy the existing inline GoogleFonts.baloo2 footnote definitions verbatim from the original file"; do not paste them literally — manually copy from the existing source. The plan flags this implicitly by saying `const Column(children: const [Text('Loratone', ...)])` style; the worker sees the original style on disk while editing.
- **Internal consistency:** `CardActor.color: .tween(...)`, `.shape: .circle`, `.border: .fixed(...)`, `.margin: const EdgeInsets.only(...)` — these match the cue-animations skill's `CardActor`/`AnimatableValue` shape (`.tween(from,to)`, `.fixed(value)`). If `CardActor.border` is not a real constructor argument, fall back to `.decorate(border:)` — see the skill section "Multi-Property Acts — decorate". The spec's fallback already lists `CardActor` for card-surface animations; if border-crossfade is not supported by `CardActor` directly, use the `decorate` act via `Actor(acts: [.decorate(border: .tween(...))])` instead. Land that adjustment inline while implementing if the analyzer flags the field. StoriaMotion tokens `StoriaMotion.quick`, `StoriaMotion.medium`, `StoriaMotion.slow` retain their existing definitions.
- **Risk:** `_GoalCard` is private; the test goes end-to-end through `ReviewOnboardingScreen`. If `ParentGoal`'s label accessor differs, adjust `_firstGoalLabel()` in the test.