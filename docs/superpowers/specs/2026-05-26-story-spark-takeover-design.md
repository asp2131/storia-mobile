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
| Trigger (read-aloud) | Fire when the active narrated word index reaches the card's `anchorWordIndex` |
| Trigger (self-read, MVP) | No within-page progress signal exists → fire on page load (today's behavior). True mid-passage self-read deferred to a future spec. |
| Missed anchor (read-aloud) | Defer/skip — do not show a departed page's card over the next page; not shown this pass |
| Audio | Explicit `ReaderExperienceActivityShown` (stores `wasNarrationPlaying`, pauses only if playing) + `ReaderExperienceActivityDismissed` (resumes only if it paused) |

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
  count (or a page with no `narrationTimestamps`) never fires mid-passage and falls through to
  the page-load / self-read path.

Update `mock_gen_ui_cards.dart` so the existing demo cards carry representative anchor indices,
plus at least one null-anchor card to exercise the page-load path.

### 2. Trigger — pure `isActivityLive` predicate

The "when" is a **pure predicate**, `isActivityLive(...)`, evaluated for the active page on each
build — not a stateful notifier. There is no separate `pending → live → dismissed` state machine:
"pending" is simply the predicate returning `false`; "dismissed" is handled by the existing
activity log (`log.hasInteractedWith`), which makes `readerGenUiCardProvider` return `null` after
the child answers or skips, so the predicate naturally stops returning `true`. This keeps the
trigger logic trivially unit-testable and avoids duplicating dismissal state.

**Correct signals (verified against the codebase):**
- Narration highlight is **not** `spokenWordIndices`. `spokenWordIndices` is speech-practice
  recognition state (populated from `_speechPort.startListening` / `matchSpokenWords` in
  `reader_session_impl.dart`).
- The active narrated word is `computeActiveWordIndex(page.narrationTimestamps,
  narrationPosition)` (see `overlay/text_overlay_utils.dart`, already used by `page_renderer.dart`).
- `_scrollOffsetNotifier` is the **vertical PageView page position** (`localOffset = scrollOffset
  - index`), not within-page reading progress. Pages are static full-screen; there is no
  per-word scroll position or "reading line" while a child self-reads.

Inputs (all passed into the predicate / computed at the call site, no stored state):
- The chosen card for the active page (`readerGenUiCardProvider`) and its `anchorWordIndex`.
- `isNarrationPlaying` and the active narrated word index, computed from
  `computeActiveWordIndex(page.narrationTimestamps, narrationPosition)`.

`isActivityLive` rules:
- **No card:** never live.
- **Null anchor:** live (on page load).
- **Self-read MVP (narration off):** live (on page load) — no within-page progress signal exists.
  True mid-passage self-read is **out of scope** (requires page-internal word/scroll tracking).
- **Read-aloud (narration playing):** live once the active narrated word index reaches/passes
  `anchorWordIndex`. The only path with a genuine mid-passage signal.

**Missed anchor (read-aloud):** if the child swipes away before narration reaches the anchor, the
predicate simply never returns `true` for that pass — the card is not shown. We do **not** show a
departed page's card over the next page, and we do **not** block the swipe. Re-entering the page
without active narration shows it via the page-load path. No backstop state to manage.

**Dismissal:** answering or skipping (skip includes scrim tap) logs the interaction; thereafter
`readerGenUiCardProvider` returns `null` for that card (`log.hasInteractedWith`) and the predicate
returns `false`. The overlay tracks a local `_shown` boolean only to fire the audio
shown/dismissed actions exactly once (see Presentation).

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

**Audio coordination (explicit pause/restore, not toggle):**
Narration currently exposes only `ReaderExperienceToggleNarration` — toggling to "pause" would
flip narration *on* if it was already off. The activity flow must use intent-explicit actions:
- Add `ReaderExperienceActivityShown`: capture `wasNarrationPlaying = isNarrationPlaying`, and
  pause narration **only if** it was playing. Soundscape is untouched. Requires a discrete
  narration-pause path at the session level (e.g. `ReaderPauseNarration`) rather than a toggle.
- Add `ReaderExperienceActivityDismissed`: resume narration **only if** this flow paused it
  (`wasNarrationPlaying`). Idempotent — dismissing when nothing was paused is a no-op.
- `wasNarrationPlaying` is owned by reader experience state (not the overlay), so it survives
  rebuilds and double-dismiss.
- The gen-UI activity controller continues to own answer/skip logging; these new actions only
  coordinate audio and are dispatched on `live` (shown) and on dismiss (answer / skip / scrim).

### Accessibility

- Card keeps `Semantics(container: true, label: 'Story activity. <prompt>')`.
- Scrim is a labeled button ("Skip activity").
- On show, focus moves to the card prompt; tiles/rows keep each choice's `accessibilityLabel`.
- Animation respects reduced-motion (fall back to fade only).

## Data Flow

1. Child reads page N. `readerGenUiCardProvider(N)` yields a candidate card (policy unchanged).
2. `ReaderActivityTrigger` holds it `pending` for page N.
3. Card goes `live` when: anchor is null (on load), OR narration is off (on load, self-read MVP),
   OR narration is playing and the active narrated word index reaches `anchorWordIndex`.
4. On `live`, dispatch `ReaderExperienceActivityShown` (pauses narration only if it was playing);
   overlay shows the takeover with a smooth animated entrance.
5. Child answers (logged via `genUiActivityControllerProvider.answer`) or skips / taps scrim
   (`skip`). Card animates out; `ReaderExperienceActivityDismissed` resumes narration only if this
   flow paused it.
6. If the child swipes away during read-aloud before the anchor is reached, the card is deferred
   (not shown this pass) — no transition blocking, no cross-page display.

## Error Handling / Edge Cases

- **Invalid card:** existing "activity unavailable" fallback.
- **Anchor beyond word count / null timestamps:** `computeActiveWordIndex` returns -1 when there
  are no timestamps; an unreachable anchor never fires mid-passage and falls through to the
  page-load / self-read path on the next eligible entry.
- **Narration toggled mid-page:** turning narration off mid-page makes the card eligible via the
  self-read (page-load) path; turning it on resumes the active-narrated-word evaluation.
- **Rapid page swipes during read-aloud:** pending card is deferred (not shown); once dismissed
  it does not reappear for that page.
- **Double dismiss / rebuild:** `ReaderExperienceActivityDismissed` is idempotent and keyed on
  `wasNarrationPlaying`, so narration is never resumed twice or resumed when it was already off.
- **Reduced motion:** fade-only entrance/exit.

## Testing

**Unit (trigger engine):**
- Null anchor → live on page load.
- Narration off → live on page load (self-read MVP).
- Narration on → live when `computeActiveWordIndex(narrationTimestamps, narrationPosition)`
  reaches `anchorWordIndex`; not before.
- Swipe away during read-aloud before anchor reached → card deferred (never `live`, no
  cross-page display).
- Dismissed card does not re-trigger for the same page.

**Unit (audio coordination):**
- `ActivityShown` pauses narration only when `isNarrationPlaying` was true; no-op otherwise.
- `ActivityDismissed` resumes narration only when this flow paused it; idempotent on double
  dismiss; never resumes when narration was already off.

**Widget (presentation):**
- Adaptive layout: short emoji choices render tile grid; long labels render stacked rows; odd
  count spans last tile.
- Scrim tap invokes skip.
- Opaque card (no transparency).
- `ActivityShown` / `ActivityDismissed` dispatched on show / dismiss.

**Regression:**
- Update `test/features/reader/reader_screen_coordinator_test.dart` and reader session tests for
  the new overlay/trigger wiring.

## Out of Scope

- New answer modalities: drag-and-drop, listen-and-respond, speech recognition.
- True mid-passage triggering while self-reading (narration off). Requires new page-internal
  scroll/word-position tracking; this effort uses the page-load fallback for self-read.
- Server-driven card content (mock repository remains).
- Selection-policy changes (`GenUiPromptPolicy` unchanged).
