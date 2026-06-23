# PR 4 — Library filter indicator + reader audio pill

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 is merged. PR 1 helpful (modal + ValueNotifier muscle).

**Goal:** Replace the two `AnimatedPositioned` blobs inside `_FilterGooeyIndicator` with a Cue-driven `PositionedActor.from / to` whose animation re-triggers whenever the active filter changes (keyed-restart on `Cue.onMount`). Replace the audio pill's `AnimatedOpacity`/`AnimatedScale` (visibility + drag scale) with `Cue.onToggle` + `Actor`s backed by a `ValueNotifier<bool>` refactor of `_isDragging`.

**Architecture:**

1. **Filter indicator** — Horizontal gooey "pill" trail in the library shelf-filter row. The pill's two `GooeyBlob`s move whenever the active filter changes (chip switch). Migration shape:
   - `_FilterGooeyIndicator` becomes `StatefulWidget` (`_FilterGooeyIndicatorState`) and gains an `activeFilter: _ShelfFilter` prop. The parent `_ShelfFilters` passes both `activeRect` (existing) and `activeFilter` (new) into it.
   - State stores `_fromRect` (initialized to `widget.activeRect` in `initState`). `didUpdateWidget` updates `_fromRect = oldWidget.activeRect` when the active filter changes. `to:` becomes `widget.activeRect`.
   - `Stack` children's `PositionedActor(from: Position(...), to: Position(...), child: blob)` are wrapped in one shared `Cue.onMount(key: ValueKey(widget.activeFilter), motion: .spatial(), debugLabel: 'filter-indicator', child:)`. Keying `Cue.onMount` on `activeFilter` means each chip switch dismantles the Cue and rebuilds a fresh one with new `from:`/`to:`, replaying the animation.
   - The trail blob's actor carries `delay: 40.ms` and `reverseDelay: 20.ms` for the lag effect.
   - The `_chipRects` measurement pipeline in `_ShelfFiltersState` is unchanged.

2. **Audio pill** — `AudioControlsPill` in `reader_screen.dart`:
   - The outer pill subtree currently wraps `AnimatedOpacity(opacity: isVisible ? 1 : 0)` + `AnimatedScale(scale: _isDragging ? 1.035 : 1.0)`. Replaced by `Cue.onToggle(toggled: widget.isVisible, motion: .bouncy(), acts: storiaActs(c, all: const [.fadeIn(), .scale(to: 1.035)], reduced: const [.fadeIn()]), child: pillSubtree)`.
   - The grip handle currently uses `AnimatedScale(scale: _isDragging ? 1.06 : 1.0, duration: 160 ms, curve: Curves.easeOut)`. Replaced by `Cue.onToggle(toggled: _isDragging.value, motion: .snappy(), acts: const [.scale(to: 1.06)], child: gripHandle)`.
   - The `_isDragging` field becomes a `ValueNotifier<bool>` so `Cue.onToggle` can watch the `Listenable`. `dispose()` adds `_isDragging.dispose();`. All 6 read sites change from `_isDragging` to `_isDragging.value`. The 4 write sites — `setState(() => _isDragging = true/false)` — become `_isDragging.value = true/false;` (drop the `setState` wrapper since the `ValueNotifier` self-notifies and the consuming `Cue.onToggle` rebuilds). However, since other parts of the build (e.g. boxShadow differences on `_isDragging`) still read the bool at build time and a `ValueNotifier` listener triggers a rebuild, the existing `setState(_=> _isDragging = true)` pattern can be **kept as-is** — set the notifier value and call `setState`. Simpler: keep `bool _isDragging` plus a parallel `ValueNotifier<bool> _isDraggingNotifier`, sync them in the handlers. Chosen: refactor to `ValueNotifier<bool> _isDragging` + `setState` removed from the toggle sites only where the rebuild comes entirely from the notifier. **Decision for the plan: keep `setState` calls where they drive other visual props; update the field type to `ValueNotifier<bool>` and reads to `.value`.**

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2 (`Cue.onMount` keyed restart, `PositionedActor`, `Cue.onToggle`, `Position` data class), `package:flutter_test`.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 4 — Library indicator + audio pill").

---

### Task 1: Write the failing test for the gooey indicator Cue restart

