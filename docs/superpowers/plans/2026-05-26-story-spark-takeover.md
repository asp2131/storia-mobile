# Story Spark Takeover + Mid-Passage Triggering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reposition the gen-AI "Story Spark" activity into a focused, centered takeover with adaptive answers and smooth pause/resume narration, and retime it to fire mid-passage at a per-card word anchor.

**Architecture:** A per-card optional `anchorWordIndex` drives a pure trigger predicate (`isActivityLive`). During read-aloud the card goes live when the active narrated word (`computeActiveWordIndex(narrationTimestamps, narrationPosition)`) reaches the anchor; otherwise (null anchor or narration off / self-read MVP) it goes live on page load. The overlay becomes a full-screen scrim + centered card that dispatches explicit `ReaderExperienceActivityShown`/`ActivityDismissed` actions to pause/restore narration only when needed (mirroring the existing practice-mode pattern).

**Tech Stack:** Flutter, Riverpod (`StateNotifier`/`Provider.family`), `cue` 0.2.1 for animation, existing `Sketch*` widgets + `Storia*` theme tokens.

**Spec:** `docs/superpowers/specs/2026-05-26-story-spark-takeover-design.md`

**Conventions (verified in codebase):**
- Run a single test file: `flutter test test/path/to/file_test.dart`
- Run one test by name: `flutter test --plain-name 'test description' test/path/to/file_test.dart`
- Analyze: `flutter analyze`
- Theme tokens: `StoriaColors.paperRaised`, `.ink`, `.inkMuted`, `.mustard`, `.mustardDeep`; spacing `StoriaSpacing.{xs,sm,md,lg,xl}`; motion `StoriaMotion.{quick=180ms,medium=280ms}`, curve `StoriaMotion.emphasized`.
- Narration highlight index is `computeActiveWordIndex(page.narrationTimestamps, narrationPosition)` from `lib/src/features/reader/overlay/text_overlay_utils.dart`. `spokenWordIndices` is speech-practice state — do NOT use it for narration.

---

## File Structure

**Create:**
- `lib/src/features/gen_ui/domain/reader_activity_trigger.dart` — pure `isActivityLive(...)` predicate.
- `test/features/gen_ui/domain/reader_activity_trigger_test.dart`
- `test/features/gen_ui/presentation/reader_activity_card_test.dart`
- `test/features/reader/runtime/reader_session_narration_pause_test.dart`

**Modify:**
- `lib/src/features/gen_ui/domain/gen_ui_card_schema.dart` — add `anchorWordIndex`.
- `lib/src/features/gen_ui/data/mock_gen_ui_cards.dart` — add anchor indices.
- `lib/src/features/reader/runtime/reader_session.dart` — add `ReaderPauseNarration`/`ReaderResumeNarration` intents.
- `lib/src/features/reader/runtime/reader_session_impl.dart` — handle the two intents.
- `lib/src/features/reader/application/reader_experience_controller.dart` — add `ReaderExperienceActivityShown`/`ActivityDismissed` actions + `activityNarrationPaused` state field.
- `lib/src/features/gen_ui/presentation/reader_activity_card.dart` — full-screen takeover + adaptive answers + audio dispatch + animation.
- `lib/src/features/reader/reader_screen.dart` — update overlay mount (pass narration inputs, drop `bottomInset`).
- `test/features/gen_ui/domain/gen_ui_schema_test.dart` — anchor parse test.

---

## Task 1: Add `anchorWordIndex` to the card schema

**Files:**
- Modify: `lib/src/features/gen_ui/domain/gen_ui_card_schema.dart`
- Test: `test/features/gen_ui/domain/gen_ui_schema_test.dart`

- [ ] **Step 1: Write the failing test**

Append inside the existing `group('GenUiCardSchema validation', ...)` in `test/features/gen_ui/domain/gen_ui_schema_test.dart`:

```dart
    test('parses anchorWordIndex from snake_case and camelCase', () {
      final snake = GenUiCardSchema.fromJson({
        'id': 'a-1',
        'surface': 'reader',
        'type': 'picture_choice',
        'prompt': 'Which one?',
        'anchor_word_index': 12,
        'choices': [
          {'id': 'x', 'label': 'X', 'accessibilityLabel': 'X', 'emoji': '🦋'},
        ],
      });
      final camel = GenUiCardSchema.fromJson({
        'id': 'a-2',
        'surface': 'reader',
        'type': 'picture_choice',
        'prompt': 'Which one?',
        'anchorWordIndex': 7,
        'choices': [
          {'id': 'x', 'label': 'X', 'accessibilityLabel': 'X', 'emoji': '🦋'},
        ],
      });

      expect(snake.anchorWordIndex, 12);
      expect(camel.anchorWordIndex, 7);
    });

    test('anchorWordIndex defaults to null when absent', () {
      final schema = GenUiCardSchema.fromJson({
        'id': 'a-3',
        'surface': 'reader',
        'type': 'reflection_prompt',
        'prompt': 'Notice anything?',
        'choices': [
          {'id': 'y', 'label': 'Yes', 'accessibilityLabel': 'Yes'},
        ],
      });

      expect(schema.anchorWordIndex, isNull);
      expect(schema.validation.isValid, isTrue);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --plain-name 'parses anchorWordIndex' test/features/gen_ui/domain/gen_ui_schema_test.dart`
