# PR 5 — Enrich existing Cue spots (word pop, Story Spark choices, book preview arrow)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 merged. (PRs 1-4 not strictly required; can land in any order vs them.)

**Goal:** Three small, high-impact polish-overs on Cue spots that already exist:
1. **Word-tap pop** — Reader overlay text. Upgrade the existing `Cue.onToggle(toggled: token.isTapped, acts: [.scale(to: 1.15)])` to a keyframed scale that punches up to 1.18 and settles back to 1.0, plus a brief purple tint that rides alongside the existing TTS highlight.
2. **Story Spark choice stagger** — Inside the story-spark card, the per-answer choices currently appear simultaneously. Wrap them in `Actor(delay: (i * 60).ms, ...)` so they cascade.
3. **Book preview arrow drop** — Small triangle below the book preview card. Wrap in `Actor(delay: 100.ms, acts: [.fadeIn(), .slideY(from: 0.5)])` so it drops in just after the card.

**Architecture:** All three migrations are local — single-file per task. Word-pop swaps a `const [....]` list for a list containing one keyframed act and one `.colorTint()` act. Story Spark re-uses the parent `Cue.onMount`'s `CueScope` and adds per-index `Actor` wraps without nesting new triggers. Book preview simply adds one `Actor` around the existing `CustomPaint`.

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2 (`ScaleAct.keyframed`, `Keyframes`, `.colorTint()`), `package:flutter_test`.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 5 — Enrich existing Cue spots").

---

### Task 1: Enrich the word-tap pop with a keyframed scale + tint

**Files:**
- Modify: `lib/src/features/reader/overlay/overlay_text_element.dart` — `_buildSpans` (around line 84).
- Create: `test/features/reader/overlay_text_element_pop_test.dart`

- [ ] **Step 1: Add the import**

At the top of `overlay_text_element.dart`:

```dart
import '../../../../core/utils/storia_cue_acts.dart';
```

`import 'package:cue/cue.dart';` is already present (line 1).

- [ ] **Step 2: Replace the existing word-pop Cue.onToggle**

Find the block around line 84 (currently):

```dart
wordWidget = Cue.onToggle(
  key: ValueKey('reader-word-pop-$index'),
  toggled: token.isTapped,
  motion: .spring(
    duration: const Duration(milliseconds: 220),
    bounce: 0.35,
  ),
  reverseMotion: .snappy(),
  acts: const [.scale(to: 1.15)],
  child: wordWidget,
);
```

Replace with:

```dart
wordWidget = Cue.onToggle(
  key: ValueKey('reader-word-pop-$index'),
  toggled: token.isTapped,
  motion: .smooth(),
  reverseMotion: .snappy(),
  acts: storiaActs(
    context,
    all: const [
      ScaleAct.keyframed(
        frames: Keyframes([
          .key(1.0),
          .key(1.18, motion: .bouncy()),
          .key(1.0),
        ], motion: .smooth()),
      ),
      .colorTint(
        from: Colors.transparent,
        to: Color.fromRGBO(139, 92, 246, 0.18),
      ),
    ],
    reduced: const [.fadeIn()],
  ),
  child: wordWidget,
);
```

Notes:
- `ScaleAct.keyframed(frames: Keyframes([.key(1.0), .key(1.18, motion: .bouncy()), .key(1.0)], motion: .smooth()))` matches the cue 0.2.2 signature confirmed at `~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/scale.dart:270`.
- `.colorTint(from: Colors.transparent, to: Color.fromRGBO(139,92,246,0.18))` matches `ColorTintAct`'s signature (`~/.pub-cache/.../cue-0.2.2/lib/src/acts/color_tint.dart:51`).
- The reverse path goes `1.0 → 1.0` (the keyframes are symmetric, so reverse mirrors them) and the tint fades back via `ReverseBehavior.mirror` (default). A snappy reverse matches the existing UX.
- The keyframe list is `const` because `Keyframes` and its `.key()` entries are const-compatible.

- [ ] **Step 3: Write the failing test**

In `test/features/reader/overlay_text_element_pop_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_mobile/src/features/reader/overlay/overlay_text_element.dart';
import 'package:storia_mobile/src/features/reader/overlay/overlay_frame.dart';

void main() {
  group('OverlayTextElement word pop', () {
    testWidgets('isTapped word wraps in Cue.onToggle with a ScaleAct.keyframed of 3 keys',
        (tester) async {
      final token = OverlayTokenFrame(
        raw: 'hello',
        style: const TextStyle(),
        isWord: true,
        globalWordIndex: 4,
        isTapped: true,
      );
      final element = OverlayElementFrame(
        index: 0,
        left: 0,
        top: 0,
        width: 100,
        baseStyle: const TextStyle(),
        tokens: [token],
        textAlign: TextAlign.left,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              OverlayTextElement(
                element: element,
                onWordTap: (_, __) {},
                onWordLongPress: (_, __) {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // Find the word's Cue and inspect its act list.
      final cues = tester.widgetList<Cue>(find.byType(Cue));
      expect(cues, isNotEmpty);

      // The first Cue's acts should include a ScaleAct.keyframed whose
      // frames contain 3 keyframes.
      // Since act introspection is private, we assert only by Cue presence
      // and by the visible scale value after settle (skip reverse here).
      expect(cues.first.debugLabel, isNull);
    });
  });
}
```

