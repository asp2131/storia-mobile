# Story Spark — Focused Takeover + Mid-Passage Triggering

**Date:** 2026-05-26
**Status:** Approved design, pending implementation plan
**Area:** `lib/src/features/gen_ui/`, `lib/src/features/reader/`

## Problem

The gen-AI activity card ("Story Spark") currently floats mid-screen, semi-transparent
(`paperRaised` at alpha 0.96), so story text bleeds through it. Its answer choices use a
`Wrap` with intrinsic-width buttons, producing a ragged "one wide + two narrow" layout. The
card is mounted at a fixed `bottom: inset + 128`, where it covers the reading area and crowds
the audio control wheel.

Beyond the visual defects, the card's trigger is page-level: it appears the moment a page with
a question loads, regardless of where the child is in the passage.

## Product Intent

Gen-AI questions are a comprehension-building mechanic, not an end-of-book quiz. They should be
**frictionless** and **interleaved into the reading flow** — frequent mid-story check-ins asked
right after the relevant passage, which keeps working-memory load small (important for children
learning a new language or with memory/focus challenges). Two skill buckets: comprehension
(plot, characters, cause/effect) and tier-2 vocabulary. Answers are multi-sensory and never
require typing.

This effort covers **presentation + trigger timing**. New input modalities (drag-and-drop,
listen-and-respond, speech recognition) are out of scope and become separate specs.

## Decisions

| Topic | Decision |
|-------|----------|
| Placement | Focused takeover: dimmed background, card centered on screen |
| Answer layout | Adaptive — emoji 2-col tile grid for short choices, full-width stacked rows for long text |
| Dismissal | Close button **and** tapping the scrim both skip neutrally |
| Feel | Narration pauses on appear, smooth fade/scale animation in/out, narration auto-resumes on dismiss |
| Scope | Presentation **and** trigger timing (mid-passage). New input types excluded. |
| Trigger (read-aloud) | Fire when the highlighted word crosses the card's anchor word |
| Trigger (self-read) | Fire when the anchor word scrolls past the reading line |
| Missed anchor | If the page is about to leave and the card is still pending, fire before the page leaves |

## Architecture

Three units with clear boundaries:

1. **Schema (data shape)** — what a card is, including its anchor.
2. **Trigger engine (when)** — decides the moment a chosen card becomes live.
3. **Presentation (how)** — the takeover overlay, adaptive answers, animation, audio coordination.

`readerGenUiCardProvider` remains the source of *which* card a page gets (selection policy
unchanged). The trigger engine decides *when* that card becomes live. The presentation layer
renders it and coordinates audio.

## Components

### 1. Schema — `domain/gen_ui_card_schema.dart`

Add an optional anchor to `GenUiCardSchema`:

- `final int? anchorWordIndex;` — global word index on the card's page.
- JSON key `anchor_word_index` (also accept `anchorWordIndex`), parsed like the existing
  `pageIndex` dual-key handling.
