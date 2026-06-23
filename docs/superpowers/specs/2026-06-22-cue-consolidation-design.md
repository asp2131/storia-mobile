# Cue Animation Consolidation Design

> **Status:** approved design on 2026-06-22
> **Author:** brainstormed with user, drafted by opencode
> **Scope:** consolidate every animation in storia-mobile onto `package:cue`, drop `flutter_animate`, ship in 8 ordered PRs

## Goal

Consolidate every animation in the app onto `package:cue` so the codebase has one motion model, one trigger vocabulary, and one reduced-motion contract. Drop `flutter_animate` from `pubspec.yaml`. Add the missing high-value Cue usage (modals, entrances, page controller, ambient loops) while shrinking the mental model and the dep graph.

## Approach

- **One shared reduced-motion guard:** `storiaActs(context, all:, reduced:)` in `lib/src/core/utils/storia_cue_acts.dart`. Every `acts:` argument in every `Cue.*` call passes through it. Reduced motion → `reduced ?? const [.fadeIn()]`.
- **One animation system:** `Cue` replaces every `AnimatedOpacity`, `AnimatedScale`, `AnimatedPositioned`, `AnimatedSwitcher`, `AnimatedDefaultTextStyle`, `AnimatedContainer`, the lone `flutter_animate` chain, and all hand-rolled `AnimationController` / `TickerProviderStateMixin` sites.
- **Motions:** spring presets `.smooth()` (default), `.snappy()` (micro-interactions), `.bouncy()` / `.wobbly()` (playful kids' touches — word pop, audio pill, story spark, default badge), `.gentle()` (intro hero bob). `StoriaMotion` tokens remain available for fixed-curve cases.
- **Cue version:** bump `cue: ^0.2.1` → `cue: ^0.2.2` (PR 0). Cue 0.2.2 ships `CueModalTransition`, `showCueDialog`/`CueDialogRoute`, `CuePageController`, `Cue.indexed`, `CardActor`. Confirmed locally in `~/.pub-cache/hosted/pub.dev/cue-0.2.2/`.
- **Drop `flutter_animate ^4.5.2`** in PR 7 (it's used only in `page_renderer.dart`).
- **8 PRs in dependency order**, each shipping independently.

## PR ordering

| PR | Area | New files | Touched files | Risk |
|----|------|-----------|----------------|------|
| 0 | Foundation: `storiaActs` helper + test; bump cue to 0.2.2 | `lib/src/core/utils/storia_cue_acts.dart` + test, `pubspec.yaml`, `AGENTS.md` | none else | low |
| 1 | Modals: `_AudioSettingsSheet` + `ParentalGate` → `showCueDialog` / `CueDialogRoute` | tests | `reader_screen.dart`, `parental_gate.dart` | low |
| 2 | Auth + onboarding entrances: `intro_screen`, `sign_in_screen`, `sign_up_screen`, `parent_birth_year_screen`, `review_onboarding_screen` (goal-card `CardActor`) | tests | 5 files | low |
| 3 | Child profile picker: `profile_picker_screen` avatar stagger + `_DefaultBadge` pop; `add_child_screen` `_AgeBandChip` `onToggle` | tests | 2 files | low |
| 4 | Library indicator + audio pill: `_FilterGooeyIndicator` (`onChange` + `PositionedActor.keyframed`); `AudioControlsPill` show/hide + grip scale (`Cue.onToggle` + `ValueNotifier<bool>` refactor) | tests | `library_screen.dart`, `reader_screen.dart` | medium |
| 5 | Enrich existing Cue spots: word-tap pop keyframe, Story Spark choice stagger, book preview arrow drop | tests | `overlay_text_element.dart`, `reader_activity_card.dart`, `book_preview_overlay.dart` | medium |
| 6 | Ambient loops: `intro_screen` clouds/sun/sparkles + `intro_hero_illustration` bob + `library_screen._SkyDecorations` via `Cue.onMount(repeat:, reverseOnRepeat:)` + `TweenActor<double>` | tests | 3 files | medium |
| 7 | Reader PageView: `PageController` → `CuePageController`, `flutter_animate` → `Cue.indexed`, drop `flutter_animate` dep | test | `reader_screen.dart`, `page_renderer.dart`, `pubspec.yaml`, `AGENTS.md` | high |

## Shared helper

`lib/src/core/utils/storia_cue_acts.dart`:

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

/// Reduced-motion entrance: gentle fade + a 0.06 slide so the motion still
/// reads but doesn't travel. Pass as [storiaActs]'s `reduced:` argument where
/// the full entrance slides further (e.g. `from: 0.12+`).
const List<Act> storiaReducedEntrance = [
  .fadeIn(),
  .slideY(from: 0.06),
];
```

Every migrated `Cue.*` call site throughout the seven subsequent PRs routes its `acts:` argument through `storiaActs`.

## Per-PR specs

### PR 0 — Foundation

**New file:** `lib/src/core/utils/storia_cue_acts.dart` (see Shared helper above).

**New test:** `test/core/utils/storia_cue_acts_test.dart`
- asserts the reduced-motion branch selects `const [.fadeIn()]` when `MediaQuery.disableAnimationsOf` returns true.
- asserts the full branch returns the input list unchanged.
- asserts a custom `reduced:` argument wins under reduced motion.

**pubspec.yaml:**
- Line 62: `cue: ^0.2.1` → `cue: ^0.2.2` (prefix `>=0.2.2 <0.3.0` allowed for stability).
- `flutter pub get`.

**AGENTS.md:**
- Line 64: remove `flutter_animate` from the Animation list; the dep is still installed until PR 7 but the doc note now reflects that the canonical animation library is cue.

**Out of scope for PR 0:** touching any animation call site, dropping `flutter_animate` (PR 7 only).

### PR 1 — Modals

**`_AudioSettingsSheet` (`reader_screen.dart:360-380`):**
- Replace `showModalBottomSheet<void>(context:, backgroundColor:, shape:, builder:)` with `showCueDialog<void>(context:, motion: .smooth(), reverseMotion: .snappy(), barrierColor: StoriaColors.paper.withAlpha(0xCC), builder: (ctx) => Actor(acts: storiaActs(ctx, all: const [.fadeIn(), .slideY(from: 1), reduced: storiaReducedEntrance]), child: _AudioSettingsSheet(...)))`.
- `.slideY(from: 1)` rides the sheet up from bottom (preserves the existing bottom-sheet origin of `showModalBottomSheet`).
- The settings sheet body now wraps in `CueScope` automatically via `showCueDialog` (no manual controller pass-through).
- Drop the `shape:` `RoundedRectangleBorder` since the inner card already provides the shape; translate the existing `Padding` into the Actor's child.

**`ParentalGate.verify` (`parental_gate.dart:19-31`):**
- Replace `showModalBottomSheet<bool>(...)` with `Navigator.of(context).push<bool>(CueDialogRoute<bool>(motion: .smooth(), reverseMotion: .snappy(), barrierColor: Colors.black54, barrierDismissible: false, pageBuilder: (c, _, _) => _GateSheet(controller: controller)))` then `await` it.
- Inside `_GateSheet.build`, wrap `GateChallengeCard(...)` in `Actor(acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 1, motion: CueMotion.easeOut(StoriaMotion.quick))]))`.
- `CueDialogRoute` is a `PageRoute` subclass — existing `Navigator.pop(true)` / `Navigator.pop(false)` calls in `_GateSheetState._onStateChanged` keep working unchanged.

**New tests:**
- `test/core/widgets/parental_gate_cue_dialog_test.dart`: mount `_GateSheet` in a `CueDebugTools` harness wrapped in `MaterialApp`, pump, assert `find.byType(Actor)` finds at least one widget and the card becomes visible (`Opacity` descendant == 1.0 after settle).
- `test/features/reader/audio_settings_cue_dialog_test.dart`: trigger `_showAudioSettings` via the chrome-button tap, assert the dialog route becomes the topmost route, assert `Actor` present.

**Playwright:** `recordings/pr1-modals-proof.webm` covering: open audio settings (top-bar tune icon) → dismiss; trigger parental gate (settings icon in library) → cancel.

### PR 2 — Auth + onboarding entrances

**`intro_screen.dart`:**
- The inner content `Column` (title → subtitle → top button → second button, currently at `intro_screen.dart:248-289`) wraps in `Cue.onMount(debugLabel: 'intro-entrance', motion: .smooth(), child:)`. Each of the four children becomes an `Actor(delay: (i * 60).ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.08)], reduced: storiaReducedEntrance))`.
- Ambient loops (clouds, sun, sparkles) stay with the existing `AnimationController..repeat()` until PR 6.

**`auth_screen_shell.dart` (shared by `sign_in_screen.dart:58` and `sign_up_screen.dart:41`):**
- Read `lib/src/features/auth/presentation/widgets/auth_screen_shell.dart` first; insert one `Cue.onMount(debugLabel: 'auth-form-entrance', motion: .smooth(), child:)` around its `child:` slot.
- Inside `child:` content per-screen, wrap the form heading block in `Actor(acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.06)]), child:)` and the buttons row + footer in `Actor(delay: 80.ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.06)]), child:)`.
- Single insertion point in `auth_screen_shell.dart` covers both sign-in and sign-up screens.

**`parent_birth_year_screen.dart`:**
- Currently `ConsumerStatefulWidget` form with year field + submit button (no animation).
- Wrap the form `Column` in `Cue.onMount(debugLabel: 'parent-year-entrance', motion: .smooth(), child:)` and add `Actor`s around: (1) heading/icon block at delay 0ms, (2) field block at delay 60ms, (3) submit button at delay 120ms. `acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.06)], reduced: storiaReducedEntrance)`.

**`review_onboarding_screen.dart:222`** — the goal-card check icon `AnimatedContainer` becomes:
```dart
Cue.onToggle(
  toggled: isSelected,
  motion: .snappy(),
  reverseMotion: .snappy(),
  child: CardActor(
    color: .tween(Colors.transparent, StoriaColors.dustyPinkStrong),
    shape: .circle,
    child: SizedBox(width: 22, height: 22,
      child: isSelected ? Icon(Icons.check, size: 14, color: Colors.white) : SizedBox.shrink()),
  ),
)
```
Plus the `Icon` fades via `Actor(acts: [(.fadeIn(),)])` inside the `CueScope`.

**New tests:**
- `test/features/auth/intro_screen_entrance_test.dart`: mount `IntroScreen`, pump, assert 4 `Actor`s present with increasing delays.
- `test/features/auth/auth_shell_entrance_test.dart`: mount `AuthScreenShell` with a `Text('hi')` child, pump, assert shared `Cue.onMount` present.
- `test/features/onboarding/review_onboarding_goal_card_test.dart`: build `_GoalCard(goal: _, isSelected: true, onTap: _)`, toggle `isSelected` false→true, assert `CardActor` present and `find.byIcon(Icons.check)` appears after pumpAndSettle.

**Playwright:** `recordings/pr2-entrances-proof.webm` covering: intro→signup entrance animation; sign-in entrance; parent-year entrance; onboarding goal-card selection toggle.

### PR 3 — Child profile picker

**`profile_picker_screen.dart:129 (the `_ProfilePickerContent` body):**
- Currently `...profiles.map((profile) => Padding(... _ProfileChoiceCard(...))) ...` has no animation; appears instantly.
- Wrap the outer `Column` in `Cue.onMount(debugLabel: 'profile-list-entrance', motion: .smooth(), child:)`.
- Move the `Padding` + `_ProfileChoiceCard` per-item inside an `Actor(delay: (displayIndex * 60).ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.05)], reduced: storiaReducedEntrance))`.
- Pass a new `int displayIndex` field into `_ProfilePickerContent`'s `.map((profile)` enumeration (the lambda already runs as `.map` over `profiles` so add `Indexed` via `profiles.asMap().entries.map((entry) { final i = entry.key; final profile = entry.value; ...})` if the index isn't already in scope — check the current file; `.map((profile)=>...)` is fine, change to `.toList().asMap()...` or use `for (var i = 0; i < profiles.length; i++) {...}`).
- The "Add another child" `SketchButton` after the loop becomes `Actor(delay: (profiles.length * 60).ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.05)]), child: button)`.
- Empty state `_NoProfilesCard` is wrapped in an `Actor(acts: storiaActs(c, all: const [.fadeIn()]), child:)`.

