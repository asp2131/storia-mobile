# PR 0 — Foundation: storiaActs helper + cue bump

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the shared reduced-motion guard and bump `cue` to ^0.2.2 so every subsequent PR has the helper ready and the new Cue API surface (`showCueDialog`, `CueDialogRoute`, `CueModalTransition`, `CuePageController`, `Cue.indexed`, `CardActor`, `PositionedActor.keyframed`) is available. No animation call sites are touched in this PR.

**Architecture:** One new utility file `lib/src/core/utils/storia_cue_acts.dart` exports a free function `storiaActs(context, all:, reduced:)` and a `storiaReducedEntrance` const. Every `acts:` argument in every `Cue.*` call in later PRs routes through this function. The function consults `MediaQuery.disableAnimationsOf` and returns either `all` or `reduced ?? const [.fadeIn()]`. `cue` version is bumped 0.2.1 → 0.2.2 in `pubspec.yaml`; `pubspec.lock` updated via `flutter pub get`. `AGENTS.md` animation-dep list is updated to note `flutter_animate` is going away (it's still installed and used by `page_renderer.dart` until PR 7).

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2, `package:flutter_test`.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "Shared helper" and "PR 0 — Foundation").

---

### Task 1: Scaffold the utils directory and write the failing test for `storiaActs`

**Files:**
- Create: `test/core/utils/storia_cue_acts_test.dart`
- Verify the parent directory `test/core/utils/` exists (create it).

- [ ] **Step 1: Confirm the directory structure**

Run: `ls test/core/ 2>/dev/null; mkdir -p test/core/utils`
Expected: `test/core/utils/` directory now exists (whether or not `test/core/` existed before).

- [ ] **Step 2: Write the failing test**

Paste into `test/core/utils/storia_cue_acts_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_mobile/src/core/utils/storia_cue_acts.dart';

Widget _harness({required bool disableAnimations, Widget? child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(800, 600),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: child ?? const SizedBox.shrink()),
    ),
  );
}

void main() {
  group('storiaActs', () {
    testWidgets(
      'returns the full acts list when animations are not disabled',
      (tester) async {
        List<Act>? captured;
        await tester.pumpWidget(
          _harness(
            disableAnimations: false,
            child: Builder(
              builder: (context) {
                captured = storiaActs(
                  context,
                  all: const [.fadeIn(), .slideY(from: 0.12)],
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(captured, isNotNull);
        expect(captured!.length, 2);
      },
    );

    testWidgets(
      'falls back to a single fadeIn under reduced motion',
      (tester) async {
        List<Act>? captured;
        await tester.pumpWidget(
          _harness(
            disableAnimations: true,
            child: Builder(
              builder: (context) {
                captured = storiaActs(
                  context,
                  all: const [.fadeIn(), .slideY(from: 0.12), .scale(from: 0.95)],
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(captured, isNotNull);
        expect(captured!.length, 1);
      },
    );

    testWidgets(
      'honors a custom reduced list when provided',
      (tester) async {
        List<Act>? captured;
        await tester.pumpWidget(
          _harness(
            disableAnimations: true,
            child: Builder(
              builder: (context) {
                captured = storiaActs(
                  context,
                  all: const [.fadeIn(), .slideY(from: 0.12)],
                  reduced: const [.fadeIn(), .slideY(from: 0.06)],
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(captured, isNotNull);
        expect(captured!.length, 2);
      },
    );

    test('storiaReducedEntrance is a const list of two acts', () {
      expect(storiaReducedEntrance, isA<List<Act>>());
      expect(storiaReducedEntrance.length, 2);
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/core/utils/storia_cue_acts_test.dart`
Expected: FAIL with a compilation error — `storia_cue_acts.dart` does not exist / `storiaActs` undefined.

---

### Task 2: Create `storia_cue_acts.dart` and make the test pass

**Files:**
- Create: `lib/src/core/utils/storia_cue_acts.dart`
- Create parent directory `lib/src/core/utils/` if missing.

- [ ] **Step 1: Scaffold the directory**

Run: `mkdir -p lib/src/core/utils`
Expected: directory created.

- [ ] **Step 2: Write the helper implementation**

Paste into `lib/src/core/utils/storia_cue_acts.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

/// Returns [all] animations, or a reduced-motion fallback when the platform
/// requests reduced animations.
///
/// Defaults to a plain `.fadeIn()` under reduced motion (matches the existing
/// guard in `reader_activity_card.dart`). Pass [reduced] to override the
/// fallback shape per call site.
///
/// Use at every `acts:` argument in the app:
/// ```dart
/// Cue.onMount(
///   motion: .smooth(),
///   acts: storiaActs(context, all: const [.fadeIn(), .slideY(from: 0.12)]),
///   child: child,
/// )
/// ```
List<Act> storiaActs(
  BuildContext context, {
  required List<Act> all,
  List<Act>? reduced,
}) {
  return MediaQuery.disableAnimationsOf(context)
      ? (reduced ?? const [.fadeIn()])
      : all;
}

/// Reduced-motion entrance: gentle fade plus a 0.06 slide so the motion still
/// reads but doesn't travel. Pass as [storiaActs]'s `reduced:` argument where
/// the full entrance slides further (e.g. `from: 0.12+`).
const List<Act> storiaReducedEntrance = [
  .fadeIn(),
  .slideY(from: 0.06),
];
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/core/utils/storia_cue_acts_test.dart`
Expected: PASS — 4 tests, 0 failures.

---

### Task 3: Bump `cue` to ^0.2.2 in `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml` line 62 (`cue: ^0.2.1` → `cue: ^0.2.2`)

- [ ] **Step 1: Edit the dep line**

In `pubspec.yaml`, change:

```yaml
  cue: ^0.2.1
