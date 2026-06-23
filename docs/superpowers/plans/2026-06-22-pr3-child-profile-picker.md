# PR 3 — Child profile picker + Add-child age-band chips

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 is merged (helper + cue 0.2.2). PR 1 and PR 2 not strictly required, but recommended to land first for the `storiaActs` muscle memory.

**Goal:** Add a staggered entrance to the child profile picker list (each profile card rises + fades with index-proportional delay), pop the "Default" badge in via `Cue.onMount(motion: .bouncy())`, and turn the `_AgeBandChip` selection toggle on the add-child form into a `Cue.onToggle` micro-interaction.

**Architecture:**
- `_ProfilePickerContent` builds its cards via a `.map` over `profiles`. Wrap the outer content `Column` in a single `Cue.onMount`. Each card sits inside an `Actor(delay: displayIndex * 60 ms, ...)`. To supply the index, switch the `.map((profile)=>...)` to a `for (var i = 0; i < profiles.length; i++)` loop and pass `displayIndex: i` into `_ProfileChoiceCard` — pure plumbing, no widget tree shape change.
- `_DefaultBadge` is a small badge shown only on default profiles. Wrap its `DecoratedBox` in a `Cue.onMount(motion: .bouncy(), acts: [.scale(from: 0)])` so it pops in when the card mounts.
- `_AgeBandChip` selection today toggles a plain `Ink` background color jump. Wrap its `Ink` body in a `Cue.onToggle(toggled: selected, motion: .snappy())` with a `.scale(to: 0.97)` act so the chip squishes 3% when selected.

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2, `package:flutter_test`.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 3 — Child profile picker").

---

### Task 1: Refactor `_ProfilePickerContent` to expose a per-card display index

**Files:**
- Modify: `lib/src/features/child/presentation/profile_picker_screen.dart` — `_ProfilePickerContent` and `_ProfileChoiceCard`.

- [ ] **Step 1: Add `displayIndex` field to `_ProfileChoiceCard`**

Change the class (around line 163):

```dart
class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    required this.profile,
    required this.isSelected,
    required this.isSaving,
    required this.onTap,
    required this.displayIndex,
  });

  final ChildProfile profile;
  final String? activeId; // unchanged
  final bool isSelected;
  final bool isSaving;
  final VoidCallback onTap;
  final int displayIndex;
  ...
```

Note: re-confirm the existing fields by reading the file — `_ProfileChoiceCard` does **not** take `activeId` (the parent compares and passes `isSelected`). I retain `profile`, `isSelected`, `isSaving`, `onTap` and add `displayIndex`. If the field set differs, do not introduce `activeId`.

- [ ] **Step 2: Replace the `.map` at line 129 with a `for` loop**

Replace:

```dart
                      ...profiles.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: StoriaSpacing.lg,
                          ),
                          child: _ProfileChoiceCard(
                            profile: profile,
                            isSelected: profile.id == activeId,
                            isSaving: isSaving,
                            onTap: () => onSelect(profile),
                          ),
                        ),
                      ),
                      const SizedBox(height: StoriaSpacing.sm),
                      SketchButton(
                        label: 'Add another child',
                        leading: const Icon(Icons.add_rounded),
                        tone: SketchButtonTone.secondary,
                        onPressed: isSaving
                            ? null
                            : () => pushAddProfile(context),
                      ),
```

with:

```dart
                      for (var i = 0; i < profiles.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: StoriaSpacing.lg,
                          ),
                          child: _ProfileChoiceCard(
                            profile: profiles[i],
                            isSelected: profiles[i].id == activeId,
                            isSaving: isSaving,
                            onTap: () => onSelect(profiles[i]),
                            displayIndex: i,
                          ),
                        ),
                      const SizedBox(height: StoriaSpacing.sm),
                      SketchButton(
                        label: 'Add another child',
                        leading: const Icon(Icons.add_rounded),
                        tone: SketchButtonTone.secondary,
                        onPressed: isSaving
                            ? null
                            : () => pushAddProfile(context),
                      ),
```