Expected: FAIL — `anchorWordIndex` getter not defined / compile error.

- [ ] **Step 3: Add the field, constructor param, and JSON parsing**

In `lib/src/features/gen_ui/domain/gen_ui_card_schema.dart`, add an `_nullableInt` helper near the existing `_int` at the bottom of the file:

```dart
int? _nullableInt(Object? value) {
  if (value is num && value.isFinite) return value.toInt();
  return null;
}
```

Add `required this.anchorWordIndex,` to the `GenUiCardSchema` constructor (place it after `choices`), and the field declaration after `final List<GenUiChoiceSchema> choices;`:

```dart
  final int? anchorWordIndex;
```

In the `fromJson` factory, add the parse line (after the `pageIndex:` line) and pass it through:

```dart
      anchorWordIndex: _nullableInt(
        json['anchorWordIndex'] ?? json['anchor_word_index'],
      ),
```

(Insert `anchorWordIndex: _nullableInt(...)` into the `return GenUiCardSchema(...)` argument list.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/gen_ui/domain/gen_ui_schema_test.dart`
Expected: PASS (all existing + 2 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/gen_ui/domain/gen_ui_card_schema.dart test/features/gen_ui/domain/gen_ui_schema_test.dart
git commit -m "feat(gen_ui): add optional anchorWordIndex to card schema"
```

---

## Task 2: Pure trigger predicate `isActivityLive`

**Files:**
- Create: `lib/src/features/gen_ui/domain/reader_activity_trigger.dart`
- Test: `test/features/gen_ui/domain/reader_activity_trigger_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/gen_ui/domain/reader_activity_trigger_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:storia_kids/src/features/gen_ui/domain/reader_activity_trigger.dart';

GenUiCardSchema _card({int? anchor}) => GenUiCardSchema.fromJson({
      'id': 'c-1',
      'surface': 'reader',
      'type': 'picture_choice',
      'prompt': 'Which one?',
      if (anchor != null) 'anchor_word_index': anchor,
      'choices': [
        {'id': 'x', 'label': 'X', 'accessibilityLabel': 'X', 'emoji': '🦋'},
      ],
    });

void main() {
  group('isActivityLive', () {
    test('null card is never live', () {
      expect(
        isActivityLive(
          card: null,
          isNarrationPlaying: true,
          activeNarratedWordIndex: 99,
        ),
        isFalse,
      );
    });

    test('null anchor is live immediately', () {
      expect(
        isActivityLive(
          card: _card(anchor: null),
          isNarrationPlaying: true,
          activeNarratedWordIndex: -1,
        ),
        isTrue,
      );
    });

    test('narration off (self-read MVP) is live on load regardless of anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: false,
          activeNarratedWordIndex: -1,
        ),
        isTrue,
      );
    });

    test('read-aloud not live until narrated word reaches anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: true,
          activeNarratedWordIndex: 9,
        ),
        isFalse,
      );
    });

    test('read-aloud live once narrated word reaches anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: true,
          activeNarratedWordIndex: 10,
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/gen_ui/domain/reader_activity_trigger_test.dart`
Expected: FAIL — `reader_activity_trigger.dart` / `isActivityLive` not found.

- [ ] **Step 3: Write minimal implementation**

Create `lib/src/features/gen_ui/domain/reader_activity_trigger.dart`:

```dart
import 'gen_ui_card_schema.dart';

/// Decides whether the active page's chosen activity card should be shown now.
///
/// Rules (see spec 2026-05-26-story-spark-takeover-design.md):
/// - No card -> never live.
/// - Null anchor -> live on page load.
/// - Narration off (self-read MVP) -> live on page load (no within-page signal).
/// - Narration on (read-aloud) -> live once the active narrated word index
///   reaches the card's anchor. If the child swipes away first, the card is
///   simply never live for that pass (defer/skip).
///
/// [activeNarratedWordIndex] is the result of
/// `computeActiveWordIndex(page.narrationTimestamps, narrationPosition)`
/// (-1 when there is no active word / no timestamps).
bool isActivityLive({
  required GenUiCardSchema? card,
  required bool isNarrationPlaying,
  required int activeNarratedWordIndex,
}) {
  if (card == null) return false;
  final anchor = card.anchorWordIndex;
  if (anchor == null) return true;
  if (!isNarrationPlaying) return true;
  return activeNarratedWordIndex >= anchor;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/gen_ui/domain/reader_activity_trigger_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/gen_ui/domain/reader_activity_trigger.dart test/features/gen_ui/domain/reader_activity_trigger_test.dart
git commit -m "feat(gen_ui): add isActivityLive trigger predicate"
```

---

## Task 3: Discrete narration pause/resume intents (session)

**Files:**
- Modify: `lib/src/features/reader/runtime/reader_session.dart`
- Modify: `lib/src/features/reader/runtime/reader_session_impl.dart`
- Test: `test/features/reader/runtime/reader_session_narration_pause_test.dart`

Background: the audio port only exposes `toggleNarration()` (no discrete pause). Practice mode already pauses/resumes safely by guarding the toggle on `isNarrationPlaying` (`reader_session_impl.dart` ~lines 231-273). Mirror that.

- [ ] **Step 1: Write the failing test**

Create `test/features/reader/runtime/reader_session_narration_pause_test.dart`:

The fakes below mirror `test/features/reader/runtime/reader_session_page_reset_test.dart` exactly (`ReaderSessionImpl` requires `audioPort` + `speechPort` + `scheduler`, and subscribes to the audio port's three streams in its constructor — the fakes must expose real `StreamController`s). The audio fake adds a `toggleNarrationCalls` counter. Narration on/off is driven by the session's optimistic `_emit(isNarrationPlaying: willPlay)` in the `ReaderToggleNarration` handler, so the state-guarded pause/resume logic is exercised without wiring the audio stream.

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/audio_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/scheduler_port.dart';
import 'package:storia_kids/src/features/reader/runtime/ports/speech_practice_port.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session.dart';
import 'package:storia_kids/src/features/reader/runtime/reader_session_impl.dart';

final _book = Book(
  id: 'b1',
  title: 'T',
  pageCount: 1,
  pages: const [PageData(id: 'p1', pageNumber: 1, textContent: 'hello world')],
);

void main() {
  test('ReaderPauseNarration / ReaderResumeNarration are state-guarded', () async {
    final audio = _CountingAudioPort();
    final session = ReaderSessionImpl(
      audioPort: audio,
      speechPort: _FakeSpeechPracticePort(),
      scheduler: _FakeSchedulerPort(),
    );

    await session.dispatch(ReaderStart(book: _book));
    // Turn narration on (toggle from initial false).
    await session.dispatch(const ReaderToggleNarration());
    expect(audio.toggleNarrationCalls, 1);

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2); // was playing -> paused

    await session.dispatch(const ReaderPauseNarration());
    expect(audio.toggleNarrationCalls, 2); // already paused -> no-op

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3); // was paused -> resumed

    await session.dispatch(const ReaderResumeNarration());
    expect(audio.toggleNarrationCalls, 3); // already playing -> no-op

    await session.dispose();
  });
}