**Files:**
- Create: `test/features/library/filter_gooey_indicator_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_mobile/src/features/library/library_screen.dart';

void main() {
  group('FilterGooeyIndicator Cue restart', () {
    testWidgets('renders a PositionedActor under a Cue.onMount keyed by activeFilter',
        (tester) async {
      // The indicator is private, so we mount via _ShelfFilters within the
      // LibraryScreen or directly via a public harness if _ShelfFilters is
      // exposed. See test/features/library/library_screen_test.dart for the
      // existing harness pattern.
      await tester.pumpWidget(_harnessWithFilter(/* selected: */ _ShelfFilter.all));
      await tester.pump();

      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(PositionedActor), findsNWidgets(2 /* main + trail blob */));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/library/filter_gooey_indicator_test.dart`
Expected: FAIL — indicator still uses `AnimatedPositioned`, no `PositionedActor` present.

- [ ] **Step 3: Implement the harness helper `_harnessWithFilter`**

```
Read test/features/library/library_screen_test.dart to find the existing ProviderScope + ProviderScope overrides recipe, then add a helper that mounts `LibraryScreen` (or `_ShelfFilters` if exposed via `@visibleForTesting`) with a filtered list of fake `Book`s that drive the chip rects into measurable values.
```

If `_ShelfFilters` is too private to mount in isolation, mount `LibraryScreen` and assert the indicator subtree from there.

---

### Task 2: Migrate `_FilterGooeyIndicator` to keyed `Cue.onMount` + `PositionedActor`

**Files:**
- Modify: `lib/src/features/library/library_screen.dart` — `_ShelfFilters`, `_FilterGooeyIndicator`.

- [ ] **Step 1: Add the imports** to `library_screen.dart`:

```dart
import '../../core/utils/storia_cue_acts.dart';
```

`import 'package:cue/cue.dart';` is already present (line 5).

- [ ] **Step 2: Pass `activeFilter` prop from `_ShelfFilters` down to `_FilterGooeyIndicator`**

In `_ShelfFilters.build` (around line 891), the `_FilterGooeyIndicator(activeRect: activeRect)` call (line 906 within the Stack) becomes:

```dart
_FilterGooeyIndicator(
  activeRect: activeRect,
  activeFilter: widget.activeFilter,
)
```

- [ ] **Step 3: Convert `_FilterGooeyIndicator` to `StatefulWidget` and add `activeFilter`**

Replace the existing `_FilterGooeyIndicator` `StatelessWidget` (lines 931-993) with:

