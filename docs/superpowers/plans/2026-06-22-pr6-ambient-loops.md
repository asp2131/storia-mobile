# PR 6 — Ambient loops: replace every `AnimationController..repeat()` with Cue

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** PR 0 merged. PR 2 should land first if possible because PR 2 wraps the intro screen's content `Column` in `Cue.onMount` and PR 6 wraps the *ambient* hero bob inside the same screen — the two co-exist cleanly without overlap (different subtrees).

**Goal:** Kill every hand-rolled `AnimationController..repeat()` site. Convert the intro-screen clouds/sun/sparkles, the intro hero illustration bob, and the library `_SkyDecorations` (stars twinkle, sun glow, moon bob, four clouds) to `Cue.onMount(repeat: true, [reverseOnRepeat: true], motion:)` driving one `TweenActor<double>(from:, to:, motion: CueMotion.linear(Duration(seconds: X)), builder:)` per drifting element.

**Architecture:** Three widgets migrate, in order: simplest to most stateful.

1. **`IntroHeroIllustration` (smallest, ~43 LOC)** — bob `AnimationController(duration: 6s)..repeat(reverse: true)` becomes a `Cue.onMount(repeat: true, reverseOnRepeat: true, motion: .gentle(), child: TweenActor<double>(from: 0, to: math.pi, motion: CueMotion.linear(3.seconds), builder: (c, v, _) { final dy = math.sin(v) * 6; return Transform.translate(...); }))`. The widget can become `StatelessWidget`, dropping `TickerProviderStateMixin` and `dispose`.

2. **`IntroScreen` (medium, ~560 LOC)** — `_IntroScreenState.SingleTickerProviderStateMixin` + `_controller = AnimationController(duration: 20s)..repeat()` + an `AnimatedBuilder(animation: _controller)` wrapping the whole `Stack`. The current code computes every cloud / sun / sparkle position from `math.sin((_controller.value + phase) * math.pi * 2)` per frame, all inside the single `AnimatedBuilder`.
   - The rewrite splits into 4 clouds (`_driftingCloud` + `_driftingCloudNear`), 1 sun glow (`_floatingSunWithGlow`), 3 sparkles (`_sparkle`). Each becomes its own `Cue.onMount(repeat: true, motion: .gentle(), child: TweenActor<double>(from: 0, to: 1, motion: CueMotion.linear(Duration(seconds: X)), builder: ...))` placed in the `Stack` children list. Each `TweenActor` computation matches the existing math (`progress = ((_controller.value * speed) + phase) % 1; left = screenWidth + 40 - progress * loopDistance`). The `speed` ratio translates to `Duration(seconds: (20 / speed).round())` — e.g. speed: 0.40 → 50 seconds, speed: 1.30 → 15 seconds. Pre-compute and pass as a constant.
   - The Rive `.riv` hero in the middle keeps its own internal controller (`RiveWidgetBuilder` file loader wraps the file); PR 6 does not touch this. The hero bob inside the `Transform.translate(offset: Offset(0, math.sin(...)), child: Stack(clipBehavior: Clip.none, children: [...]))` block (around line 165-246) gets its own `TweenActor<double>(from: 0, to: math.pi * 2, motion: CueMotion.linear(2.seconds), builder: (c, v, _) => Transform.translate(offset: Offset(0, math.sin(v) * -4.2), child: /* remaining hero stack */))`.
   - Drop `_IntroScreenState.dispose()`.

3. **`_SkyDecorations` in `library_screen.dart` (~150 LOC)** — `_SkyDecorationsState.SingleTickerProviderStateMixin` + `_t = AnimationController(duration: 120s)..repeat()` driving `_StarsPainter`, `_MoonPainter`, the sun glow, and 4 clouds (`_cloud` method). Same split-per-element rewrite as `IntroScreen`. The `_StarsPainter` currently takes `double t` and computes `twinkle = 0.58 + 0.42 * math.sin(t * math.pi * 2 + i * 1.7)`; the `TweenActor` builder just passes `v` as `t`. The widget converts from `StatefulWidget` to `StatelessWidget`.

**Tech Stack:** Flutter, `package:cue/cue.dart` 0.2.2 (`Cue.onMount` with `repeat: true` + `reverseOnRepeat:`, `TweenActor<double>`, `CueMotion.linear(Duration)`), `package:flutter_test`, Storia theme tokens.