```

to:

```yaml
  cue: ^0.2.2
```

- [ ] **Step 2: Run pub get**

Run: `flutter pub get`
Expected: resolves; `pubspec.lock` `cue:` entry now shows `version: 0.2.2` (or higher within ^0.2.2). No conflicts reported.

- [ ] **Step 3: Confirm cue 0.2.2 carries the new API surface**

Run this quick check by inspecting the resolved package:

```bash
grep -l "showCueDialog\|CueDialogRoute" ~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/
```

Expected: at least one file pathlists (e.g. `cue_modals.dart`).

```bash
grep -l "CuePageController" ~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/
```

Expected: at least one file path (e.g. `cue_indexed.dart` or `cue_page_controller.dart`).

If either returns nothing, STOP — the local cache version does not have the required API; investigate before continuing.

- [ ] **Step 4: Verify analyze is still clean**

Run: `flutter analyze`
Expected: "No issues found!" or zero warnings. The repo gate is zero warnings per AGENTS.md.

---

### Task 4: Update `AGENTS.md` to note the consolidation direction

**Files:**
- Modify: `AGENTS.md` line 64 (Animation bullet)

- [ ] **Step 1: Read the current line**

Run: `awk 'NR==64' AGENTS.md`
Expected output: `- **Animation**: `flutter_animate`, `rive`, `gooey`, `cue`, `confetti`.`

- [ ] **Step 2: Edit the line**

Change the bullet to reflect that `cue` is now the canonical animation library and `flutter_animate` is being retired:

```
- **Animation**: `cue` (canonical; see `lib/src/core/utils/storia_cue_acts.dart` for the reduced-motion guard every `Cue.*` call site must use), `rive`, `gooey`, `confetti`. `flutter_animate` is being retired in favor of `cue` — do not add new `flutter_animate` call sites.
```

- [ ] **Step 3: Verify the file still parses cleanly**

Run: `flutter analyze`
Expected: zero warnings (AGENTS.md is not analyzed, but run the gate anyway to confirm no edits leaked into other files).

---

### Task 5: Confirm the PR scope — nothing else touched

**Files:**
- Verify the git status is clean outside the intended changes.

- [ ] **Step 1: List changed files**

Run: `git status`
Expected changes only:
- `lib/src/core/utils/storia_cue_acts.dart` (new)
- `test/core/utils/storia_cue_acts_test.dart` (new)
- `pubspec.yaml`
- `pubspec.lock`
- `AGENTS.md`

If anything else shows, investigate before committing — this PR must not touch any animation call sites.

- [ ] **Step 2: Run the full test gate**

Run: `flutter test`
Expected: all existing tests pass + the 4 new `storia_cue_acts_test.dart` tests pass.

---

### Task 6: Capture the Playwright proof and commit

**Files:**
- Record: `recordings/pr0-foundation-proof.webm`
- Commit on a new branch `cue-pr0-foundation`.

- [ ] **Step 1: Capture a short intro-screen proof**

This PR has no UI-visible behavior change (no animation call sites touched). The proof records that the app still boots and renders after the cue version bump + helper introduction.

```bash
flutter run -d chrome &     # leave running on default port
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Journey: Start your journey -> app-review@storia.kids -> parent birth year 1980 -> onboarding -> library
playwright-cli video-stop --filename=recordings/pr0-foundation-proof.webm
playwright-cli close
```

The WebM is the AGENTS.md App Review proof that nothing visibly regressed.

- [ ] **Step 2: Stage the change set**

Run:
```bash
git add lib/src/core/utils/storia_cue_acts.dart \
        test/core/utils/storia_cue_acts_test.dart \
        pubspec.yaml pubspec.lock AGENTS.md \
        recordings/pr0-foundation-proof.webm
```

- [ ] **Step 3: Commit**

Run:
```bash
git commit -m "feat(cue): add storiaActs reduced-motion guard and bump cue to ^0.2.2

Foundation for the cue consolidation. The helper routes every Cue acts:
argument through MediaQuery.disableAnimationsOf and returns either the
caller-provided full acts list or a reduced fallback (defaults to a plain
.fadeIn()). storiaReducedEntrance is a fade+0.06-slide const supplied for
entrance call sites whose full motion travels further.

cue 0.2.2 unlocks the API surface used by later PRs: showCueDialog,
CueDialogRoute, CueModalTransition, CuePageController, Cue.indexed,
CardActor, PositionedActor.keyframed. No animation call sites are modified
in this PR; flutter_animate remains installed pending PR 7.

Plan: docs/superpowers/specs/2026-06-22-cue-consolidation-design.md (PR 0).
Proof: recordings/pr0-foundation-proof.webm"
```

Expected: commit succeeds; pre-commit hooks pass the analyze gate.

---

## Self-Review

- **Spec coverage:** `storiaActs` helper + `storiaReducedEntrance` (Task 2) — matches spec section "Shared helper". cue bump to ^0.2.2 (Task 3) — matches spec section "Net dep change". `AGENTS.md` update (Task 4) — matches spec line "AGENTS.md:64 update". No animation call site touched — matches spec "Out of scope for PR 0".
- **Placeholder scan:** None found.
- **Type consistency:** `storiaActs(BuildContext, {required List<Act> all, List<Act>? reduced}) → List<Act>` and `storiaReducedEntrance: List<Act>` match the spec. The test asserts both.
- **Verification gate:** Every Task ends with a `flutter test` or `flutter analyze` step. PR ends with full `flutter test` (Task 5 Step 2) and a Playwright proof (Task 6 Step 1).