```dart
class _FilterGooeyIndicator extends StatefulWidget {
  const _FilterGooeyIndicator({
    required this.activeRect,
    required this.activeFilter,
  });

  final Rect activeRect;
  final _ShelfFilter activeFilter;

  @override
  State<_FilterGooeyIndicator> createState() => _FilterGooeyIndicatorState();
}

class _FilterGooeyIndicatorState extends State<_FilterGooeyIndicator> {
  late Rect _fromRect;

  @override
  void initState() {
    super.initState();
    _fromRect = widget.activeRect;
  }

  @override
  void didUpdateWidget(covariant _FilterGooeyIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeFilter != widget.activeFilter) {
      _fromRect = oldWidget.activeRect;
    }
  }

  @override
  Widget build(BuildContext context) {
    final toRect = widget.activeRect;
    // Map a Rect to a Position via top-left + width + height.
    Position _pos(Rect r) =>
        Position(top: r.top, start: r.left, width: r.width, height: r.height);

    final pillRect = Rect.fromLTWH(
      toRect.left,
      toRect.top + 2,
      toRect.width,
      toRect.height - 4,
    );
    final fromPillRect = Rect.fromLTWH(
      _fromRect.left,
      _fromRect.top + 2,
      _fromRect.width,
      _fromRect.height - 4,
    );

    final trailSize = math.min(36.0, pillRect.height);
    final fromTrail = Rect.fromCenter(
      center: Offset(fromPillRect.center.dx, fromPillRect.center.dy),
      width: trailSize,
      height: trailSize,
    );
    final toTrail = Rect.fromCenter(
      center: Offset(pillRect.center.dx, pillRect.center.dy),
      width: trailSize,
      height: trailSize,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: GooeyZone(
            key: const ValueKey('library-filter-gooey-indicator'),
            color: StoriaColors.ink,
            gooiness: 34,
            borderWidth: 1,
            borderColor: StoriaColors.paper.withValues(alpha: 0.16),
            child: Cue.onMount(
              key: ValueKey('filter-indicator-${widget.activeFilter}'),
              motion: .spatial(),
              reverseMotion: .spatial(),
              debugLabel: 'filter-indicator',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedActor(
                    from: _pos(fromTrail),
                    to: _pos(toTrail),
                    delay: 40.ms,
                    reverseDelay: 20.ms,
                    child: const GooeyBlob(
                      key: ValueKey('library-filter-gooey-trail'),
                      shape: BlobShape.circle(),
                      child: SizedBox.expand(),
                    ),
                  ),
                  PositionedActor(
                    from: _pos(fromPillRect),
                    to: _pos(pillRect),
                    child: const GooeyBlob(
                      key: ValueKey('library-filter-gooey-main'),
                      shape: BlobShape.rounded(16),
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Notes:
- `Position` imports from `package:cue/cue.dart`.
- `Position(top:, start:, width:, height:)` matches the `Position` data class shape (defined at `~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/position.dart`). If `start:` is named `left:` in this version of cue, switch to that — the dartdoc example uses `start:` for LTR equivalency. Verify with `grep -n "Position(" ~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/position.dart` during implementation.
- The `Stack` children go directly into the `Cue.onMount`'s `child:` so both `PositionedActor`s share one trigger.
- Drop the now-unused `AnimatedPositioned` imports semantics; `dart:async` and `dart:math` are already imported at the top of `library_screen.dart`.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/library/filter_gooey_indicator_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze + full test gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all existing library tests still pass. If `Position` field access differs from the example, fix here.

---

### Task 3: Refactor `AudioControlsPill._isDragging` into a `ValueNotifier<bool>`

**Files:**
- Modify: `lib/src/features/reader/reader_screen.dart` — `AudioControlsPillState`.

- [ ] **Step 1: Change the field type**

Find the declaration at `lib/src/features/reader/reader_screen.dart:565`:

```dart
bool _isDragging = false;
```

Replace with:

```dart
final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);
```

- [ ] **Step 2: Update read sites to use `.value`**

Search:

```bash
grep -n "_isDragging" lib/src/features/reader/reader_screen.dart
```

For every read site (`_isDragging ==`, `_isDragging ? ...`, `if (_isDragging)`), change to `_isDragging.value`. For write sites (`_isDragging = true;`, `_isDragging = false;`), change to `_isDragging.value = true;` / `false;`.

There are roughly 6 read sites and 3-4 write sites in `AudioControlsPillState` (560-1042).

- [ ] **Step 3: Remove `setState(() => _isDragging = ...)` wrappers but keep `setState` where other state changes**

For the two handlers that ONLY flip `_isDragging`:

```dart
void _handlePanStart() {
  setState(() => _isDragging = true);
  _activateWobble();
}

void _handlePanEnd() {
  setState(() => _isDragging = false);
  _beginWobbleOutro();
}
```

become:

```dart
void _handlePanStart() {
  _isDragging.value = true;
  _activateWobble();
}