class _CountingAudioPort implements AudioPort {
  final _narrationPosition = StreamController<Duration>.broadcast();
  final _narrationPlaying = StreamController<bool>.broadcast();
  final _soundscapePlaying = StreamController<bool>.broadcast();
  int toggleNarrationCalls = 0;

  @override
  Stream<Duration> get narrationPosition => _narrationPosition.stream;
  @override
  Stream<bool> get narrationPlaying => _narrationPlaying.stream;
  @override
  Stream<bool> get soundscapePlaying => _soundscapePlaying.stream;
  @override
  Future<void> ensureInitialized() async {}
  @override
  Future<void> loadPage(PageData page) async {}
  @override
  Future<void> transitionToPage(PageData page) async {}
  @override
  Future<void> toggleNarration() async {
    toggleNarrationCalls++;
  }
  @override
  Future<void> toggleSoundscape() async {}
  @override
  Future<void> setNarrationVolume(double volume) async {}
  @override
  Future<void> setSoundscapeVolume(double volume) async {}
  @override
  Future<void> dispose() async {
    await _narrationPosition.close();
    await _narrationPlaying.close();
    await _soundscapePlaying.close();
  }
}

class _FakeSpeechPracticePort implements SpeechPracticePort {
  @override
  Future<bool> initialize() async => true;
  @override
  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
        onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  }) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeSchedulerPort implements SchedulerPort {
  @override
  CancelableTask schedule(Duration delay, void Function() action) =>
      _FakeCancelableTask();
}

class _FakeCancelableTask implements CancelableTask {
  @override
  void cancel() {}
}
```

NOTE: `SpeechPracticePort.startListening` and `SchedulerPort` signatures are copied from `reader_session_page_reset_test.dart` — if either interface differs at execution time, copy the current signatures from that file verbatim.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/reader/runtime/reader_session_narration_pause_test.dart`
Expected: FAIL — `ReaderPauseNarration`/`ReaderResumeNarration` not defined.

- [ ] **Step 3: Add the intents**

In `lib/src/features/reader/runtime/reader_session.dart`, after `ReaderResumeListening` (line ~132), add:

```dart
final class ReaderPauseNarration extends ReaderIntent {
  const ReaderPauseNarration();
}

final class ReaderResumeNarration extends ReaderIntent {
  const ReaderResumeNarration();
}
```