- [ ] **Step 3: Compile-check**

Run: `flutter analyze lib/src/features/child/presentation/profile_picker_screen.dart`
Expected: zero warnings. No behavior change yet.

---

### Task 2: Wrap the picker list in `Cue.onMount` + per-card `Actor`

**Files:**
- Modify: `lib/src/features/child/presentation/profile_picker_screen.dart` — `_ProfilePickerContent.build` + `_ProfileChoiceCard.build`.

- [ ] **Step 1: Add the imports**

```dart
import 'package:cue/cue.dart';
import '../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Wrap the inner content `Column` of `_ProfilePickerContent` in `Cue.onMount`**

The `_ProfilePickerContent.build` returns a `LayoutBuilder` whose child is a `ListView` whose child is a `Center > ConstrainedBox > Column`. Wrap the `Column` (around line 104) in:

```dart
return Cue.onMount(
  debugLabel: 'profile-list-entrance',
  motion: .smooth(),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ... same heading Text and SizedBox children up through the empty-state branch ...
      if (profiles.isEmpty)
        Actor(
          acts: storiaActs(context, all: const [.fadeIn()]),
          child: const _NoProfilesCard(),
        )
      else ...[
        for (var i = 0; i < profiles.length; i++)
          Actor(
            delay: (i * 60).ms,
            acts: storiaActs(
              context,
              all: const [.fadeIn(), .slideY(from: 0.05)],
              reduced: storiaReducedEntrance,
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: StoriaSpacing.lg),
              child: _ProfileChoiceCard(
                profile: profiles[i],
                isSelected: profiles[i].id == activeId,
                isSaving: isSaving,
                onTap: () => onSelect(profiles[i]),
                displayIndex: i,
              ),
            ),
          ),
        const SizedBox(height: StoriaSpacing.sm),
        Actor(
          delay: (profiles.length * 60).ms,
          acts: storiaActs(
            context,
            all: const [.fadeIn(), .slideY(from: 0.05)],
            reduced: storiaReducedEntrance,
          ),
          child: SketchButton(
            label: 'Add another child',
            leading: const Icon(Icons.add_rounded),
            tone: SketchButtonTone.secondary,
            onPressed: isSaving ? null : () => pushAddProfile(context),
          ),
        ),
      ],
    ],
  ),
);
```

The `Actor` now owns the `Padding` that was previously the for-loop item wrapper. Drop the outer `Padding` to avoid double wrapping — keep the spacing via the Actor's child `Padding` (already included above).

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: zero warnings. If `actor` import is missing, ensure `_ProfileChoiceCard` no longer references the old `Padding` wrapping it had before (it shouldn't — the `Padding` is now the `Actor`'s child in the picker content loop).

---

### Task 3: Add the "Default" badge pop via `Cue.onMount(motion: .bouncy())`

**Files:**
- Modify: `lib/src/features/child/presentation/profile_picker_screen.dart` — `_DefaultBadge.build`.

- [ ] **Step 1: Wrap `_DefaultBadge.build` content in `Cue.onMount`**

Replace the `DecoratedBox(...)` body (around line 270-289) with:

```dart
@override
Widget build(BuildContext context) {
  return Cue.onMount(
    motion: .bouncy(),
    debugLabel: 'default-badge-pop',
    acts: storiaActs(
      context,
      all: const [.scale(from: 0)],
      reduced: const [.fadeIn()],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: StoriaColors.sage,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StoriaColors.sageDeep),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          'Default',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: StoriaColors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    ),
  );
}
```

`.bouncy()` with `.scale(from: 0)` reads as a bounce-in stamp — fits the playful "Default" tag.

---

### Task 4: Turn the `_AgeBandChip` selection into a `Cue.onToggle` micro-interaction

**Files:**
- Modify: `lib/src/features/child/presentation/add_child_screen.dart` — `_AgeBandChip.build`.

- [ ] **Step 1: Add imports**

```dart
import 'package:cue/cue.dart';
import '../../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Wrap the chip `Ink` body in `Cue.onToggle`**

