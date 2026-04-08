# Storia Kids — Library Preview + Continue Reading UX Spec

Generated: 2026-04-06

## Goal

Define the Milestone 1 Flutter UX for:
- the `Continue Reading` surface on the library screen
- the upgraded book preview popup shown when a child taps a book on the library map
- the action model for `Play` vs `Read`
- the visual states needed to support proof-test metrics

This spec is intentionally focused on the library-to-reader decision moment, because it is one of the highest-leverage points in the app for both user experience and proof-of-worth instrumentation.

---

## Why this matters

The library is where browsing turns into reading.

Right now, Storia already has a strong map-based discovery experience. What Milestone 1 should add is:
- stronger continuity (`Continue Reading`)
- clearer intent selection (`Play` vs `Read`)
- visible progress awareness (`New`, `Continue`, `Completed`)
- cleaner instrumentation of entry behavior

This gives Storia a better product story and a better data story at the same time.

---

# Part 1 — UX Principles

## 1. Preserve the playful map-first experience
The map should remain the emotional center of the library.
New UX should support the map, not turn the screen into a dashboard.

## 2. Reduce friction at the moment of choice
A child or parent should quickly understand:
- what this book is
- whether they’ve started it before
- how to begin now

## 3. Support both independent reading and narration-led reading
The UI should make both modes feel intentional and equally valid.

## 4. Keep progress visible but lightweight
Progress should feel encouraging, not managerial.
Avoid heavy academic framing in child-facing surfaces.

## 5. Design for measurability
Every meaningful action at this layer should map cleanly to an event or canonical write.

---

# Part 2 — Continue Reading Surface

## Purpose
Surface the child’s most relevant in-progress book so they can quickly resume reading.

## Entry criteria
Show the `Continue Reading` surface when:
- there is an active child profile
- backend or local cache provides one in-progress book

Do not show it when:
- there is no in-progress book
- child context is unresolved

---

## Placement

### Recommended placement
Top portion of `LibraryScreen`, below the search/filter chrome and above the map’s main focal area.

### Why
This placement:
- makes the card immediately visible
- does not compete too heavily with top controls
- preserves the map as the primary body of the screen

### Layout behavior
- full-width card with comfortable horizontal margins
- visually light enough to feel like a featured helper, not a modal or dashboard block

---

## Card content

### Required content
- label: `Continue Reading`
- cover thumbnail
- title
- optional author/subtext if space allows
- page progress text
- progress indicator
- primary actions:
  - `Resume`
  - `Play` if narration exists

### Recommended copy
#### Header label
- `Continue Reading`

#### Supporting line examples
- `Page 7 of 24`
- `You were here last time`
- `Ready for the next page?`

Keep copy warm and low-pressure.

---

## Visual structure

### Left section
- cover thumbnail

### Middle section
- `Continue Reading` label
- title
- page progress text
- progress bar or progress pill

### Right/bottom actions
- `Resume` button
- `Play` icon button or compact secondary CTA

---

## Progress indicator

### Recommended style
A small progress bar or filled pill is preferred over raw percentages alone.

### Example display
- `Page 7 of 24`
- visual bar showing partial completion

### Why
This is easier for children and parents to parse quickly than a numeric percent.

---

## Continue Reading actions

## Action 1 — Resume
### Behavior
- open reader at saved page
- use `standard` entry intent
- do not auto-start narration

### Event
- `continue_reading_resume_tapped`

---

## Action 2 — Play
### Show only when
- the selected book has narration available

### Behavior
- open reader at saved page
- use `autoplay_narration` entry intent
- auto-start narration once reader/audio is ready

### Event
- `continue_reading_play_tapped`

---

## Empty state behavior
If no continue-reading target exists:
- omit the card entirely
- do not show a dead placeholder in Milestone 1

Rationale:
- cleaner library
- less visual noise
- map remains primary

---

# Part 3 — Upgraded Book Preview Popup

## Purpose
Turn the tapped-book popup into a lightweight decision hub for entering the reader.