- [ ] **Step 4: Handle the intents in the session impl**

In `lib/src/features/reader/runtime/reader_session_impl.dart`, in the `dispatch` chain (after the `ReaderResumeListening` block, before `ReaderPracticePrimaryAction`), add:

```dart
    if (intent is ReaderPauseNarration) {
      if (_state.isNarrationPlaying) {
        await _audioPort.toggleNarration();
        _emit(_state.copyWith(isNarrationPlaying: false));
      }
      return;
    }
    if (intent is ReaderResumeNarration) {
      if (!_state.isNarrationPlaying) {
        await _audioPort.toggleNarration();
        _emit(_state.copyWith(isNarrationPlaying: true));
      }
      return;
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/reader/runtime/reader_session_narration_pause_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/reader/runtime/reader_session.dart lib/src/features/reader/runtime/reader_session_impl.dart test/features/reader/runtime/reader_session_narration_pause_test.dart
git commit -m "feat(reader): add discrete narration pause/resume intents"
```

---

## Task 4: Activity audio actions in the experience controller

**Files:**
- Modify: `lib/src/features/reader/application/reader_experience_controller.dart`

Behavioral coverage for the pause/restore dispatch lives in Task 7 (a real `ReaderScreen` integration test using the existing action-recording fake notifier). This task is implementation + `flutter analyze`.

- [ ] **Step 1: Add `activityNarrationPaused` to `ReaderExperienceState`**

In `lib/src/features/reader/application/reader_experience_controller.dart`, add to the `ReaderExperienceState` constructor params, fields, `.initial()` (=`false`), and `copyWith` (following the existing `endedForLifecycle` pattern exactly):

```dart
  final bool activityNarrationPaused;
```
- Constructor: `required this.activityNarrationPaused,`
- `.initial()` analog: set `activityNarrationPaused: false` wherever the initial state is built (the controller builds `ReaderExperienceState(readerState: ..., wordHelpSnapshot: ..., showCelebrationGif: false, endedForLifecycle: false)` at line ~162 — add `activityNarrationPaused: false`).
- `copyWith`: add `bool? activityNarrationPaused,` param and `activityNarrationPaused: activityNarrationPaused ?? this.activityNarrationPaused,`.

Adding a `required` field breaks the only other `ReaderExperienceState(...)` construction — the fake in `test/features/reader/reader_screen_coordinator_test.dart` (~line 234). Add `activityNarrationPaused: false,` to that constructor call too (place it after `endedForLifecycle: false,`).

```bash
grep -rn 'ReaderExperienceState(' lib test --include='*.dart' | grep -v copyWith
# Confirm only controller line ~162 and the test line ~234 need the new field.
```

- [ ] **Step 2: Add the actions and dispatch mapping**

In the same file, after `ReaderExperienceResumeListening` (line ~142), add:

```dart
final class ReaderExperienceActivityShown extends ReaderExperienceAction {
  const ReaderExperienceActivityShown();
}

final class ReaderExperienceActivityDismissed extends ReaderExperienceAction {
  const ReaderExperienceActivityDismissed();
}
```

In the `dispatch` switch (after `ReaderExperienceResumeListening()` case, before `ReaderExperienceAckCelebration()`), add:

```dart
      case ReaderExperienceActivityShown():
        if (_state.readerState.isNarrationPlaying) {
          _setState(_state.copyWith(activityNarrationPaused: true));
          await _session.dispatch(const ReaderPauseNarration());
        }
      case ReaderExperienceActivityDismissed():
        if (_state.activityNarrationPaused) {
          _setState(_state.copyWith(activityNarrationPaused: false));
          await _session.dispatch(const ReaderResumeNarration());
        }
```

NOTE: confirm the private state mutator is named `_setState` (it is used in `handleLifecycleState`). Use the same method here.

- [ ] **Step 3: Run analyze + the existing reader suite**

Run: `flutter analyze lib/src/features/reader/application/reader_experience_controller.dart`
Run: `flutter test test/features/reader/reader_screen_coordinator_test.dart`
Expected: No analyze issues; coordinator test still PASS (the `activityNarrationPaused: false` added to its fake state keeps it compiling). Behavioral dispatch coverage comes in Task 7.

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/reader/application/reader_experience_controller.dart test/features/reader/reader_screen_coordinator_test.dart
git commit -m "feat(reader): add activity shown/dismissed actions that pause/restore narration"
```

---

## Task 5: Anchor indices in mock cards

**Files:**
- Modify: `lib/src/features/gen_ui/data/mock_gen_ui_cards.dart`

- [ ] **Step 1: Add anchors to two demo cards, leave others null**

In `lib/src/features/gen_ui/data/mock_gen_ui_cards.dart`, add `'anchor_word_index'` to the `page-2-picture` and `page-3-empathy` map literals (so read-aloud mid-passage is exercised), and intentionally leave `page-0-reflection` without an anchor (page-load path). Add to the `page-2-picture` map (after `'page_index': 2,`):

```dart
    'anchor_word_index': 6,