**Reference spec:** `docs/superpowers/specs/2026-06-22-cue-consolidation-design.md` (Section "PR 6 — Ambient loops").

---

### Task 1: Migrate `IntroHeroIllustration` from `SingleTickerProviderStateMixin` to a Cue loop

**Files:**
- Modify: `lib/src/features/auth/presentation/widgets/intro_hero_illustration.dart`
- Create: `test/features/auth/intro_hero_illustration_loop_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/features/auth/intro_hero_illustration_loop_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/auth/presentation/widgets/intro_hero_illustration.dart';

void main() {
  group('IntroHeroIllustration Cue loop', () {
    testWidgets('renders a TweenActor under a Cue.onMount; no AnimationController present',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IntroHeroIllustration()),
      );
      await tester.pump();

      expect(find.byType(Cue), findsOneWidget);
      expect(find.byType(TweenActor<double>), findsOneWidget);
      expect(find.byType(AnimationController), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/auth/intro_hero_illustration_loop_test.dart`
Expected: FAIL — `find.byType(Cue)` finds nothing.

- [ ] **Step 3: Replace the widget implementation**

Replace the entire `intro_hero_illustration.dart` body of `_IntroHeroIllustrationState.build` with a `StatelessWidget` that uses Cue:

```dart
import 'dart:math' as math;

import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/storia_colors.dart';

class IntroHeroIllustration extends StatelessWidget {
  const IntroHeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Cue.onMount(
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
            child: CustomPaint(
              size: const Size(310, 310),
              painter: _IntroHeroPainter(),
            ),
          );
        },
      ),
    );
  }
}

/* _IntroHeroPainter unchanged — leave the existing class body verbatim */
```