## Current role
The popup already presents:
- cover
- title
- author
- pages
- a `Read` button

## Milestone 1 role
The popup should now answer:
- Is this book new, in progress, or completed?
- Can I listen right away?
- Should I read or play?

---

## Popup placement and behavior

### Placement
Keep the popup anchored above the tapped node/book.
This preserves the game-like feel of the map.

### Dismissal
- tap outside popup → dismiss
- opening a reader mode → dismiss popup and navigate

### Animation
Keep the current fade + scale entrance.
No heavier transition is needed in Milestone 1.

---

## Popup content hierarchy

### Top
- status chip or reading band
- title
- author

### Middle
- page count
- optional progress chip
- optional `Questions at the end` chip later

### Bottom
- `Play` icon button
- `Read` primary button

---

## Required popup states

## 1. New book
### Status chip
- `New`

### Description
No saved progress exists.

### Actions
- `Play` if narration exists
- `Read`

---

## 2. In-progress book
### Status chip
- `Continue · Page X`

### Description
Saved progress exists and book is not completed.

### Actions
- `Play` if narration exists
- `Read`

### Behavior
Both actions should resume from saved progress, not restart from page 1.

---

## 3. Completed book
### Status chip
- `Completed`

### Description
Book was completed before.

### Actions
- `Play` if narration exists
- `Read`

### Behavior
For Milestone 1:
- `Read` may reopen from beginning or last page depending on product decision
- recommended default: reopen from beginning for completed state unless explicit resume is desired elsewhere

### Suggested follow-up consideration
Later, add a dedicated `Read again` label or choice.
Not required in Milestone 1.

---

# Part 4 — Play Button UX

## Explicit requirement
The popup should include a **play icon button** when tapping a book from the library screen.

## Recommendation
Yes — this should ship in Milestone 1.

### Why it is high leverage
- supports younger readers
- supports narration-led reading behavior
- clarifies mode choice without extra friction
- creates a cleaner event split between passive/listening and standard reading entry

---

## Button design recommendation

### Type
Compact icon-forward button.

### Icon
- preferred: `play_arrow_rounded`

### Labeling options
#### Option A — icon only
Pros:
- compact
- playful
- visually distinct

Cons:
- slightly less explicit for parents/new users

#### Option B — icon + short label (`Play`)
Pros:
- clearer semantics
- stronger for first-time understanding

Cons:
- slightly more visual weight

### Recommended Milestone 1 choice
Use an **icon-forward compact labeled control** if space allows, or a prominent circular icon button paired with a standard `Read` button.

Best practical version:
- `Play` = circular filled icon button
- `Read` = filled text button

This creates clear distinction without overloading the popup.

---

## Interaction behavior
### On tap
- dismiss popup
- navigate to reader
- pass `entryIntent = autoplay_narration`
- track `book_preview_play_tapped`

### Loading/transition note
Autoplay should start after reader setup is ready, not immediately on route push.

---

# Part 5 — Read Button UX

## Purpose
Open standard reading mode.

## On tap
- dismiss popup
- navigate to reader
- pass `entryIntent = standard`
- track `book_preview_read_tapped`

## Visual role
This remains the main textual CTA because:
- it is familiar
- it preserves the reading-first identity of the product
- it avoids making `Play` feel like the only primary mode

---

# Part 6 — Status and Progress Chips

## Purpose
Make state visible without clutter.

## Recommended chip states

### `New`
For untouched books.

### `Continue · Page X`
For in-progress books.
This is likely the most useful state in Milestone 1.

### `Completed`
For completed books.

---

## Visual style
- small rounded pill
- soft tinted background
- high legibility
- warm, friendly palette aligned to current Storia surfaces

Avoid making chips feel overly system-like or enterprise-heavy.

---

## Priority of information
For popup compactness:
1. state chip
2. title
3. author
4. page count
5. actions

If space is tight, prefer dropping secondary metadata before dropping state/action clarity.

---

# Part 7 — Map Node State Indications

## Milestone 1 recommendation
Keep node-state changes subtle.