```

Add to the `page-3-empathy` map (after `'page_index': 3,`):

```dart
    'anchor_word_index': 4,
```

- [ ] **Step 2: Run the gen_ui data/domain tests**

Run: `flutter test test/features/gen_ui/`
Expected: PASS (anchors are optional; nothing regresses).

- [ ] **Step 3: Commit**

```bash
git add lib/src/features/gen_ui/data/mock_gen_ui_cards.dart
git commit -m "feat(gen_ui): add anchor word indices to demo reader cards"
```

---

## Task 6: Takeover overlay + adaptive answers + audio dispatch

**Files:**
- Modify: `lib/src/features/gen_ui/presentation/reader_activity_card.dart`
- Test: `test/features/gen_ui/presentation/reader_activity_card_test.dart`

This task rewrites the overlay/card. `ReaderActivityCard` (the inner presentational widget) stays a pure `StatelessWidget` taking a `card`, `onChoiceSelected`, `onSkip` — easy to widget-test without the reader graph. The full-screen scrim, centering, animation, and audio dispatch live in `ReaderActivityPromptOverlay`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/gen_ui/presentation/reader_activity_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:storia_kids/src/features/gen_ui/presentation/reader_activity_card.dart';

GenUiCardSchema _pictureCard() => GenUiCardSchema.fromJson({
      'id': 'pic-1',
      'surface': 'reader',
      'type': 'picture_choice',
      'prompt': 'Which picture best matches what happened?',
      'choices': [
        {'id': 'lantern', 'label': 'Lantern', 'accessibilityLabel': 'A lantern', 'emoji': '🏮'},
        {'id': 'rain', 'label': 'Rain', 'accessibilityLabel': 'Rain', 'emoji': '🌧️'},
        {'id': 'fly', 'label': 'Butterfly', 'accessibilityLabel': 'Butterfly', 'emoji': '🦋'},
      ],
    });

GenUiCardSchema _reflectionCard() => GenUiCardSchema.fromJson({
      'id': 'ref-1',
      'surface': 'reader',
      'type': 'reflection_prompt',
      'prompt': 'What is one tiny detail you notice on this page right now?',
      'choices': [
        {
          'id': 'noticed',
          'label': 'I noticed something interesting happening',
          'accessibilityLabel': 'I noticed something',
        },
        {
          'id': 'wonder',
          'label': 'I wonder why that happened the way it did',
          'accessibilityLabel': 'I wonder why',
        },
      ],
    });

Future<void> _pump(WidgetTester tester, GenUiCardSchema card,
    {void Function(GenUiChoiceSchema)? onChoice, VoidCallback? onSkip}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReaderActivityCard(
          card: card,
          onChoiceSelected: onChoice ?? (_) {},
          onSkip: onSkip ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('short emoji choices render as a tile grid', (tester) async {
    await _pump(tester, _pictureCard());
    expect(find.byType(ReaderActivityCard), findsOneWidget);
    // All three choice labels visible.
    expect(find.text('Lantern'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('Butterfly'), findsOneWidget);
    // Tile-grid layout uses a GridView/Wrap-of-tiles tagged by key.
    expect(find.byKey(const ValueKey('activity-answers-tiles')), findsOneWidget);
  });

  testWidgets('long labels render as stacked rows', (tester) async {
    await _pump(tester, _reflectionCard());
    expect(find.byKey(const ValueKey('activity-answers-stacked')), findsOneWidget);
    expect(find.textContaining('I noticed something'), findsOneWidget);
  });

  testWidgets('tapping a choice invokes onChoiceSelected', (tester) async {
    GenUiChoiceSchema? picked;
    await _pump(tester, _pictureCard(), onChoice: (c) => picked = c);
    await tester.tap(find.text('Lantern'));
    await tester.pump();
    expect(picked?.id, 'lantern');
  });

  testWidgets('tapping the skip button invokes onSkip', (tester) async {
    var skipped = false;
    await _pump(tester, _pictureCard(), onSkip: () => skipped = true);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(skipped, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/gen_ui/presentation/reader_activity_card_test.dart`
Expected: FAIL — missing `activity-answers-tiles`/`activity-answers-stacked` keys (current card uses a `Wrap`).

- [ ] **Step 3: Rewrite the card body with adaptive answers**

In `lib/src/features/gen_ui/presentation/reader_activity_card.dart`, replace the `Wrap(...)` block (currently the choices section inside `ReaderActivityCard.build`) with a call to a new private widget, and make the card opaque. Change the `SketchCard` color to opaque:

```dart
      child: SketchCard(
        color: StoriaColors.paperRaised,
        borderColor: StoriaColors.mustardDeep.withValues(alpha: 0.6),
```

Replace the choices `Wrap(...)` with:

```dart
            _ActivityAnswers(
              choices: card.choices,
              onChoiceSelected: onChoiceSelected,
            ),
```

Add this private widget at the bottom of the file:

```dart
/// Picks an answer layout by content: a 2-column emoji tile grid when every
/// choice has an emoji and all labels are short; otherwise full-width stacked
/// rows (handles reflection prompts and long true/false sentences).
class _ActivityAnswers extends StatelessWidget {
  const _ActivityAnswers({required this.choices, required this.onChoiceSelected});

  static const int _shortLabelMaxChars = 14;

  final List<GenUiChoiceSchema> choices;
  final ValueChanged<GenUiChoiceSchema> onChoiceSelected;

  bool get _useTiles =>
      choices.isNotEmpty &&
      choices.every(
        (c) => c.emoji != null && c.label.characters.length <= _shortLabelMaxChars,
      );

  @override
  Widget build(BuildContext context) {
    if (_useTiles) {
      return Wrap(
        key: const ValueKey('activity-answers-tiles'),
        spacing: StoriaSpacing.sm,
        runSpacing: StoriaSpacing.sm,
        children: [
          for (final choice in choices)
            _AnswerTile(choice: choice, onTap: () => onChoiceSelected(choice)),
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
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.choice, required this.onTap});

  final GenUiChoiceSchema choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Two columns: each tile ~half the available width minus the Wrap spacing.
    final width = (MediaQuery.sizeOf(context).width.clamp(0.0, 460.0)
            - StoriaSpacing.lg * 2 - StoriaSpacing.sm) / 2;
    return Semantics(
      button: true,
      label: choice.accessibilityLabel,
      child: SizedBox(
        width: width,
        child: SketchButton(
          label: choice.emoji == null
              ? choice.label
              : '${choice.emoji}  ${choice.label}',
          tone: SketchButtonTone.secondary,
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.choice, required this.onTap});

  final GenUiChoiceSchema choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: choice.accessibilityLabel,
      child: SketchButton(
        label: choice.emoji == null
            ? choice.label
            : '${choice.emoji}  ${choice.label}',
        tone: SketchButtonTone.secondary,
        onPressed: onTap,
      ),
    );
  }
}
```

Add `import 'package:characters/characters.dart';` if `.characters` is not already available (it is part of the Dart SDK via `dart:core` extension from package:characters — confirm with `flutter analyze`; if unresolved, add the import).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/gen_ui/presentation/reader_activity_card_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Convert the overlay to a full-screen animated takeover with audio dispatch**

Replace the `ReaderActivityPromptOverlay.build` body. The overlay must:
1. Watch the card via `readerGenUiCardProvider`.
2. Compute live state with `isActivityLive` using `isNarrationPlaying`, and `computeActiveWordIndex(page.narrationTimestamps, narrationPosition)`.
3. On first transition to live, dispatch `ReaderExperienceActivityShown`; on dismiss dispatch `ReaderExperienceActivityDismissed` (via the reader experience controller).
4. Render a full-screen scrim (tap = skip) + centered card with a Cue entrance.

Make `ReaderActivityPromptOverlay` a `ConsumerStatefulWidget`. Its new constructor takes the narration inputs instead of `bottomInset`:

```dart
class ReaderActivityPromptOverlay extends ConsumerStatefulWidget {
  const ReaderActivityPromptOverlay({
    super.key,
    required this.bookId,
    required this.pageIndex,
    required this.isNarrationPlaying,
    required this.narrationPositionListenable,
    required this.narrationTimestamps,
    required this.onActivityShown,
    required this.onActivityDismissed,
  });

  final String bookId;
  final int pageIndex;
  final bool isNarrationPlaying;
  final ValueListenable<Duration> narrationPositionListenable;
  final List<WordTimestamp>? narrationTimestamps;
  final VoidCallback onActivityShown;
  final VoidCallback onActivityDismissed;

  @override
  ConsumerState<ReaderActivityPromptOverlay> createState() =>
      _ReaderActivityPromptOverlayState();
}
```

State implementation:

```dart
class _ReaderActivityPromptOverlayState
    extends ConsumerState<ReaderActivityPromptOverlay> {
  bool _shown = false;

  void _handleLive(bool live) {
    if (live && !_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onActivityShown();
      });
    }
  }

  void _dismiss(VoidCallback action) {
    if (_shown) {
      _shown = false;
      widget.onActivityDismissed();
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(
      readerGenUiCardProvider(
        ReaderGenUiPromptRequest(
          bookId: widget.bookId,
          pageIndex: widget.pageIndex,
        ),
      ),
    );

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.narrationPositionListenable,
      builder: (context, position, _) {
        final activeWordIndex = computeActiveWordIndex(
          widget.narrationTimestamps,
          position,
        );
        final live = isActivityLive(
          card: card,
          isNarrationPlaying: widget.isNarrationPlaying,
          activeNarratedWordIndex: activeWordIndex,
        );
        _handleLive(live);

        if (!live || card == null) return const SizedBox.shrink();

        return _ActivityTakeover(
          card: card,
          onChoiceSelected: (choice) {
            _dismiss(() {
              ref
                  .read(genUiActivityControllerProvider.notifier)
                  .answer(card, choice);
            });
          },
          onSkip: () {
            _dismiss(() {
              ref.read(genUiActivityControllerProvider.notifier).skip(card);
            });
          },
        );
      },
    );
  }
}
```