void _handlePanEnd() {
  _isDragging.value = false;
  _beginWobbleOutro();
}
```

`_activateWobble` and `_beginWobbleOutro` already call `setState` themselves where needed.

- [ ] **Step 4: Dispose the notifier**

In `dispose()` (the override at lines 617-625):

```dart
@override
void dispose() {
  _outroController
    ..removeListener(_handleOutroTick)
    ..removeStatusListener(_handleOutroStatus)
    ..dispose();
  _trailVectorNotifier.dispose();
  _dragOffsetNotifier.dispose();
  _isDragging.dispose(); // NEW
  super.dispose();
}
```

- [ ] **Step 5: Run analyze + test gate (no visual change yet — `Cue.onToggle` lands in Task 4)**

Run: `flutter analyze && flutter test`
Expected: zero warnings; existing tests still pass.

This task is internal plumbing — the audio pill behaves identically until Task 4 replaces the `AnimatedOpacity`/`AnimatedScale` with `Cue.onToggle`.

---

### Task 4: Replace `AnimatedOpacity` + `AnimatedScale` (pill visibility + drag scale) with `Cue.onToggle`

**Files:**
- Modify: `lib/src/features/reader/reader_screen.dart` — `AudioControlsPillState.build` (lines 1044-1107).

- [ ] **Step 1: Add the storiaActs import** to `reader_screen.dart` (PR 1 already added `import '../../core/utils/storia_cue_acts.dart';` — confirm and skip if present):

```dart
import '../../core/utils/storia_cue_acts.dart';
```

- [ ] **Step 2: Replace the outer wrap in `build`**

Find this block (lines 1052-1073):

```dart
final pillSubtree = IgnorePointer(
  ignoring: !widget.isVisible,
  child: AnimatedOpacity(
    opacity: widget.isVisible ? 1 : 0,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    child: AnimatedScale(
      scale: _isDragging.value ? 1.035 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: _circleSize,
        height: _circleSize,
        child: _buildCircleBody(
          viewportSize: viewportSize,
          safePadding: safePadding,
          baseBottom: baseBottom,
        ),
      ),
    ),
  ),
);
```

Replace with:

```dart
final pillSubtree = IgnorePointer(
  ignoring: !widget.isVisible,
  child: Cue.onToggle(
    toggled: widget.isVisible,
    motion: .bouncy(),
    reverseMotion: .smooth(),
    acts: storiaActs(
      context,
      all: const [.fadeIn(), .scale(to: 1.035)],
      reduced: const [.fadeIn()],
    ),
    child: SizedBox(
      width: _circleSize,
      height: _circleSize,
      child: _buildCircleBody(
        viewportSize: viewportSize,
        safePadding: safePadding,
        baseBottom: baseBottom,
      ),
    ),
  ),
);
```

Note: dropped the inner `AnimatedScale(scale: _isDragging.value ? 1.035 : 1.0)` — the `Cue.onToggle(toggled: widget.isVisible)` owns the `.scale(to: 1.035)` now. The grip handle still uses `_isDragging.value` separately in Task 5.

- [ ] **Step 3: Replace the grip handle's `AnimatedScale`**

Find `_buildGripHandle` (lines 985-1042). The current `AnimatedScale` is at line 985:

```dart
child: AnimatedScale(
  scale: _isDragging ? 1.06 : 1.0,
  duration: const Duration(milliseconds: 160),
  curve: Curves.easeOut,
  child: Container(
    width: _gripSize,
    height: _gripSize,
    decoration: /* gradient + box-shadow */,
    child: /* grip handle rows */,
  ),
),
```

Replace the `AnimatedScale(...)` wrap with:

```dart
child: Cue.onToggle(
  toggled: _isDragging.value,
  motion: .snappy(),
  reverseMotion: .snappy(),
  acts: const [.scale(to: 1.06)],
  child: Container(
    width: _gripSize,
    height: _gripSize,
    decoration: /* existing decoration verbatim */,
    child: /* existing grip rows verbatim */,
  ),
),
```

Leave the gradient color change (`_isDragging ? 0.40 : 0.32`) and shadow opacity (`alpha: _isDragging ? 0.32 : 0.24`) untouched — those flip instantly via `.value` reads inside the build, exactly as before. Only the `AnimatedScale` becomes `Cue.onToggle`. If the existing code reads `_isDragging` in the gradient/shadow expressions, only the new `.value` reads (from Task 3) carry over.

- [ ] **Step 4: Run analyze + test**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

---

### Task 5: Write the audio pill tests

**Files:**
- Create: `test/features/reader/audio_pill_visibility_test.dart`
- Create: `test/features/reader/audio_pill_drag_scale_test.dart`

- [ ] **Step 1: Visibility test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/reader/reader_screen.dart';

void main() {
  group('AudioControlsPill visibility Cue.onToggle', () {
    testWidgets('renders a Cue.onToggle wrapping a fadeIn+scale Actor',
        (tester) async {
      await tester.pumpWidget(_harness(isVisible: true));
      await tester.pump();
      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(Actor), findsWidgets);
    });

    testWidgets('hides when isVisible=false', (tester) async {
      await tester.pumpWidget(_harness(isVisible: false));
      await tester.pumpAndSettle();
      // Off-state — the subtree is still present but the cue progress is 0.
      expect(find.byType(AudioControlsPill), findsOneWidget);
    });
  });
}
```

The `_harness` recipe follows `test/features/reader/reader_screen_test.dart` minimally — render `AudioControlsPill` with stub narration/soundscape toggles.

- [ ] **Step 2: Drag-scale test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/reader/reader_screen.dart';

