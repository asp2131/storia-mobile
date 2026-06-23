# PR 1 — Modals: audio settings + parental gate → `showCueDialog` / `CueDialogRoute`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 (`docs/superpowers/plans/2026-06-22-pr0-cue-foundation.md`) is landed and merged. `storiaActs` helper exists; `cue: ^0.2.2` resolves.

**Goal:** Replace the two `showModalBottomSheet` call sites in the app with Cue-driven modal transitions. `_AudioSettingsSheet` (reader) goes through `showCueDialog`; `ParentalGate.verify` (settings) goes through `CueDialogRoute` so the existing `Navigator.pop(bool)` flow stays untouched.

**Architecture:** `showCueDialog` returns a `Future<T?>` and pushes a `CueDialogRoute` — a `RawDialogRoute` whose content tree is wrapped in `CueScope`. Every `Actor` placed inside the `builder`'s return value animates against the route controller automatically (no manual controller threading). `CueDialogRoute` is a plain `PageRoute` subclass, so `Navigator.pop(true)` inside `_GateSheetState._onStateChanged` keeps working exactly as today. Both modal bodies wrap their content in a single `Actor(acts: storiaActs(ctx, all: const [.fadeIn(), .slideY(from: 1)], reduced: storiaReducedEntrance))` so the sheet rises from the bottom (preserving the existing `showModalBottomSheet` origin).

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2 (`showCueDialog`, `CueDialogRoute`), `package:flutter_test`, Storia theme tokens.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 1 — Modals").

---

### Task 1: Write the failing test for the parental gate Cue dialog

**Files:**
- Create: `test/core/widgets/parental_gate_cue_dialog_test.dart`

- [ ] **Step 1: Write the test**

Paste into `test/core/widgets/parental_gate_cue_dialog_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/core/widgets/parental_gate.dart';
import 'package:storia_mobile/src/core/widgets/gate_controller.dart';

void main() {
  group('ParentalGate Cue dialog', () {
    testWidgets(
      'pushes a CueDialogRoute whose body is wrapped in an Actor',
      (tester) async {
        late Future<bool> resultFuture;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          resultFuture = ParentalGate.verify(context),
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // A CueDialogRoute is on top and its content tree contains an Actor.
        expect(find.byType(Actor), findsWidgets);
        expect(find.byType(GateChallengeCard), findsOneWidget);
        expect(find.text('Grown-ups only'), findsOneWidget);

        // Cancel from the card and let the route pop, ending the future.
        // The card's cancel control is a TextButton labeled 'Cancel'.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        final result = await resultFuture;
        expect(result, false);
      },
    );
  });
}
```