Add the `_ActivityTakeover` widget (scrim + centered card + Cue entrance):

```dart
class _ActivityTakeover extends StatelessWidget {
  const _ActivityTakeover({
    required this.card,
    required this.onChoiceSelected,
    required this.onSkip,
  });

  final GenUiCardSchema card;
  final ValueChanged<GenUiChoiceSchema> onChoiceSelected;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Dimmed scrim — tap to skip neutrally.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Skip activity',
              child: GestureDetector(
                onTap: onSkip,
                child: const ColoredBox(color: Color(0x8C080B11)),
              ),
            ),
          ),
          Center(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StoriaSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Cue.onMount(
                    motion: const CueMotion.curved(
                      StoriaMotion.medium,
                      curve: StoriaMotion.emphasized,
                    ),
                    acts: const [.fadeIn(), .slideY(from: 0.12)],
                    child: ReaderActivityCard(
                      card: card,
                      onChoiceSelected: onChoiceSelected,
                      onSkip: onSkip,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Add imports at the top of the file:

```dart
import 'package:cue/cue.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models.dart';
import '../../reader/overlay/text_overlay_utils.dart';
import '../domain/reader_activity_trigger.dart';
```

NOTE: Animation polish (exit animation, reduced-motion fallback) — invoke the `cue-animations` skill to refine. Confirmed-available acts in cue 0.2.1: `.fadeIn()`, `.slideY(from:)`. If `.slideY` signature differs, the skill will correct it. Entrance-only is acceptable for this task; an exit animation is a nice-to-have, not required by tests.

- [ ] **Step 6: Run the presentation tests + analyze**

Run: `flutter test test/features/gen_ui/presentation/reader_activity_card_test.dart`
Run: `flutter analyze lib/src/features/gen_ui/presentation/reader_activity_card.dart`
Expected: PASS, no analyze issues.

- [ ] **Step 7: Commit**

```bash
git add lib/src/features/gen_ui/presentation/reader_activity_card.dart test/features/gen_ui/presentation/reader_activity_card_test.dart
git commit -m "feat(gen_ui): convert Story Spark to focused takeover with adaptive answers"
```

---

## Task 7: Wire the overlay into the reader screen

**Files:**
- Modify: `lib/src/features/reader/reader_screen.dart` (around line 280)
- Test: `test/features/reader/reader_screen_coordinator_test.dart` (verify still green)

- [ ] **Step 1: Update the overlay mount**

In `lib/src/features/reader/reader_screen.dart`, replace the existing `ReaderActivityPromptOverlay(...)` mount (lines ~280-284) with the new signature. The active page is `book.pages[activeIndex]`; the controller `c` exposes `narrationPositionListenable`:

```dart
              ReaderActivityPromptOverlay(
                bookId: book.id,
                pageIndex: activeIndex,
                isNarrationPlaying: state.readerState.isNarrationPlaying,
                narrationPositionListenable: c.narrationPositionListenable,
                narrationTimestamps: activePage.narrationTimestamps,
                onActivityShown: () => unawaited(
                  c.dispatch(const ReaderExperienceActivityShown()),
                ),
                onActivityDismissed: () => unawaited(
                  c.dispatch(const ReaderExperienceActivityDismissed()),
                ),
              ),
```

NOTE: confirm `activePage` is in scope at this point (it is used at line ~150/267 for `activePage.narrationUrl` / `activePage.pageNumber`). Confirm `c` is the `ReaderExperienceControllerNotifier`/controller handle exposing `narrationPositionListenable` (line ~372 exposes it). If `c` is the notifier, expose `narrationPositionListenable` through it or read the underlying controller — match how line 176 obtains `c.narrationPositionListenable`.

- [ ] **Step 2: Keep the takeover hidden in the coordinator test**

IMPORTANT: `MockGenUiCardRepository.readerCardsForPage` filters by `page_index` only and **ignores `bookId`**, so page 0 of *any* book yields the null-anchor `page-0-reflection` card → the takeover would render and its full-screen scrim would intercept the `Icons.headphones_rounded` tap, breaking the existing coordinator assertions.

Fix: in `test/features/reader/reader_screen_coordinator_test.dart`, override the card repository to return no cards. Add a fake repo near the other fakes:

```dart
class _EmptyGenUiRepo implements MockGenUiCardRepository {
  const _EmptyGenUiRepo();
  @override
  List<GenUiCardSchema> readerCardsForPage({
    required String bookId,
    required int pageIndex,
  }) => const [];
}
```

Add to the `overrides:` list of **each** test that mounts `ReaderScreen` with a present book (the two `book-1` tests and the `book-multi` test — not the `missing` test, which never builds the reader body):

```dart
          mockGenUiCardRepositoryProvider.overrideWithValue(
            const _EmptyGenUiRepo(),
          ),