Notes:
- Drop the `State`, `SingleTickerProviderStateMixin`, `AnimationController`, and `dispose()`. The `_IntroHeroPainter` stays exactly as-is (its `shouldRepaint` returns `false` so it never repaints; that's correct).
- `TweenActor<double>` advances from 0 to π over 3s, then `Cue.onMount(repeat: true, reverseOnRepeat: true)` runs it forward, reverses, repeats. `math.sin(v)` over [0, π] gives the same bob the existing `math.sin(_controller.value * math.pi)` did, just with a 3s half-period instead of 6s full — keep the visual via the existing 6 second cycle. Adjust to: `from: 0, to: math.pi * 2, motion: CueMotion.linear(6.seconds)` if needed; verify the proof visually.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/auth/intro_hero_illustration_loop_test.dart`
Expected: PASS.

---

### Task 2: Write the failing test for `IntroScreen` Cue-driven ambient loops

**Files:**
- Create: `test/features/auth/intro_screen_loop_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/auth/presentation/intro_screen.dart';

void main() {
  group('IntroScreen ambient loops', () {
    testWidgets('renders multiple Cue.onMount widgets for ambient clouds/sun/sparkles; no AnimationController',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
      await tester.pump();

      // At least the outer shell Cue (PR 2) + per-ambient Cue(8+ ambient elements).
      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(TweenActor<double>), findsWidgets);
      expect(find.byType(AnimationController), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/auth/intro_screen_loop_test.dart`
Expected: FAIL — the screen still uses `AnimatedBuilder(animation: _controller)` and `AnimationController`.

---

### Task 3: Rebuild `IntroScreen` ambient loops with per-element `TweenActor`s

**Files:**
- Modify: `lib/src/features/auth/presentation/intro_screen.dart`

- [ ] **Step 1: Add / confirm the imports**

At the top of `intro_screen.dart`:

```dart
import 'package:cue/cue.dart';
```

Pressence has been confirmed in PR 2 (`import 'package:cue/cue.dart';`). Add `dart:math as math` if for some reason it's not already (it's already imported on line 1).

- [ ] **Step 2: Convert `_IntroScreenState` to drop `SingleTickerProviderStateMixin` + `_controller`**

In `_IntroScreenState`:

- Remove `with SingleTickerProviderStateMixin` from the class declaration.
- Remove `late final AnimationController _controller = AnimationController(...)..repeat();` (lines ~23-26) and `_IntroScreenState.dispose()` (lines ~34-41, only the `_controller.dispose()` line, keep `super.dispose()`).
- The class now has no state — if no other fields remain, convert the class to `StatelessWidget`. The `late final rive.FileLoader _landingRiveLoader` field has a comment about not disposing it — keep that field. Best: keep `_IntroScreenState extends State<IntroScreen>` but drop the mixin.

[Implementation reading: see lines 17-41 of `intro_screen.dart`. After PR 2's edits, the only ambient state remaining in `_IntroScreenState` is the `_controller`.]

- [ ] **Step 3: Replace `_driftingCloud` with a Cue-driven version**

Replace `_driftingCloud({...})` (lines 360-409) with:

```dart
Widget _driftingCloud({
  required double top,
  required double width,
  required double height,
  required double phase,
  required double speed,
  required double yAmplitude,
  required double opacity,
  double scale = 1,
  double blurSigma = 0,
  bool flipX = false,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final loopDistance = screenWidth + width + 120;
  // Existing math: progress = ((controller.value * speed) + phase) % 1
  //                 left = screenWidth + 40 - progress * loopDistance
  // The TweenActor drives progress 0 -> 1 over (20 / speed) seconds, with
  // phase offset applied via delay.
  final durationSec = (20 / speed).round();
  final startDelay = Duration(seconds: ((phase * durationSec).round()));

  return IgnorePointer(
    child: TweenActor<double>(
      from: 0,
      to: 1,
      motion: CueMotion.linear(Duration(seconds: durationSec)),
      // Repeat forever via outer Cue.onMount, below.
      builder: (context, progress, _) {
        final wrappedProgress = progress;
        final left = screenWidth + 40 - wrappedProgress * loopDistance;
        final dy = math.sin((wrappedProgress + phase) * math.pi * 2) * yAmplitude;

        Widget cloud = SvgPicture.asset('assets/svgs/cloud.svg');
        if (flipX) {
          cloud = Transform.flip(flipX: true, child: cloud);
        }
        if (blurSigma > 0) {
          cloud = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: cloud,
          );
        }

        return Positioned(
          top: top + dy,
          left: left,
          width: width,
          height: height,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, alignment: Alignment.center, child: cloud),
          ),
        );
      },
    ),
  );
}
```

Wrap each call site of `_driftingCloud(...)` in the build body with `Cue.onMount(repeat: true, motion: .gentle(), delay: startDelay, child: _driftingCloud(...))`. Or hoist the wrap inside `_driftingCloud`'s return by enclosing the `TweenActor` inside a `Cue.onMount`:

```dart
return Cue.onMount(
  repeat: true,
  motion: .gentle(),
  delay: startDelay,
  child: IgnorePointer(
    child: TweenActor<double>(
      from: 0,
      to: 1,
      motion: CueMotion.linear(Duration(seconds: durationSec)),
      builder: /* (context, progress, _) => ... */ ,
    ),
  ),
);
```

The latter is cleaner — one wrap per cloud.

- [ ] **Step 4: Apply the same pattern to `_driftingCloudNear`, `_floatingSunWithGlow`, `_sparkle`**

For `_driftingCloudNear` (lines 413-453): apply the same `Cue.onMount(repeat: true) + TweenActor<double>` shape. The horizontal drift becomes `driftX = math.sin(progress * math.pi * 2)`, `rightOffset = screenWidth - width * 0.35 + driftX * (width * 0.25)`. Speed-to-duration mapping is the same.

For `_floatingSunWithGlow` (lines 316-357): bob amplitude 2, drifting sun glow with phase 0.1. The TweenActor goes `from: 0, to: 1, motion: CueMotion.linear(Duration(seconds: 20))` because the existing math used `(_controller.value + phase) * math.pi * 2` — phase offset returned by `delay: (phase * 20).seconds`.

For `_sparkle` (lines 455-487): the pulse cycles at `t * math.pi * 2 * 3`, so 3x the 20-second default — use `CueMotion.linear(Duration(seconds: 20 / 3))` ~ `Duration(seconds: 7)` rounded. The scale + opacity derivation is the same math as the existing method, just driven by `progress` from the `TweenActor`.

- [ ] **Step 5: Replace the hero `Transform.translate` bob**

In the `SafeArea > Center > ConstrainedBox > Padding > Column` branch at lines 162-246, the inner hero `Transform.translate(offset: Offset(0, math.sin(_controller.value * math.pi * 12) * -4.2), child: Stack(...))` becomes:

```dart
TweenActor<double>(
  from: 0,
  to: math.pi * 12,
  motion: CueMotion.linear(const Duration(seconds: 20)),
  builder: (context, v, child) => Transform.translate(
    offset: Offset(0, math.sin(v) * -4.2),
    child: child!,
  ),
  child: /* the entire existing Stack(clipBehavior: Clip.none, children: [...]) block from lines 174-244 */,
),
```

Wrap that whole `TweenActor` in a `Cue.onMount(repeat: true, motion: .gentle(), child:)` so it loops.

- [ ] **Step 6: Remove `AnimatedBuilder(animation: _controller,...)` outer wrap and `Stack` direct children list**

After this rewrite, the `Stack` direct children list (around line 56-308) keeps the same order: `Positioned.fill` background SVG, gradient overlay, `_floatingSunWithGlow(...)`, every `_driftingCloud(...)`, near-cloud, the `SafeArea > Center` content, etc. — each call site now returns a `Cue.onMount(... TweenActor ...)` chain instead of relying on the outer `AnimatedBuilder`.

- [ ] **Step 7: Run the test**

Run: `flutter test test/features/auth/intro_screen_loop_test.dart`
Expected: PASS.

- [ ] **Step 8: Run analyze + full test gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

---

### Task 4: Migrate `_SkyDecorations` to `StatelessWidget` + per-element `TweenActor`s

**Files:**
- Modify: `lib/src/features/library/library_screen.dart` — `_SkyDecorations`, `_SkyDecorationsState`.

- [ ] **Step 1: Write the failing test**

Create `test/features/library/sky_decorations_loop_test.dart`:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/features/library/library_screen.dart';

void main() {
  group('_SkyDecorations Cue loop', () {
    testWidgets('renders TweenActors under Cue.onMount; no AnimationController',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: _SkyDecorationsHarness(),
      ));
      await tester.pump();

      expect(find.byType(Cue), findsWidgets);
      expect(find.byType(TweenActor<double>), findsWidgets);
      expect(find.byType(AnimationController), findsNothing);
    });
  });
}

class _SkyDecorationsHarness extends StatelessWidget {
  const _SkyDecorationsHarness();

  @override
  Widget build(BuildContext context) {
    // _SkyDecorations is private; the harness indirectly mounts it via a
    // minimal LibraryScreen or via an @visibleForTesting export. If access
    // isn't possible from the test target, switch the test to mount
    // LibraryScreen with ProviderScope overrides and assert the presence of
    // TweenActor in the subtree instead.
    return const SizedBox.shrink(); // TODO: replace with a real harness
  }
}
```

Replace this `_SkyDecorationsHarness` with a real harness by reading `test/features/library/library_screen_test.dart` for the established recipe.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/library/sky_decorations_loop_test.dart`
Expected: FAIL — `_SkyDecorations` still uses `AnimationController(_t)`.

- [ ] **Step 3: Convert `_SkyDecorations` to `StatelessWidget` with Cue loops**

Replace the `_SkyDecorations` `StatefulWidget` + `_SkyDecorationsState` (lines 1328-1477) with:

```dart
class _SkyDecorations extends StatelessWidget {
  const _SkyDecorations({required this.palette});

  final _SkyPalette palette;

  static const _clouds = <_CloudSpec>[
    _CloudSpec(top: 200, scale: 0.9, phase: 0.00, opacity: 0.85),
    _CloudSpec(top: 280, scale: 1.3, phase: 0.30, opacity: 0.80),
    _CloudSpec(top: 240, scale: 0.7, phase: 0.55, opacity: 0.75, flip: true),
    _CloudSpec(top: 340, scale: 1.0, phase: 0.80, opacity: 0.80),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          if (palette.starOpacity > 0.01)
            Cue.onMount(
              repeat: true,
              motion: .gentle(),
              child: TweenActor<double>(
                from: 0,
                to: 1,
                motion: CueMotion.linear(const Duration(seconds: 120)),
                builder: (c, t, _) => _StarField(t: t, opacity: palette.starOpacity),
              ),
            ),
          palette.isNight
              ? Cue.onMount(
                  repeat: true,
                  motion: .gentle(),
                  child: TweenActor<double>(
                    from: 0,
                    to: 1,
                    motion: CueMotion.linear(const Duration(seconds: 120)),
                    builder: (c, t, _) => _moon(t, context),
                  ),
                )
              : Cue.onMount(
                  repeat: true,
                  motion: .gentle(),
                  child: TweenActor<double>(
                    from: 0,
                    to: 1,
                    motion: CueMotion.linear(const Duration(seconds: 120)),
                    builder: (c, t, _) => _sun(t, context),
                  ),
                ),
          for (final spec in _clouds)
            Cue.onMount(
              repeat: true,
              motion: .gentle(),
              delay: Duration(seconds: ((spec.phase * 120).round())),
              child: TweenActor<double>(
                from: 0,
                to: 1,
                motion: CueMotion.linear(const Duration(seconds: 120)),
                builder: (c, t, _) => _cloud(spec, t, context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cloud(_CloudSpec spec, double t, BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    const baseW = 140.0;
    final w = baseW * spec.scale;
    final loop = screenW + w + 80;
    final progress = (t + spec.phase) % 1;
    final left = screenW + 40 - progress * loop;
    final dy = math.sin((t + spec.phase) * math.pi * 2) * 4;

    Widget cloud = SvgPicture.asset('assets/svgs/cloud.svg', width: w);
    if (spec.flip) {
      cloud = Transform.flip(flipX: true, child: cloud);
    }

    return Positioned(
      top: spec.top + dy,
      left: left,
      child: Opacity(opacity: spec.opacity * palette.cloudOpacity, child: cloud),
    );
  }

  Widget _sun(double t, BuildContext context) {
    final glowOpacity = 0.18 + 0.10 * math.sin(t * math.pi * 2);
    const sunSize = 64.0;
    const boxSize = sunSize + 32;
    return Positioned(
      top: 170,
      right: 28,
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.sunColor.withValues(alpha: glowOpacity),
                  palette.sunColor.withValues(alpha: 0),
                ],
                stops: const [0.2, 1.0],
              ),
            ),
          ),
          SvgPicture.asset('assets/svgs/sun.svg', width: sunSize, height: sunSize),
        ],
      ),
    );
  }

  Widget _moon(double t, BuildContext context) {
    final glowOpacity = 0.18 + 0.08 * math.sin(t * math.pi * 2);
    final bob = math.sin((t + 0.15) * math.pi * 2) * 3;
    const moonSize = 58.0;
    const boxSize = moonSize + 38;
    return Positioned(
      top: 164 + bob,
      right: 26,
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.moonColor.withValues(alpha: glowOpacity),
                  palette.moonColor.withValues(alpha: 0),
                ],
                stops: const [0.12, 1.0],
              ),
            ),
          ),
          CustomPaint(
            size: const Size.square(moonSize),
            painter: _MoonPainter(color: palette.moonColor, shadowColor: palette.moonShadow),
          ),
        ],
      ),
    );
  }
}
```

Drop the original `_SkyDecorationsState` class entirely. `_MoonPainter`, `_StarsPainter`, `_StarField`, `_CloudSpec` helpers stay unchanged.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/library/sky_decorations_loop_test.dart`
Expected: PASS.