**`_DefaultBadge` (`profile_picker_screen.dart:266`):**
- Wrap the badge content in `Cue.onMount(motion: .bouncy(), debugLabel: 'default-badge-pop', acts: storiaActs(c, all: const [.scale(from: 0)], reduced: const [.fadeIn()]), child: badge)`.
- `.bouncy()` matches the playful kids' feel for the "Default" tag.

**`add_child_screen.dart:200 _AgeBandChip`:**
- Per-chip selection toggle: wrap the chip's `Ink` content in `Cue.onToggle(toggled: selected, motion: .snappy(), reverseMotion: .snappy(), acts: storiaActs(c, all: const [.scale(to: 0.97)], reduced: const [.fadeIn()]), child: ...)`.
- Subtle 3% squish on tap is playful without being busy.

**New tests:**
- `test/features/child/profile_picker_entrance_test.dart`: build `_ProfilePickerContent` with a stub `ChildProfile` list of 3, pump, assert 3 `Actor`s present with `delay` increasing per index.
- `test/features/child/default_badge_pop_test.dart`: mount `_DefaultBadge`, pump, assert `Cue.onMount` present with `Acts.scale` containing `from: 0`.
- `test/features/child/age_band_chip_toggle_test.dart`: build `_AgeBandChip(selected: true)`, pumpAndSettle, tap, assert `Cue.onToggle` flips.