```

Add the imports to the test file:

```dart
import 'package:storia_kids/src/features/gen_ui/data/gen_ui_providers.dart';
import 'package:storia_kids/src/features/gen_ui/data/mock_gen_ui_cards.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';
```

Run: `flutter test test/features/reader/reader_screen_coordinator_test.dart`
Expected: PASS. With no cards, the overlay renders `SizedBox.shrink()` and existing assertions are unaffected. (`computeActiveWordIndex(null, ...)` returns -1, so even a `_book` without `narrationTimestamps` is safe.)

- [ ] **Step 3: Add an integration test for the audio dispatch (Task 4 behavioral coverage)**

This test deliberately lets a card show (no empty-repo override) and asserts the wiring dispatches `ReaderExperienceActivityShown` on show and `ReaderExperienceActivityDismissed` on skip, using the existing action-recording fake notifier. Add to `test/features/reader/reader_screen_coordinator_test.dart` inside `main()`:

```dart
  testWidgets('Story Spark takeover dispatches activity shown/dismissed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final coordinatorLog = _CoordinatorLog();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentBookProvider('book-1').overrideWith((ref) async => _book),
          bookManifestProvider('book-1').overrideWith((ref) async => null),
          readerSessionProvider.overrideWith((ref) => _FakeReaderSession()),
          readerExperienceControllerProvider.overrideWith(
            () => _FakeReaderExperienceControllerNotifier._(
              coordinatorLog,
              'book-1',
            ),
          ),
          readerExperienceEffectsProvider.overrideWith(
            (ref) => const NoopReaderExperienceEffects(),
          ),
          // NOTE: no mockGenUiCardRepositoryProvider override here — page 0
          // yields the null-anchor reflection card, which is live on load.
        ],
        child: const MaterialApp(home: ReaderScreen(bookId: 'book-1')),
      ),
    );
    await tester.pump();
    await tester.pump(); // let the post-frame onActivityShown fire

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceActivityShown>(),
      hasLength(1),
    );

    // Skip via the card's close button.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    expect(
      coordinatorLog.actions.whereType<ReaderExperienceActivityDismissed>(),
      hasLength(1),
    );
  });
```

Run: `flutter test test/features/reader/reader_screen_coordinator_test.dart`
Expected: PASS. If the card overflows at this view size, increase `physicalSize` height; the reflection card is short.

- [ ] **Step 4: Full analyze + reader test suite**

Run: `flutter analyze`
Run: `flutter test test/features/reader/ test/features/gen_ui/`
Expected: No analyze issues; all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/reader/reader_screen.dart test/features/reader/reader_screen_coordinator_test.dart
git commit -m "feat(reader): mount Story Spark takeover with narration-anchored trigger"
```

---

## Task 8: Manual verification + full suite

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All PASS.

- [ ] **Step 2: Manual smoke (use the `run` skill or `flutter run`)**

Verify on a book whose pages have anchored cards:
- Read-aloud ON: card appears mid-page when narration reaches the anchored word; narration pauses; answering/skip/scrim-tap resumes narration.
- Narration OFF: card appears on page load (self-read MVP).
- Swiping away during read-aloud before the anchor: card does not appear over the next page.
- Card is fully opaque (no story-text bleed); picture-choice shows tile grid; reflection shows stacked rows.

- [ ] **Step 3: Update `.wolf` project memory**

Append the outcome to `.wolf/memory.md` and update `.wolf/anatomy.md` per project rules.

- [ ] **Step 4: Final commit (if any verification fixes were made)**

```bash
git add -A
git commit -m "test(gen_ui): verify Story Spark takeover end-to-end"
```

---

## Self-Review Notes

- **Spec coverage:** schema anchor (T1), trigger predicate read-aloud/self-read/defer (T2), discrete pause/resume (T3), explicit shown/dismissed audio (T4), mock anchors (T5), takeover + adaptive answers + scrim skip + opaque card + animation (T6), wiring + page-load fallback via null timestamps (T7), edge cases via predicate tests (T2) and manual (T8).
- **Out-of-scope respected:** no new input modalities, no within-page self-read tracking, no policy change.
- **Type consistency:** `isActivityLive({card, isNarrationPlaying, activeNarratedWordIndex})`, `ReaderPauseNarration`/`ReaderResumeNarration`, `ReaderExperienceActivityShown`/`ReaderExperienceActivityDismissed`, `activityNarrationPaused` state field, `_ActivityAnswers`/`_AnswerTile`/`_AnswerRow`/`_ActivityTakeover` — names consistent across tasks.
- **Open confirmations flagged inline** (Book/Page constructor shape, `ReaderSessionImpl` ctor ports, `_setState` name, `c` handle for `narrationPositionListenable`, `.slideY` signature) — each task says to verify against the named file before running.