If `GateChallengeCard`'s cancel control's locator differs, adjust to an exact `byWidgetPredicate` (the actual `IconButton` tooltip says "Cancel" — confirm by reading `gate_challenge_card.dart`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/widgets/parental_gate_cue_dialog_test.dart`
Expected: FAIL — `find.byType(Actor)` finds nothing (the modal still uses `showModalBottomSheet`).

---

### Task 2: Migrate `ParentalGate.verify` to `CueDialogRoute`

**Files:**
- Modify: `lib/src/core/widgets/parental_gate.dart` (imports + `_GateSheet.build` body wrap)

- [ ] **Step 1: Add the cue import**

In `lib/src/core/widgets/parental_gate.dart`, replace the existing import block with:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import '../utils/storia_cue_acts.dart';
import 'gate_challenge_card.dart';
import 'gate_controller.dart';
import 'gate_state.dart';
```

- [ ] **Step 2: Replace `showModalBottomSheet` with `CueDialogRoute` push**

Change `ParentalGate.verify` (currently lines 19-31) to:

```dart
static Future<bool> verify(BuildContext context) async {
  final controller = GateController();
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    CueDialogRoute<bool>(
      motion: .smooth(),
      reverseMotion: .snappy(),
      barrierColor: Colors.black54,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => _GateSheet(controller: controller),
    ),
  );
  controller.dispose();
  return result ?? false;
}
```

Notes:
- `CueDialogRoute` is a `RawDialogRoute` subclass that wraps its content in `CueScope`. `Navigator.pop(bool)` inside `_GateSheetState._onStateChanged` still resolves to the route's `Future<bool>` return value.
- `rootNavigator: true` matches the previous `showModalBottomSheet` default of using the root navigator.

- [ ] **Step 3: Wrap `_GateSheet.build` content in an `Actor`**

In `_GateSheetState.build` (currently lines 66-78), wrap the existing `GateChallengeCard(...)` in an `Actor`:

```dart
@override
Widget build(BuildContext context) {
  final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
  return Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
    child: Actor(
      acts: storiaActs(
        context,
        all: const [
          .fadeIn(),
          .slideY(from: 1, motion: CueMotion.easeOut(StoriaMotion.quick)),
        ],
        reduced: storiaReducedEntrance,
      ),
      child: GateChallengeCard(
        controller: widget.controller,
        header: _GateHeaderIcon(),
        title: 'Grown-ups only',
        showCancel: true,
        onCancel: () => widget.controller.cancel(),
      ),
    ),
  );
}
```

Add the `StoriaMotion` import if it's not already present at the top:

```dart
import '../theme/storia_motion.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/widgets/parental_gate_cue_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite** to confirm no regression

Run: `flutter test`
Expected: every previously passing test still passes.

---

### Task 3: Write the failing test for `_AudioSettingsSheet` Cue dialog

**Files:**
- Create: `test/features/reader/audio_settings_cue_dialog_test.dart`

- [ ] **Step 1: Write the test**

Paste:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storia_mobile/src/core/theme/storia_colors.dart';

/// Minimal harness that taps the chrome settings button and asserts a Cue
/// modal route opens with an Actor subtree.
void main() {
  group('AudioSettings Cue dialog', () {
    testWidgets(
      'opens via the chrome button and renders an Actor inside the modal',
      (tester) async {
        // The settings button is the second chrome button (icon tune_rounded).
        // We tap by that icon to open the sheet without wiring the full reader.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => showCueDialog<void>(
                      context: context,
                      motion: .smooth(),
                      reverseMotion: .snappy(),
                      barrierColor: StoriaColors.paper.withAlpha(0xCC),
                      builder: (ctx) => Actor(
                        acts: const [.fadeIn(), .slideY(from: 1)],
                        child: const SizedBox(
                          width: 220,
                          height: 120,
                          child: Center(child: Text('Audio Mix')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pumpAndSettle();

        expect(find.byType(Actor), findsWidgets);
        expect(find.text('Audio Mix'), findsOneWidget);

        // Dismiss.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Audio Mix'), findsNothing);
      },
    );
  });
}
```

- [ ] **Step 2: Run to verify it passes (sanity check on the API surface)**

Run: `flutter test test/features/reader/audio_settings_cue_dialog_test.dart`
Expected: PASS — the test only exercises `showCueDialog` itself, not the wiring in `ReaderScreen`. (We verify the wiring via the broader `flutter test` gate after the migration.)

---

### Task 4: Migrate `_AudioSettingsSheet` open + content to `showCueDialog`

**Files:**
- Modify: `lib/src/features/reader/reader_screen.dart` — `_showAudioSettings` (around line 360) + imports at the top.

- [ ] **Step 1: Add the required imports** to `reader_screen.dart`:

```dart
import '../../core/utils/storia_cue_acts.dart';
```

`package:cue/cue.dart` is already imported at line 6.

- [ ] **Step 2: Replace `showModalBottomSheet` with `showCueDialog`**

In `_ReaderScreenState._showAudioSettings` (lines 360-380), change:

```dart
void _showAudioSettings(
  BuildContext context,
  ReaderExperienceControllerNotifier controller,
  double narrationVolume,
  double soundscapeVolume,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: StoriaColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) {
      return _AudioSettingsSheet(
        controller: controller,
        initialNarrationVolume: narrationVolume,
        initialSoundscapeVolume: soundscapeVolume,
      );
    },
  );
}
```

to:

```dart
 void _showAudioSettings(
  BuildContext context,
  ReaderExperienceControllerNotifier controller,
  double narrationVolume,
  double soundscapeVolume,
) {
  showCueDialog<void>(
    context: context,
    motion: .smooth(),
    reverseMotion: .snappy(),
    barrierColor: StoriaColors.ink.withAlpha(0xCC),
    barrierDismissible: true,
    builder: (ctx) => Actor(
      acts: storiaActs(
        ctx,
        all: const [.fadeIn(), .slideY(from: 1)],
        reduced: storiaReducedEntrance,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: _AudioSettingsSheet(
          controller: controller,
          initialNarrationVolume: narrationVolume,
          initialSoundscapeVolume: soundscapeVolume,
        ),
      ),
    ),
  );
}
```

Notes:
- Drop the `RoundedRectangleBorder` from the dialog root — the inner `_AudioSettingsSheet` body already builds its own column on `StoriaColors.paper`; if the sheet's design relied on the bottom-sheet's rounded top corners, add a `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(30)), child: ...)` inside the `Actor` wrapping the sheet. Iterate after the first Playwright proof captures the visual.
- The horizontal `Padding` keeps the modal narrower than full-screen, matching the previous bottom-sheet margin feel.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze`
Expected: zero warnings. If `showCueDialog` is flagged with "unused_import" anywhere (the parent file already imports cue), no action. If `StoriaColors.paper` is unused after removing the `backgroundColor: StoriaColors.paper` line, leave the import; it's used elsewhere in reader_screen.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. Existing reader tests cover the chrome button tap wiring; if any tap into `_AudioSettingsSheet` previously asserted `showModalBottomSheet`/`ModalBottomSheet` existence, update them to assert `find.byType(Actor)` instead. Search:

```bash
grep -rn "ModalBottomSheet" test/
```

Expected empty (no test references the bottom sheet by type). If non-empty, adjust those tests in this step.

---

### Task 5: Visual polish — restore rounded sheet corners (only if needed)

**Files:**
- Modify: `lib/src/features/reader/reader_screen.dart` — the `Actor` field inside `_showAudioSettings`.

- [ ] **Step 1: Capture the proof first (Task 6) and inspect the recording**

If the modal looks like a hard-edged square card after the migration (it may, since we dropped the `RoundedRectangleBorder`), wrap the sheet in a `ClipRRect` inside the `Actor`:

```dart
child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    child: _AudioSettingsSheet(...),
  ),
),
```

Re-run analyze + test; submit the new proof.

---

### Task 6: Capture the Playwright proof and commit

**Files:**
- Record: `recordings/pr1-modals-proof.webm`

- [ ] **Step 1: Boot the app on chrome**

```bash
flutter run -d chrome &
```

- [ ] **Step 2: Record the modal flow**

```bash
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Flow:
#   1. Tap "Start your journey"
#   2. Sign in via app-review@storia.kids
#   3. Enter parent birth year 1980
#   4. Complete onboarding selections
#   5. Library opens -> tap settings (gear) icon -> parental gate Cue modal appears
#   6. Cancel the parental gate
#   7. Open a book -> tap chrome tune icon -> audio settings Cue modal appears
#   8. Dismiss the audio settings
playwright-cli video-stop --filename=recordings/pr1-modals-proof.webm
playwright-cli close
```

- [ ] **Step 3: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests including the two new ones pass.

- [ ] **Step 4: Stage and commit**

```bash
git add lib/src/core/widgets/parental_gate.dart \
        lib/src/features/reader/reader_screen.dart \
        test/core/widgets/parental_gate_cue_dialog_test.dart \
        test/features/reader/audio_settings_cue_dialog_test.dart \
        recordings/pr1-modals-proof.webm