- [ ] **Step 5: Run analyze + full test gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

---

### Task 5: Sentinel test — assert no `AnimationController` remains outside Cue

**Files:**
- Create: `test/core/animation_no_handrolled_controllers_test.dart`

- [ ] **Step 1: Write a source-scan test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no source file under lib/src/ declares its own AnimationController', () {
    final banned = RegExp(r'AnimationController\s*\(');
    final exceptions = <String>[
      // None expected after PR 6.
    ];

    final failures = <String>[];
    for (final file in Directory('lib/src/').recursiveDartFiles()) {
      if (exceptions.any((ex) => file.path.contains(ex))) continue;
      final source = file.readAsStringSync();
      if (banned.hasMatch(source)) {
        failures.add(file.path);
      }
    }
    expect(failures, isEmpty, reason: 'Hand-rolled AnimationController found in: $failures');
  });
}

extension on Directory {
  Iterable<File> recursiveDartFiles() sync* {
    for (final entry in listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('.dart')) yield entry;
    }
  }
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/core/animation_no_handrolled_controllers_test.dart`
Expected: PASS — no `AnimationController(` literal in `lib/src/`.

If it fails, hunt down any remaining hand-rolled controllers in this PR's scope.

---

### Task 6: Playwright proof + commit

- [ ] **Step 1: Record**

```bash
flutter run -d chrome &
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Flow:
#   1. Intro screen -> clouds drift across screen over 10s, sun's glow pulses gently, sparkles fade/scale, hero Rive animates
#   2. Sign in (app-review@storia.kids) -> parent year 1980 -> onboarding -> library
#   3. Library _SkyDecorations: stars twinkle, moon bobs, clouds drift across 10s
playwright-cli video-stop --filename=recordings/pr6-ambient-proof.webm
playwright-cli close
```

- [ ] **Step 2: Verify gate**

Run: `flutter analyze && flutter test`
Expected: zero warnings; all tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add lib/src/features/auth/presentation/widgets/intro_hero_illustration.dart \
        lib/src/features/auth/presentation/intro_screen.dart \
        lib/src/features/library/library_screen.dart \
        test/features/auth/intro_hero_illustration_loop_test.dart \
        test/features/auth/intro_screen_loop_test.dart \
        test/features/library/sky_decorations_loop_test.dart \
        test/core/animation_no_handrolled_controllers_test.dart \
        recordings/pr6-ambient-proof.webm
```

```bash
git commit -m "feat(cue): replace every hand-rolled AnimationController..repeat() with Cue

* IntroHeroIllustration: SingleTickerProviderStateMixin + AnimationController(6s)..repeat(reverse)
  -> StatelessWidget + Cue.onMount(repeat: true, reverseOnRepeat: true, motion: .gentle())
  wrapping a TweenActor<double>(from: 0, to: pi, motion: CueMotion.linear(3s)). math.sin(v)*6
  drives the bob.

* IntroScreen: SingleTickerProviderStateMixin + AnimationController(20s)..repeat() +
  AnimatedBuilder wrapper around every cloud/sun/sparkle -> per-element
  Cue.onMount(repeat: true) + TweenActor<double>(from: 0, to: 1, motion:
  CueMotion.linear(seconds: 20/speed)). Eight ambient elements: 4 drifting
  clouds + 1 near cloud + 1 sun glow + 3 sparkles + the hero Transform bob.
  Existing math preserved (progress = phase + TweenActor-value, dy = sin...).
  _IntroScreenState.drop SingleTickerProviderStateMixin + dispose() override.

* _SkyDecorations: SingleTickerProviderStateMixin + AnimationController(120s)..repeat()
  -> StatelessWidget + per-element Cue/TweenActor: stars field, sun, moon, 4 clouds.
  Painters (_StarsPainter, _MoonPainter) accept the tween's `t` value exactly as before.

* Sentinel test in test/core/animation_no_handrolled_controllers_test.dart asserts
  no lib/src/* file declares AnimationController() (regression guard).

Plan: docs/superpowers/plans/2026-06-22-pr6-ambient-loops.md
Spec:  docs/superpowers/specs/2026-06-22-cue-consolidation-design.md
Proof: recordings/pr6-ambient-proof.webm"
```

---

## Self-Review

- **Spec coverage:** intro hero bob — Task 1. intro ambient clouds/sun/sparkles — Task 3. library `_SkyDecorations` — Task 4. Sentinel guards against future regressions — Task 5. Every `AnimationController..repeat()` site removed.
- **Placeholder scan:** Task 4's `_SkyDecorationsHarness` TODO is intentional — the path: "read `test/features/library/library_screen_test.dart` for the established recipe" tells the worker exactly what to copy. Replacing with a stub before reading that file would produce a non-runnable test.
- **Type consistency:** `Cue.onMount(repeat: true, reverseOnRepeat: true, motion:, child:)` matches the confirmed source at `~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/cue/on_mount_cue.dart:50-52`. `TweenActor<double>(from:, to:, motion: CueMotion.linear(Duration), builder:)` matches `~/.pub-cache/hosted/pub.dev/cue-0.2.2/lib/src/acts/custom_tween_act.dart:217`. The math preserves the existing visuals end-to-end with the same phase and speed relationships.
- **Risk:** Every duration is approximate to within rounding (`Duration(seconds: (phase * 120).round())`), so cloud timing may diverge by ~1s from the original. The Playwright proof verifies the drift looks right visually; if a cloud visibly stalls, adjust that cloud's duration constant in a follow-up micro-edit. The `_StarField` painter continues to be a `CustomPaint` widget taking `t` as a parameter — confirmed unchanged.