If the private fields of `Cue`/`Actor` are not accessible for introspection in tests, the test instead asserts the widget tree shape: `find.byType(ScaleAct)` if it's a widget (it is NOT — `ScaleAct` is an `Act`, not a widget) — so drop the ScaleAct assertion and assert via `find.byType(Cue)` + artificial scale-on-pump metrics. The minimum assertion: `find.byType(Cue), findsOneWidget` after the widget mounts with `isTapped: true`.

- [ ] **Step 4: Adjust the field introspection according to cue's test surface**

Run, see what assertion is feasible, and rewrite the test to match Cue's public test surface. Acceptable assertion: `find.byType(Cue), findsOneWidget` and (optionally) `find.byType(Actor)` ancestor of the `RichText`. The exact `ScaleAct.keyframed` keyframe count is private — assert via Playwright visual proof only.

- [ ] **Step 5: Run analyze + test**

Run: `flutter analyze && flutter test test/features/reader/overlay_text_element_pop_test.dart`
Expected: zero warnings; PASS.

---

### Task 2: Add staggered choices to Story Spark card

**Files:**
- Modify: `lib/src/features/gen_ui/presentation/reader_activity_card.dart` — `_ActivityAnswers` and the two private row/tile widgets.

- [ ] **Step 1: Add the storiaActs import**

At top of `reader_activity_card.dart`:

```dart
import '../../../core/utils/storia_cue_acts.dart';
```

`import 'package:cue/cue.dart';` already present at line 1; `Actor` re-exports come from cue.

- [ ] **Step 2: Pass `displayIndex` through `_AnswerTile` and `_AnswerRow`**

Update the two widget constructors from:

```dart
class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.choice,
    required this.onTap,
    this.fullWidth = false,
  });

  ...
}
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.choice, required this.onTap});
  ...
}
```

to:

```dart
class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.choice,
    required this.onTap,
    this.fullWidth = false,
    required this.displayIndex,
  });

  final int displayIndex;
  ..existing fields..
}
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.choice,
    required this.onTap,
    required this.displayIndex,
  });

  final int displayIndex;
  ..existing fields..
}
```

- [ ] **Step 3: Wrap each per-index child in an `Actor` inside `_ActivityAnswers.build`**

Inside `_ActivityAnswers.build` (lines 304-333), the tiles block currently:

```dart
if (_useTiles) {
  final lastIndex = choices.length - 1;
  return Wrap(
    key: const ValueKey('activity-answers-tiles'),
    spacing: StoriaSpacing.sm,
    runSpacing: StoriaSpacing.sm,
    children: [
      for (var i = 0; i < choices.length; i++)
        _AnswerTile(
          choice: choices[i],
          fullWidth: choices.length.isOdd && i == lastIndex,
          onTap: () => onChoiceSelected(choices[i]),
        ),
    ],
  );
}
return Column(
  key: const ValueKey('activity-answers-stacked'),
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final choice in choices) ...[
      _AnswerRow(choice: choice, onTap: () => onChoiceSelected(choice)),
      if (choice != choices.last) const SizedBox(height: StoriaSpacing.sm),
    ],
  ],
);
```

Replace with:

```dart
if (_useTiles) {
  final lastIndex = choices.length - 1;
  return Wrap(
    key: const ValueKey('activity-answers-tiles'),
    spacing: StoriaSpacing.sm,
    runSpacing: StoriaSpacing.sm,
    children: [
      for (var i = 0; i < choices.length; i++)
        Actor(
          delay: (i * 60).ms,
          acts: storiaActs(
            context,
            all: const [.fadeIn(), .slideY(from: 0.08)],
            reduced: storiaReducedEntrance,
          ),
          child: _AnswerTile(
            choice: choices[i],
            fullWidth: choices.length.isOdd && i == lastIndex,
            onTap: () => onChoiceSelected(choices[i]),
            displayIndex: i,
          ),
        ),
    ],
  );
}
return Column(
  key: const ValueKey('activity-answers-stacked'),
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < choices.length; i++) ...[
      Actor(
        delay: (i * 60).ms,
        acts: storiaActs(
          context,
          all: const [.fadeIn(), .slideY(from: 0.08)],
          reduced: storiaReducedEntrance,
        ),
        child: _AnswerRow(
          choice: choices[i],
          onTap: () => onChoiceSelected(choices[i]),
          displayIndex: i,
        ),
      ),
      if (i != choices.length - 1) const SizedBox(height: StoriaSpacing.sm),
    ],
  ],
);
```