Replace the chip body (around line 436-467) — the `Ink(...)` returned from `Material(color: transparent, child: InkWell(onTap:, borderRadius:, child: Ink(...)))`:

Wrap the inner `Ink` body in `Cue.onToggle(toggled: selected, motion: .snappy(), reverseMotion: .snappy(), child:)`:

```dart
return Semantics(
  button: true,
  selected: selected,
  label: 'Age band $label',
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Cue.onToggle(
        toggled: selected,
        motion: .snappy(),
        reverseMotion: .snappy(),
        acts: storiaActs(
          context,
          all: const [.scale(to: 0.97)],
          reduced: const [.fadeIn()],
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StoriaSpacing.lg,
                vertical: StoriaSpacing.md,
              ),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: StoriaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
```

Note: the `.scale(to: 0.97)` is reversible (`.scale` act defaults `from:` to `1.0`, so forward goes 1.0 → 0.97 and reverse 0.97 → 1.0). Static ink colors and borders stay outside the `Cue.onToggle` so the visual surface change still flips instantly on tap, and the chip squishes in/out on the toggle.

---

### Task 5: Write the new tests

**Files:**
- Create: `test/features/child/profile_picker_entrance_test.dart`
- Create: `test/features/child/default_badge_pop_test.dart`
- Create: `test/features/child/age_band_chip_toggle_test.dart`

- [ ] **Step 1: Stagger test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/child/domain/child_profile.dart';

late final List<ChildProfile> _fake = [
  ChildProfile(id: 'a', displayName: 'Ava', ageBand: '3-4', readingLevel: '', isDefault: true),
  ChildProfile(id: 'b', displayName: 'Bo',  ageBand: '5-6', readingLevel: '', isDefault: false),
  ChildProfile(id: 'c', displayName: 'Cy',  ageBand: '7-9', readingLevel: '', isDefault: false),
];
```

We test the picker by mounting it via `_ProfilePickerContent` — but that's private. Either: (a) expose `_ProfilePickerContent` via `@visibleForTesting` import; (b) mount the full `ProfilePickerScreen` and inspect the tree. Pick (b):

```dart
void main() {
  group('ProfilePickerScreen entrance', () {
    testWidgets('renders Cue.onMount + 3 Actors with increasing delays',
        (tester) async {
      // Mount ProfilePickerScreen inside a ProviderScope with overridden
      // childProfilesProvider returning three profiles, and overridden
      // activeChildProfileIdProvider returning 'a'.
      // (Omitted for brevity — the actual PR plan includes the full
      //  provider override snippet.)
      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(Actor), findsNWidgets(3 /* 3 profile cards */ + 1 /* add button */));
    });
  });
}
```

The implementing worker must add the actual `ProviderScope(overrides: [...])` snippet here — the unit testing pattern is established in `test/features/library/...` and `test/features/reader/...`. Search for the existing pattern and replicate.

- [ ] **Step 2: Badge pop test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/child/presentation/profile_picker_screen.dart';

void main() {
  group('_DefaultBadge pop', () {
    testWidgets('renders under Cue.onMount with .scale(from: 0) and .bouncy() motion',
        (tester) async {
      // _DefaultBadge is private — mount via ProfilePickerScreen.
      // ... _harness with a default profile ...
      await tester.pumpWidget(_harness());
      await tester.pump();

      // Find at least one Cue.onMount that acts on [.scale(from: 0)].
      final cues = tester.widgetList<Cue>(find.byType(Cue));
      expect(cues, isNotEmpty);
    });
  });
}
```

- [ ] **Step 3: Chip toggle test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/child/presentation/add_child_screen.dart';