**Playwright:** `recordings/pr3-child-profile-proof.webm` covering: profile picker staggered entrance, default badge pop, age band chip selection.

### PR 4 — Library indicator + audio pill

**`_FilterGooeyIndicator` (`library_screen.dart:931`):**
- Currently `AnimatedPositioned` x2 driven by `activeRect` measured externally. `StoriaMotion.emphasized` curve.
- Replace with `Cue.onChange(value: activeFilter, motion: .spatial(), fromCurrentValue: true, debugLabel: 'filter-indicator', child:)` placed at the `_ShelfFilters` level. Lift `widget.activeFilter` from the existing StatefulWidget into a `ValueNotifier<_ShelfFilter>` stored in `_ShelfFiltersState` so the `Cue.onChange` has a stable `ValueListenable` to watch (mirrors the existing code that takes the widget Prop).
- Inside `_FilterGooeyIndicator`, replace the two `AnimatedPositioned` with `PositionedActor.keyframed(...)` per `GooeyBlob`. Source rects come from `_ShelfFiltersState._chipRects` (a `Map<_ShelfFilter, Rect>` already measured by `_measureChipRects()`). When the active filter changes, the previous rect is `_chipRects[previousActiveFilter]` and the new rect is `_chipRects[newActiveFilter]`; both are passed as keyframe endpoints to `PositionedActor.keyframed(frames: .fractional([...]))`.
- The trail blob `PositionedActor.keyframed` has the same target rects as main but uses `Actor(delay: 40.ms, reverseDelay: 20.ms, ...)` for the existing lag effect.
- `_MeasureChipRects` and the `_chipRects` map stay unchanged — Cue only reads the existing measurement; the keyframe endpoints are the rects themselves.