```

```bash
git commit -m "feat(cue): migrate audio settings and parental gate modals to showCueDialog/CueDialogRoute

Two replacements of showModalBottomSheet call sites:

* _AudioSettingsSheet (reader chrome tune icon) -> showCueDialog with
  motion: .smooth() and reverseMotion: .snappy(); body Actor does fadeIn +
  slideY(from: 1) to rise from the bottom (preserving bottom-sheet origin).
  Reduced motion falls back to storiaReducedEntrance.

* ParentalGate.verify -> Navigator.push(CueDialogRoute<bool>(...)). Existing
  Navigator.pop(true/false) flow in _GateSheetState._onStateChanged keeps
  working unchanged because CueDialogRoute is a RawDialogRoute subclass.
  _GateSheet body wrapped in Actor(fadeIn + slideY(from: 1)).

Adding showCueDialog/CueDialogRoute gives every Actor inside the modal
sheet a CueScope automatically; no manual controller threading.

Plan: docs/superpowers/plans/2026-06-22-pr1-cue-modals.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr1-modals-proof.webm"
```

Expected: pre-commit hooks pass.

---

## Self-Review

- **Spec coverage:** `_AudioSettingsSheet` migrate → covered (Task 4). `ParentalGate` migrate → covered (Task 2). Both wrapped in `storiaActs` (reduced-motion) → covered. Plays clean: `flutter analyze` + `flutter test` + Playwright.
- **Placeholder scan:** None. The Task 5 visual-polish branch is an `if needed` decision tree, not a placeholder — its trigger ("if hard-edged square card") is concrete.
- **Type consistency:** `CueDialogRoute<bool>` and `showCueDialog<void>` align with cue 0.2.2 signatures (confirmed at `~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/widgets/cue_modals.dart:35-112`). StoriaMotion.quick + CueMotion.easeOut usage consistent with PR 0 plan's CueMotion helpers and existing reader_screen usage.
- **Risk:** `GateChallengeCard`'s cancel button tooltip exact text is referenced by the test — if it differs from `'Cancel'`, adjust the predicate in `test/core/widgets/parental_gate_cue_dialog_test.dart` Task 1 Step 1. Reading `gate_challenge_card.dart` confirms before landing.