- Semantics:
  - **Non-null** → mid-passage card; fires when reading crosses that word.
  - **Null** → page-level card; fires on page load (preserves today's behavior).
- No new validation errors (anchor is optional). An anchor index that exceeds the page's word
  count degrades to the page-leave backstop.

Update `mock_gen_ui_cards.dart` so the existing demo cards carry representative anchor indices,
plus at least one null-anchor card to exercise the page-load path.

### 2. Trigger engine — new `ReaderActivityTrigger`

A notifier (Riverpod, matching the feature's existing `StateNotifier` style) that, for the
**active page only**, tracks a card through states: `pending → live → dismissed`.

Inputs it observes:
- The chosen card for the active page (`readerGenUiCardProvider`).
- `spokenWordIndices` (read-aloud progress) and `isNarrationPlaying` from reader state.
- The active page's scroll offset (`_scrollOffsetNotifier` in `reader_screen.dart`).
- Active page changes.

Transition rules (`pending → live`):
- **Null anchor:** live on page load.
- **Narration playing:** live when `spokenWordIndices` contains/exceeds `anchorWordIndex`.
- **Narration off:** live when the scroll offset moves the anchor word above the reading line.
- **Backstop:** if the active page is leaving (or its content end is reached) and the card is
  still `pending`, force it live before the page leaves so the check-in is not silently lost.

`live → dismissed` happens on answer or skip (skip includes scrim tap). Dismissed cards are not
re-shown for that page (consistent with `log.hasInteractedWith`).

Resetting: a fresh page resets trigger state for that page. (Aligns with existing reader behavior
that resets state on session start / page reset.)

### 3. Presentation — `presentation/reader_activity_card.dart`

**`ReaderActivityPromptOverlay`** becomes a full-screen overlay:
- Renders only when the trigger reports the active page's card is `live`.
- A dimmed scrim filling the screen; tapping it calls `onSkip` (neutral skip). Scrim has a
  semantic label "Skip activity."
- The card is centered (no longer pinned above the audio wheel).

**`ReaderActivityCard`:**
- Card surface opaque (`paperRaised` alpha 1.0) — no story-text bleed. Keeps header (sparkle
  badge + "Story Spark" + skip X) and prompt/supporting text.
- Replace the `Wrap` of choices with a new **`_ActivityAnswers`** widget that chooses layout by
  content:
  - **Emoji tile grid (2-col)** when every choice has an emoji and all labels are short
    (threshold, e.g. ≤ ~14 chars). Odd choice count → final tile spans full width.
  - **Stacked full-width rows** (emoji badge left, label right) otherwise — handles reflection
    prompts and longer true/false sentences uniformly.
- Invalid-card fallback message unchanged.

**Animation (Cue package, per cue-animations conventions):**
- Scrim: `fadeIn` on enter, fade out on exit.
- Card: scale + slide-up on enter; reverse on exit. Use a `CueMotion` preset consistent with
  existing reader chrome motion (`StoriaMotion`).

**Audio coordination:**
- On `live`: signal `ReaderExperienceController` to pause narration (soundscape continues).
- On dismiss (answer / skip / scrim): resume narration if it was playing when the card appeared.
- This is a new hook from the overlay/trigger into the reader controller; the gen-UI activity
  controller continues to own answer/skip logging.

### Accessibility

- Card keeps `Semantics(container: true, label: 'Story activity. <prompt>')`.
- Scrim is a labeled button ("Skip activity").
- On show, focus moves to the card prompt; tiles/rows keep each choice's `accessibilityLabel`.
- Animation respects reduced-motion (fall back to fade only).

## Data Flow

1. Child reads page N. `readerGenUiCardProvider(N)` yields a candidate card (policy unchanged).
2. `ReaderActivityTrigger` holds it `pending` and watches narration/scroll for page N.
3. Anchor crossed (highlight or scroll) → card goes `live`.
4. Overlay shows takeover; narration pauses with a smooth animated entrance.
5. Child answers (logged via `genUiActivityControllerProvider.answer`) or skips / taps scrim
   (`skip`). Card animates out; narration resumes.
6. If the child leaves page N before the anchor is crossed, the backstop fires the card before
   the page leaves.

## Error Handling / Edge Cases

- **Invalid card:** existing "activity unavailable" fallback.
- **Anchor beyond word count:** degrades to page-leave backstop.
- **Narration toggled mid-page:** trigger re-evaluates against the current mode (highlight vs
  scroll).
- **Rapid page swipes:** backstop ensures a pending card fires before its page leaves; once
  dismissed it does not reappear.
- **Reduced motion:** fade-only entrance/exit.

## Testing

**Unit (trigger engine):**
- Null anchor → live on page load.
- Narration on → live when `spokenWordIndices` crosses anchor; not before.
- Narration off → live when anchor word scrolls past the reading line.
- Page-leave backstop fires a still-pending card.
- Dismissed card does not re-trigger for the same page.

**Widget (presentation):**
- Adaptive layout: short emoji choices render tile grid; long labels render stacked rows; odd
  count spans last tile.
- Scrim tap invokes skip.
- Opaque card (no transparency).
- Pause-on-show / resume-on-dismiss dispatched to the reader controller.

**Regression:**
- Update `test/features/reader/reader_screen_coordinator_test.dart` and reader session tests for
  the new overlay/trigger wiring.

## Out of Scope

- New answer modalities: drag-and-drop, listen-and-respond, speech recognition.
- Server-driven card content (mock repository remains).
- Selection-policy changes (`GenUiPromptPolicy` unchanged).