**`AudioControlsPill` visibility & grip (`reader_screen.dart:1054-1058 + 985`):**
- Vis wrap: `Cue.onToggle(toggled: widget.isVisible, motion: .bouncy(), acts: storiaActs(c, all: const [.fadeIn(), .scale(to: 1.035)], reduced: const [.fadeIn()]), child: pillSubtree)`.
- Grip handle scaled via `Cue.onToggle(toggled: _isDragging, motion: .snappy(), acts: const [.scale(to: 1.06)], child: gripHandle)`.
- Refactor `_isDragging` from a plain `bool` field to `ValueNotifier<bool>` (the drag-start and drag-end handlers already call `setState`, so the only changes are 6 read sites `if (_isDragging) ` → `if (_isDragging.value)`, 4 write sites `setState(() => _isDragging = true)` → `_isDragging.value = true;` (drop the wrapper `setState` since `ValueNotifier` notifies the bindings itself), and dispose() adds `_isDragging.dispose();`. `Cue.onToggle` watches the `ValueNotifier` via its `Listenable` ancestor.

**New tests:**
- `test/features/library/filter_gooey_indicator_test.dart`: mount `_ShelfFilters` in a router-tested harness, simulate `_ShelfFilter.quick` → `_ShelfFilter.longer` via `widget.onSelected`, pump small steps, assert the indicator rect moves toward the target.
- `test/features/reader/audio_pill_visibility_test.dart`: build `AudioControlsPill` with `isVisible: false`, flip to `true` via parent `setState`, pump, assert `Cue.onToggle` rebuilding and `Actor` present.
- `test/features/reader/audio_pill_drag_scale_test.dart`: simulate `_handlePanStart` via `ValueNotifier`, assert grip subtree's `Cue.onToggle` flips to scale 1.06.

**Playwright:** `recordings/pr4-library-audio-proof.webm` covering: switch shelf filter (see indicator travel); reader → tap screen to hide audio pill → tap to show; drag audio pill (see grip scale up).

### PR 5 — Enrich existing Cue spots

**Word-tap pop (`overlay_text_element.dart:84`):**
- Current: `Cue.onToggle(toggled: token.isTapped, motion: .spring(duration: 220.ms, bounce: 0.35), reverseMotion: .snappy(), acts: const [.scale(to: 1.15)])`.
- New:
```dart
Cue.onToggle(
  key: ValueKey('reader-word-pop-$index'),
  toggled: token.isTapped,
  motion: .smooth(),
  reverseMotion: .snappy(),
  acts: storiaActs(context, all: const [
    ScaleAct.keyframed(
      frames: Keyframes([
        .key(1.0),
        .key(1.18, motion: .bouncy()),
        .key(1.0),
      ], motion: .smooth()),
    ),
    .colorTint(from: Colors.transparent, to: Color.fromRGBO(139, 92, 246, 0.18)),
  ]),
  child: wordWidget,
)
```
- A keyframed scale goes 1.0 → 1.18 (bouncy) → 1.0 so the word punches forward and settles, AND a brief purple tint rides alongside the existing TTS highlight system for emphasis on tap.

**Story Spark choice stagger (`reader_activity_card.dart:_ActivityAnswers`):**
- The outer `Cue.onMount` at `reader_activity_card.dart:161` already animates the card; the inner `_ActivityAnswers` choices appear simultaneously.
- Wrap the tile builder (currently a `for` at line 312 calling `_AnswerTile`) inside `Actor(delay: (i * 60).ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.08)], reduced: storiaReducedEntrance), child: tile)`.
- Same for `_AnswerRow` builder at line 327 — `Actor(delay: (i * 60).ms, ...)`.
- Pass `int displayIndex` into both `_AnswerTile` and `_AnswerRow` (already inside `for (var i = 0; ...)`) — change the existing `i` to use as the displayIndex for the delay.
- Because the parent `Cue.onMount` already creates a `CueScope`, these `Actor`s coordinate under a single trigger (follows the "one Cue per scene" rule).

**Book preview arrow drop (`book_preview_overlay.dart:75`):**
- The `CustomPaint` (`_ArrowPainter`) currently rides along with the parent `Cue.onMount` entrance of the whole card.
- Wrap it in its own `Actor(delay: 100.ms, acts: storiaActs(c, all: const [.fadeIn(), .slideY(from: 0.5)], reduced: storiaReducedEntrance), child: arrow)`. It drops in just after the card lands.
- Lies inside the parent `Cue.onMount` so an `Actor` is valid.

**New tests:**
- `test/features/reader/overlay_text_element_pop_test.dart`: build `OverlayTextElement` with a token whose `isTapped` is true, pump, assert `ScaleAct.keyframed` present and `Keyframes` length 3.
- `test/features/gen_ui/story_spark_choice_stagger_test.dart`: build `_ActivityAnswers` with 4 choices, assert the 4 `Actor`s have increasing `delay`s of 0/60/120/180 ms.
- `test/features/library/book_preview_overlay_arrow_test.dart`: build `BookPreviewOverlay`, pump, assert the arrow `Actor` present with `delay: 100.ms`.

**Playwright:** `recordings/pr5-enrich-proof.webm` covering: tap a reader word (see punch + tint), trigger Story Spark (see staggered choice entrance), tap a library book (see card + arrow stagger).

### PR 6 — Ambient loops (one `AnimationController..repeat()` consolidation pass)

Goal: kill every hand-rolled `AnimationController` + `SingleTickerProviderStateMixin` sine-driven drift, replace with `Cue.onMount(repeat: true, [reverseOnRepeat: true], child: TweenActor<double>(from:, to:, motion: CueMotion.linear(Duration(seconds: X)), builder: ...))`.

**`intro_hero_illustration.dart`:**
- Replace the class's `SingleTickerProviderStateMixin` + `_controller = AnimationController(duration: 6s)..repeat(reverse: true)` + `AnimatedBuilder` with:
```dart
Cue.onMount(
  repeat: true,
  reverseOnRepeat: true,
  motion: .gentle(),
  child: TweenActor<double>(
    from: 0,
    to: math.pi,
    motion: CueMotion.linear(const Duration(seconds: 3)),
    builder: (context, v, _) {
      final dy = math.sin(v) * 6;
      return Transform.translate(
        offset: Offset(0, -dy),
        child: CustomPaint(size: const Size(310, 310), painter: _IntroHeroPainter()),
      );
    },
  ),
)
```
- Drop state class entirely; convert `IntroHeroIllustration` to `StatelessWidget`.
- Remove the class's `dispose()` override.

**`intro_screen.dart`:**
- Same pattern. Replace `_IntroScreenState.SingleTickerProviderStateMixin` + `_controller = AnimationController(duration: 20s)..repeat()` + `AnimatedBuilder(animation: _controller, builder: ...)` containing every cloud / sun / sparkle with one `TweenActor<double>(from: 0, to: 1, motion: CueMotion.linear(Duration(seconds: 20)), repeat: true) ...` builder that re-derives `t`.
- Per-cloud drift uses its own `TweenActor` (`from: 0, to: 1, motion: CueMotion.linear(Duration(seconds: 30 / widget.speed))`) keyed on a phase and an outer `Cue.onMount(repeat: true)` wraps each cloud.
- Sparkles each get a `Cue.onMount(repeat: true)` + `TweenActor` duration 2s with a phase `delay` (Cue supports `delay:` on `Cue.onMount`'s outer timeline — confirm by reading the skill; otherwise use `TweenActor` start offset). Alternative: align sparkles by giving each its own `motion: CueMotion.linear(Duration(seconds: 2))` and a different starting phase knob by binding from `from` differently.
- Keep the Rive `.riv` hero on its own (`Rive` produces its own animation internally).
- Drop `dispose()` override on the screen state.

**`library_screen.dart:_SkyDecorations (1328+)`:**
- Same pattern. `_SkyDecorationsState.SingleTickerProviderStateMixin` + `_t = AnimationController(duration: 120s)..repeat()` driving stars twinkle, sun glow phase, moon bob, and 4 clouds.
- Convert `_SkyDecorations` to `StatelessWidget`. Each celestial child (sun, moon, stars field, 4 clouds) becomes its own `Cue.onMount(repeat: true)` + `TweenActor<double>(from: 0, to: 1, motion: CueMotion.linear(Duration(seconds: 120)), builder: ...)`. The `_StarsPainter`, `_MoonPainter`, `_SunPainter` already take a `t` parameter; the `TweenActor` builder passes `t` straight through.
- Cloud durations derived from existing `speed` per-cloud — keep the existing `_CloudSpec` constants.

**New tests:**
- `test/features/auth/intro_hero_illustration_loop_test.dart`: build `IntroHeroIllustration`, pump, assert `TweenActor` present, no `AnimationController` symbols in subtree.
- `test/features/auth/intro_screen_loop_test.dart`: build `IntroScreen` (fake or stub), pump, assert multiple `Cue.onMount` with `repeat: true` present.
- `test/features/library/sky_decorations_loop_test.dart`: build `_SkyDecorations`, assert no `AnimationController` symbols in subtree; multiple `TweenActor`s present.

**Playwright:** `recordings/pr6-ambient-proof.webm` capturing 10s of intro screen shows clouds drifting near and far; library screen shows stars twinkling + moon bob over 10s.

### PR 7 — Reader PageView (drop `flutter_animate`)

**`reader_screen.dart:35 _pageController`:** rename type `PageController` → `CuePageController`:
```dart
final CuePageController _pageController = CuePageController();
```
`CuePageController` is a `PageController` subclass, so `_pageController.page`, `_pageController.addListener(_onPageScroll)`, `_pageController.removeListener`, `_pageController.dispose()` all keep working.

**`reader_screen.dart:161 PageView.builder`:**
```dart
PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  itemCount: book.pages.length,
  onPageChanged: (index) => unawaited(c.dispatch(ReaderExperiencePageChanged(index))),
  itemBuilder: (context, index) {
    final isInVirtualizationWindow = (index - activeIndex).abs() <= 1;
    if (!isInVirtualizationWindow) return const SizedBox.shrink();
    final page = book.pages[index];
    final pageRenderer = /* ... existing ValueListenableBuilder<Duration> ... */;
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      child: pageRenderer,
      builder: (context, scrollOffset, child) {
        /* existing localOffset / progress / ClipPath ... */
        return ClipPath(clipper: VerticalLiquidClipper(progress:, revealFromTop:), child: child!);
      },
    );
  },
)
```
Wrap the returned `ClipPath` in `Cue.indexed(controller: _pageController, index: index, child: clipPath)` so the per-page entrance (page image and text stagger) is driven by Cue's indexed controller:
```dart
return Cue.indexed(
  controller: _pageController,
  index: index,
  child: ClipPath(...),
);
```

**`page_renderer.dart:6 import 'package:flutter_animate/flutter_animate.dart';`** — removed.

**`page_renderer.dart:309 (the text content):**
- Remove `.animate(target: widget.isActive ? 1 : 0).fadeIn(delay: 120.ms, duration: 340.ms, curve: Curves.easeOut).slideY(begin: 0.08, end: 0, delay: 120.ms, duration: 340.ms, curve: Curves.easeOutCubic)` chain.
- Wrap the `Text` widget in an `Actor(acts: storiaActs(context, all: const [.fadeIn(), .slideY(from: 0.08)], reduced: storiaReducedEntrance))`. This `Actor` picks up the nearest `CueScope` from `Cue.indexed` in the parent screen automatically.

**`reader_screen.dart:360 AnimatedOpacity` on the page image (`_buildPageImage` line 360):** This is a fade-in-when-frame-ready micro-interaction, déjà interior to the page renderer. Convert to `Cue.onToggle(toggled: frame != null, motion: .smooth(), acts: const [.fadeIn()])`. Or — simpler — keep the `AnimatedOpacity` here since it's a per-frame cache stampede and not an entrance animation in the Cue sense. **Decision: leave it.** `AnimatedOpacity` for image-frame-ready is a micro-interaction that's a poor Cue fit (high rebuild frequency); we explicitly scope this PR to the `flutter_animate` removal + page entrance indexing, not to kill every Flutter-builtin `Animated*` widget. Note this exemption in the PR description.

**pubspec.yaml:**
- Remove line 56: `  flutter_animate: ^4.5.2`.
- Run `flutter pub get` (drops ~12 transitive deps).

**AGENTS.md:**
- Line 64 already updated in PR 0 list of animation deps; double-check `flutter_animate` doesn't appear anywhere else.

**New tests:**
- `test/features/reader/page_controller_indexed_test.dart`: build a minimal `ReaderScreen` with a stub 2-page book, assert per-page Cue indexed `Actor`s present, simulate drag via `pageController.jumpToPage(1)` and assert the second page's `Actor` rebuilds on the new index.
- `test/features/reader/page_renderer_text_entrance_test.dart`: build `PageRenderer` inside a `Cue.indexed` parent, pump, assert `Actor` with `slideY(from: 0.08)` present, no `flutter_animate` symbols reachable from `PageRenderer`.
- `test/features/reader/no_flutter_animate_import_test.dart` (a sentinel runner-style test): opens `lib/src/features/reader/page_renderer.dart`, asserts `package:flutter_animate` is not imported.

**Playwright:** `recordings/pr7-readerview-proof.webm` covering open a book → swipe between two pages (see image + text stagger per page), tap a word (pop continues to work post-migration).

## Net dep change

- `cue: ^0.2.1` → `cue: ^0.2.2` (PR 0).
- `flutter_animate: ^4.5.2` removed (PR 7).
- No other dependency added or removed.

## Out-of-scope / explicit exemptions

- `AnimatedOpacity` in `page_renderer.dart` (`_buildPageImage` line 360) — kept. Reason: per-frame cache-stampede micro-interaction, not an entrance animation, and replacing it with Cue would not improve clarity.
- `Hero` animation linking library → reader covers (`page_renderer.dart:376`, `_buildPageImage`) — kept as Flutter built-in. Hero is a route-level transition primitive, distinct from Cue's scope (Cue does not own modal route transitions of this flavor).
- `Confetti` celebration (`reader_screen.dart:312`) — kept, distinct domain (game-feel particle effect), out of Cue consolidation.
- `Rive` `.riv` hero animation (`intro_screen.dart:201`) — kept, Rive owns its own animation engine; Cue only needs to host it.
- `Gooey` library (audio pill wobble, filter indicator trail) — kept, Gooey is a custom-painter continuous-deformation library, not an animation trigger; Cue now drives the LAYOUT transitions around Gooey blobs (PR 4) but Gooey still owns its blob outline.
- `gooey_edge.dart` liquid swipe transition (Flame reader) — distinct, kept; PR 7's Cue.indexed coordinates page entrance but the liquid clip effect itself is a `CustomClipper`, not in Cue's domain.

## Verification per PR

Every PR ships with:
- `flutter analyze` clean (zero warnings, per `AGENTS.md`).
- `flutter test` passing for the new test file(s) added in the PR.
- A `recordings/pr<N>-<area>-proof.webm` Playwright proof capturing the UI surface touched by the PR, following AGENTS.md's Playwright CLI flow.

The PR description includes:
- Before/after screenshot timestamps within the WebM.
- The reduced-motion path is verified in at least one PR's proof (PR 0 + one mid-sequence PR like PR 4) by passing `--dart-define=STORIA_REDUCE_MOTION=1` or `flutter run -d chrome --web-renderer canvaskit` with reduced-motion preference toggled; the reduced WebM is `pr<N>-reduce-proof.webm`.

## Risk register

- **PR 7 risk (PageView)** — `CuePageController` + `Cue.indexed` is the most novel part of the migration and the reader is the user-critical surface. Mitigation: land last when the team has Cue fluency; the PR is sequenced so it can be reverted (just re-add `flutter_animate ^4.5.2`, restore `PageController`, restore the import + chain) without rolling back PRs 1–6.
- **PR 4 risk (audio pill `_isDragging` `ValueNotifier` refactor)** — touches drag hot-path. Mitigation: keep public API of `AudioControlsPillState` (used by parent `ReaderScreen` for visibility través `AudioControlsPill(isVisible:, ...)`) untouched; only internal `_isDragging` field shape changes.
- **PR 6 risk (ambient loop regression)** — replacing the 20s `AnimationController..repeat()` with `TweenActor` could subtly change cloud speeds. Mitigation: per-cloud `TweenActor` duration matches existing math (`30 / widget.speed` seconds) so the visual speed is preserved; verification is the 10s Playwright proof side-by-side with the old behavior.
- **Reduced-motion coverage** — the `storiaActs` helper defaults to `.fadeIn()` everywhere, but large `.bouncy()` gestures (word pop, default badge, audio pill) might want a stronger reduced fallback. The `reduced:` argument is final per PR call site — the plan calls for the writer to pass `storiaReducedEntrance` (fade + 0.06 slide) where the full act slides up, and `const [.fadeIn()]` where the full act is purely scale, so reduced motion still reads visible activity without traveling.

## Acceptance criteria

- `rg "package:flutter_animate" lib/` returns nothing.
- `rg "AnimatedOpacity|AnimatedScale|AnimatedPositioned|AnimatedContainer|AnimatedDefaultTextStyle" lib/` returns at most the single exemption in `page_renderer.dart:360` (frame-ready fade).
- `rg "AnimationController|TickerProviderStateMixin|SingleTickerProviderStateMixin" lib/` returns nothing.
- `rg "storiaActs" lib/src/` returns at least 8 distinct call sites across the 7 feature PRs.
- `flutter analyze` zero warnings.
- `flutter test` suite-wide pass; eight new test files added; existing tests still pass.
- `pubspec.yaml` no longer lists `flutter_animate`.
- `cue: ^0.2.2` pinned.
- `recordings/pr0-proof.webm`, `pr1-proof.webm`, … `pr7-proof.webm` exist and show the expected flows.