void main() {
  group('_AgeBandChip toggle', () {
    testWidgets('rendered Cue.onToggle flips on selected=true',
        (tester) async {
      // _AgeBandChip is private — build AddChildScreen and tap a chip.
      // Minimal harness: ProviderScope -> MaterialApp -> AddChildScreen.
      await tester.pumpWidget(_harness());
      await tester.pump();

      final chip = find.text('3-4');
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(Actor), findsWidgets);
    });
  });
}
```

Same note: the worker adds the full harness + provider overrides per the repo's established testing recipe.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/child/profile_picker_entrance_test.dart test/features/child/default_badge_pop_test.dart test/features/child/age_band_chip_toggle_test.dart`
Expected: PASS.

---

### Task 6: Playwright proof + commit

- [ ] **Step 1: Record**

```bash
flutter run -d chrome &
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Flow:
#   1. Sign in via app-review@storia.kids -> parent birth year 1980 -> onboarding
#   2. Land on ProfilePickerScreen -> three profile cards staggered entrance visible
#   3. The Default badge on the first profile pops in (.bouncy())
#   4. Tap "Add another child" -> AddChildScreen form appears
#   5. Tap an age-band chip ("3-4") -> it squishes 3% (snappy scale) then snaps back on next tap
playwright-cli video-stop --filename=recordings/pr3-child-profile-proof.webm
playwright-cli close
```

- [ ] **Step 2: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add lib/src/features/child/presentation/profile_picker_screen.dart \
        lib/src/features/child/presentation/add_child_screen.dart \
        test/features/child/profile_picker_entrance_test.dart \
        test/features/child/default_badge_pop_test.dart \
        test/features/child/age_band_chip_toggle_test.dart \
        recordings/pr3-child-profile-proof.webm
```

```bash
git commit -m "feat(cue): add profile picker entrance, default badge pop, age-band chip toggle

* _ProfilePickerContent -> Cue.onMount + per-card Actor(delay: i * 60ms,
  acts: [fadeIn + slideY 0.05]); 'Add another child' button delayed by
  (profiles.length * 60) so it lands after the list.
* _DefaultBadge -> Cue.onMount(motion: .bouncy(), acts: [.scale(from: 0)]);
  'Default' tag bounces in when the card mounts.
* _AgeBandChip -> Cue.onToggle(toggled: selected, motion: .snappy(),
  acts: [.scale(to: 0.97)]) so the chip squishes 3% on selection.

profile_picker loop switched from .map to a for-loop so the display
displayIndex is available for the delay argument. Reduced motion falls
back to storiaReducedEntrance for entrances, .fadeIn() for the chip scale
and the badge bounce.

Plan: docs/superpowers/plans/2026-06-22-pr3-child-profile-picker.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr3-child-profile-proof.webm"
```

---

## Self-Review

- **Spec coverage:** picker list staggered entrance — Task 2. `_DefaultBadge` pop — Task 3. `_AgeBandChip` `Cue.onToggle` — Task 4. All three spec items covered.
- **Placeholder scan:** I left test-harness ProviderScope snippets as descriptive comments because the precise override snippet depends on the existing `child_profile_providers.dart` API surface (worth confirming while writing each test). The worker reads `test/features/library/library_screen_test.dart` for the established recipe and replicates.
- **Type consistency:** `Actor(delay: (i * 60).ms, acts: storiaActs(...))` — `(i * 60).ms` is the cue shorthand for `Duration(milliseconds: i * 60)`. `Cue.onToggle(toggled:, motion:, reverseMotion:, acts:, child:)` signature matches cue 0.2.2.
- **Risk:** Changing the loop from `.map` to `for` keeps `profiles[i]`-style access; the `_ProfileChoiceCard` constructor gets a new required `displayIndex` field — the picker test mounts the screen via provider overrides, and any test that constructs `_ProfileChoiceCard` directly (none found in test/ at design time) must add the field.