### Suggested map node states
- new: default node
- in-progress: faint accent ring/glow
- completed: subtle badge/check/ribbon accent

### Why subtle
The map should still feel scenic and browseable, not like a task board.

### Priority
This is lower priority than the popup and continue-reading card.
It can be included only if implementation is cheap and visually tasteful.

---

# Part 8 — Navigation + Behavior Rules

## Continue Reading card
### Resume
- route to reader with saved page and `standard`

### Play
- route to reader with saved page and `autoplay_narration`

---

## Preview popup
### New book + Play
- route to page 1 with `autoplay_narration`

### New book + Read
- route to page 1 with `standard`

### In-progress + Play
- route to saved page with `autoplay_narration`

### In-progress + Read
- route to saved page with `standard`

### Completed + Play
- recommended Milestone 1 default: page 1 with `autoplay_narration`

### Completed + Read
- recommended Milestone 1 default: page 1 with `standard`

---

# Part 9 — Event Tracking Hooks

## Continue Reading events
- `continue_reading_impression`
- `continue_reading_resume_tapped`
- `continue_reading_play_tapped`

### Recommended properties
- child id
- book id
- progress status
- current page
- source = library

---

## Preview popup events
- `book_preview_opened`
- `book_preview_read_tapped`
- `book_preview_play_tapped`

### Recommended properties
- child id
- book id
- progress status
- current page if any
- has narration
- source = library_map

---

## Reader entry event
- `reader_opened`

### Recommended properties
- child id
- book id
- entry intent
- resume page
- source = mobile

---

# Part 10 — Edge Cases

## 1. No narration available
### Behavior
- hide or disable `Play`
- prefer hide for cleaner UX in Milestone 1

## 2. Progress exists but page data looks invalid
### Behavior
- clamp or reset to page 1 safely
- still allow `Read`
- avoid blocking the user

## 3. Continue-reading target becomes stale
### Behavior
- if backend target fails, fallback to local cached progress if available
- otherwise hide card

## 4. Multiple in-progress books
### Behavior
- continue-reading card shows the most recently read book
- other in-progress books still show progress state in preview popup

## 5. Completed book with saved last page
### Behavior
- Milestone 1 should prefer clear restart semantics over confusing end-page reopen behavior
- recommended: completed books reopen from page 1 unless product later adds explicit resume-completed behavior

---

# Part 11 — Copy Recommendations

## Continue Reading card
- `Continue Reading`
- `Page 7 of 24`
- `Resume`
- `Play`

## Preview popup chips
- `New`
- `Continue · Page 7`
- `Completed`

## Buttons
- `Read`
- `Play`

Keep labels short and confidence-building.

---

# Part 12 — Flutter Implementation Notes

## Existing files likely involved
- `lib/src/features/library/library_screen.dart`
- `lib/src/features/library/game/book_preview_overlay.dart`
- `lib/src/features/library/game/library_game.dart`

## Likely new UI file
- `lib/src/features/library/widgets/continue_reading_card.dart`

## Supporting state needed
- active child context
- progress-aware books data
- continue-reading provider
- reader entry intent support

---

# Part 13 — Acceptance Criteria

## Continue Reading card
- appears only when a valid in-progress book exists
- shows title, progress, and actions
- `Resume` and `Play` behave correctly

## Preview popup
- shows progress-aware state chip
- includes `Read`
- includes **Play** when narration exists
- supports new / in-progress / completed states

## Navigation
- `Play` opens reader with autoplay narration intent
- `Read` opens standard reader intent
- in-progress actions restore saved page

## Measurement
- Storia can distinguish:
  - continue-reading resume vs play
  - preview read vs play
  - standard vs autoplay reader entry

---

# Summary

Milestone 1 library UX should make Storia feel more intentional, more supportive, and more measurable.

## Highest-priority additions
1. `Continue Reading` card
2. progress-aware preview popup
3. **Play** icon button on popup
4. `Play` vs `Read` reader entry semantics

These are relatively small UI changes with outsized product and proof-test impact.