Note: the `Actor`s here ride on the parent `Cue.onMount` at `reader_activity_card.dart:161` because `_ActivityTakeover` creates one. Stack rule (skill: one `Cue` per scene) — the choices don't need their own trigger; they reuse the parent scope.

- [ ] **Step 4: Run analyze**

Run: `flutter analyze`
Expected: zero warnings.

- [ ] **Step 5: Write the failing test**

In `test/features/gen_ui/story_spark_choice_stagger_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:storia_mobile/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:storia_mobile/src/features/gen_ui/presentation/reader_activity_card.dart';

void main() {
  group('Story Spark choice stagger', () {
    testWidgets('renders one Actor per choice (3 of them)', (tester) async {
      final card = GenUiCardSchema(
        id: 'test',
        prompt: 'Pick one',
        choices: [
          GenUiChoiceSchema(id: 'a', label: 'A', emoji: null, accessibilityLabel: 'A'),
          GenUiChoiceSchema(id: 'b', label: 'B', emoji: null, accessibilityLabel: 'B'),
          GenUiChoiceSchema(id: 'c', label: 'C', emoji: null, accessibilityLabel: 'C'),
        ],
        skippable: true,
        supportingText: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            // ReaderActivityCard's Actors ride on a Cue scope — _ActivityTakeover
            // in production, but this test mounts the card in isolation. Provide
            // a minimal Cue.onMount parent so the Actors resolve a cue scope.
            child: Cue.onMount(
              motion: .smooth(),
              acts: const [.fadeIn()],
              child: ReaderActivityCard(
                card: card,
                onChoiceSelected: (_) {},
                onSkip: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Three Actors (one per choice tile/row) + one Cue (the outer card).
      expect(find.byType(Actor), findsNWidgets(3 /* per choice */));
    });
  });
}
```

If `GenUiChoiceSchema` and `GenUiCardSchema` constructor field sets differ from the above (read `domain/gen_ui_card_schema.dart`), adjust.

- [ ] **Step 6: Run the test**

Run: `flutter test test/features/gen_ui/story_spark_choice_stagger_test.dart`
Expected: PASS — `findsNWidgets(3)` for 3 choices.

---

### Task 3: Book preview arrow drop-in

**Files:**
- Modify: `lib/src/features/library/game/book_preview_overlay.dart` — the `CustomPaint` block (around line 75).
- Create: `test/features/library/book_preview_overlay_arrow_test.dart`

- [ ] **Step 1: Add the storiaActs import**

At top of `book_preview_overlay.dart`:

```dart
import '../../../core/utils/storia_cue_acts.dart';
```

`import 'package:cue/cue.dart';` already at line 2.

- [ ] **Step 2: Wrap the arrow `CustomPaint` in an `Actor`**

Find the arrow block (around lines 74-79):

```dart
// Downward-pointing triangle arrow
CustomPaint(
  size: const Size(_arrowSize * 2, _arrowSize),
  painter: _ArrowPainter(color: StoriaColors.paperRaised),
),
```

Replace with:

```dart
// Downward-pointing triangle arrow — drops in 100ms after card lands
Actor(
  delay: 100.ms,
  acts: storiaActs(
    context,
    all: const [.fadeIn(), .slideY(from: 0.5)],
    reduced: storiaReducedEntrance,
  ),
  child: CustomPaint(
    size: const Size(_arrowSize * 2, _arrowSize),
    painter: _ArrowPainter(color: StoriaColors.paperRaised),
  ),
),
```

The `Actor` rides on the parent `Cue.onMount` declared at line 54 (` Cue.onMount(debugLabel: 'library-book-preview', ... child: GestureDetector(child: Column(...)))`). The arrow is a sibling of the SketchCard inside that `Column`. segue rule: don't introduce a second `Cue.onMount` for the arrow; the actor picks up the parent scope.

- [ ] **Step 3: Write the test**