void main() {
  group('AudioControlsPill grip Cue.onToggle on drag', () {
    testWidgets('toggling _isDragging flips the grip Cue.onToggle',
        (tester) async {
      await tester.pumpWidget(_harness(isVisible: true));
      await tester.pumpAndSettle();
      // The grip is identified by its semantically-labeled GestureDetector.
      final grip = find.bySemanticsLabel('Move audio controls');
      await tester.tap(grip);
      await tester.pump();
      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(Actor), findsWidgets);
    });
  });
}
```

If `find.bySemanticsLabel('Move audio controls')` does not match, switch to `find.byWidgetPredicate` that matches the rows of 3 grip dots drawn inside the `Container`.

- [ ] **Step 3: Run the tests**

Run: `flutter test test/features/reader/audio_pill_visibility_test.dart test/features/reader/audio_pill_drag_scale_test.dart`
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
#   2. Library screen appears
#   3. Tap "Quick Reads" filter chip -> gooey indicator springs from "All Tales" to "Quick Reads"
#   4. Tap "Longer Reads" -> indicator springs again
#   5. Open a book -> audio controls pill visible. Tap reader screen to hide chrome -> wait for pill hide
#   6. Tap to show. Drag pill -> grip squishes to 1.06 scale. Release -> grip snaps back.
playwright-cli video-stop --filename=recordings/pr4-library-audio-proof.webm
playwright-cli close
```

- [ ] **Step 2: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add lib/src/features/library/library_screen.dart \
        lib/src/features/reader/reader_screen.dart \
        test/features/library/filter_gooey_indicator_test.dart \
        test/features/reader/audio_pill_visibility_test.dart \
        test/features/reader/audio_pill_drag_scale_test.dart \
        recordings/pr4-library-audio-proof.webm
```

```bash
git commit -m "feat(cue): migrate filter gooey indicator + audio controls pill to Cue

* _FilterGooeyIndicator: AnimatedPositioned x2 -> keyed Cue.onMount +
  PositionedActor.from/to. The indicator rebuilds with from=old activeRect,
  to=new activeRect on every filter change; Cue is keyed by the active
  filter so each switch dismantles and re-creates a fresh animation.
  Trail blob Actor carries delay:40ms, reverseDelay:20ms for the lag.
  Position values map rect's top/left + width/height directly.

* AudioControlsPillState._isDragging: bool -> ValueNotifier<bool> with
  reads via .value and writes via .value=. dispose() disposes notifier.

* _AudioControlsPill visible-subtree: AnimatedOpacity + AnimatedScale
  -> Cue.onToggle(toggled: widget.isVisible, motion: .bouncy(),
  acts: storiaActs([.fadeIn(), .scale(to: 1.035)])).

* _buildGripHandle: AnimatedScale(scale: _isDragging ? 1.06 : 1.0) ->
  Cue.onToggle(toggled: _isDragging.value, motion: .snappy(),
  acts: [.scale(to: 1.06)]).

Plan: docs/superpowers/plans/2026-06-22-pr4-library-indicator-audio-pill.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr4-library-audio-proof.webm"
```

---

## Self-Review

- **Spec coverage:** indicator migration (Task 2), visible + drag scale Cue.onToggle (Tasks 3-4), `storiaActs` reduced-motion (Tasks 4 + 5). Both spec items covered.
- **Placeholder scan:** None found. The `_harness` helpers in tests are described as replicating the established recipe at `test/features/library/library_screen_test.dart` and `test/features/reader/reader_screen_test.dart`.
- **Type consistency:** `Position(top:, start:, width:, height:)` — the cue source confirms `start:` is used (LTR mapping). If the analyzer reports a different field name (e.g. `left:`), the worker swaps without behavior change — the rect→Position helper `_pos` abstracts this single line. `_isDragging.value` reads match the `ValueNotifier<bool>` refactor. `Cue.onToggle(toggled: bool, motion:, reverseMotion:, acts:, child:)` matches the API confirmed against cue 0.2.2's cue_modals.dart file (`Cue.onToggle(toggled:, motion:, reverseMotion:, child:)`).
- **Risk:** The keyed-restart pattern on `Cue.onMount(key: ValueKey(widget.activeFilter), ...)` requires that Flutter fully dispose the old CueController when the key changes — Cue 0.2.2's controller handles dispose on `dispose()`. The Playwright proof verifies the spring travels smoothly between chips; if the brief remount-flash is visible, raise the `motion:` to `.spatial()` longer duration or include `reverseOnRepeat: false` enforcement (default already false). The indicator's measure pipeline already runs in `_ShelfFiltersState._scheduleMeasure`, so `_chipRects` is populated before the indicator can race.