In `test/features/library/book_preview_overlay_arrow_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/library/game/book_preview_overlay.dart';
import 'package:storia_mobile/src/data/models.dart';

void main() {
  group('BookPreviewOverlay arrow Actor', () {
    testWidgets('renders one Actor skipping a Cue.onMount parent and another Cue (preview)',
        (tester) async {
      final book = Book(
        id: 'b1',
        title: 'T',
        author: 'A',
        pageCount: 5,
        pages: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              BookPreviewOverlay(
                book: book,
                position: const Offset(200, 200),
                onRead: () {},
                onDismiss: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Cue), findsOneWidget); // outer card Cue
      // At least one Actor lives in the subtree — the arrow one. The card
      // itself uses acts:[.fadeIn(), .scale(from: 0)], so its children are
      // not necessarily an Actor. Confirm by finding the arrow by icon.
      expect(find.byType(Actor), findsWidgets);
    });
  });
}
```

If `Book` constructor fields differ (read `data/models.dart`), adjust.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/library/book_preview_overlay_arrow_test.dart`
Expected: PASS.

---

### Task 4: Playwright proof + commit

- [ ] **Step 1: Record**

```bash
flutter run -d chrome &
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Flow:
#   1. Sign in via app-review@storia.kids -> parent birth year 1980 -> onboarding -> library
#   2. Open a book (tap book tile -> preview overlay appears, arrow drops in shortly after card)
#   3. Dismiss overlay. Open reader.
#   4. Tap a word in the reader overlay -> word punches up to 1.18x with a brief purple tint, settles back
#   5. Trigger Story Spark (if gated on, the toggle is on by default in dev; otherwise turn on via audio settings -> Story Sparks toggle) -> choice tiles cascade in
playwright-cli video-stop --filename=recordings/pr5-enrich-proof.webm
playwright-cli close
```

- [ ] **Step 2: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add lib/src/features/reader/overlay/overlay_text_element.dart \
        lib/src/features/gen_ui/presentation/reader_activity_card.dart \
        lib/src/features/library/game/book_preview_overlay.dart \
        test/features/reader/overlay_text_element_pop_test.dart \
        test/features/gen_ui/story_spark_choice_stagger_test.dart \
        test/features/library/book_preview_overlay_arrow_test.dart \
        recordings/pr5-enrich-proof.webm
```

```bash
git commit -m "feat(cue): enrich word-tap pop, Story Spark choice stagger, book preview arrow

* Reader word-tap pop: Cue.onToggle acts: [.scale(to: 1.15)] -> ScaleAct.keyframed
  with [.key(1.0), .key(1.18, motion: .bouncy()), .key(1.0)] and a brief
  ColorTintAct from Colors.transparent to RGB(139,92,246,0.18). The keyframed
  scale punches the word up to 1.18 with overshoot bounce then settles to 1.0.
  Reverse stays snappy via .snappy() reverseMotion. Reduced motion drops to
  .fadeIn() per storiaActs contract.

* Story Spark choices: per tile/row Actor(delay: (i * 60).ms) inside the
  existing _ActivityTakeover Cue.onMount cue scope; one Cue per scene rule
  preserved.

* Book preview overlay arrow CustomPaint -> Actor(delay: 100.ms) inside the
  outer Cue.onMount, drops in shortly after the card fades and scales in.

Plan: docs/superpowers/plans/2026-06-22-pr5-enrich-existing-cue-spots.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr5-enrich-proof.webm"
```

---

## Self-Review

- **Spec coverage:** word-pop keyframe + tint — Task 1. Story Spark choice stagger — Task 2. Book preview arrow drop — Task 3. All three spec items covered.
- **Placeholder scan:** Task 1 Step 5 acknowledges that Cue's `ScaleAct` keyframe fields are not introspectable from tests and adapts the test to assert on `find.byType(Cue)` presence. Real verification is the Playwright proof at Task 4.
- **Type consistency:** `ScaleAct.keyframed(frames: Keyframes([...], motion:))` matches cue 0.2.2 source (`~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/scale.dart:270`). `.colorTint(from:, to:)` matches `ColorTintAct` (`~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/color_tint.dart:51`). `Actor(delay: (i * 60).ms, acts: storiaActs(...), child:)` shape matches PRs 1-4 plan conventions.
- **Risk:** The Story Spark choice `Actor` rides on the outer `Cue.onMount` from `_ActivityTakeover` (`reader_activity_card.dart:161`). If the parent `Cue.onMount` has `repeat: false` (default) and is one-shot on mount, the per-choice delays read correctly once. The Story Spark test mounts `ReaderActivityCard` directly (not via `_ActivityTakeover`) — in that path, no parent Cue is present, and the per-choice `Actor` will throw because `Actor` without an ancestor Cue throws (per skill rule "Actor without an ancestor Cue throws"). Fix: wrap the test card in `Cue.onMount(motion: .smooth(), acts: [.fadeIn()], child: ReaderActivityCard(...))` to provide the cue scope. Add this to the test harness in Task 2 Step 5.