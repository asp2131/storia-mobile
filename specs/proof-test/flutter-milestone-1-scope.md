# Storia Kids — Proof-Test Flutter Milestone 1 Scope

Generated: 2026-04-06

## Goal

Define the smallest high-impact Flutter implementation slice to ship **after backend readiness** for the proof-test roadmap.

This milestone should create a visible UX improvement for children and parents while also unlocking the first reliable proof-of-worth data flows.

---

## Milestone 1 Product Objective

Ship the smallest Flutter slice that:
- improves library-to-reader conversion
- strengthens continue-reading behavior
- distinguishes narration-first vs standard reading entry
- records canonical progress and session data against the configured backend

This milestone intentionally stops short of comprehension checks and reporting UI.

---

## Milestone 1 Success Criteria

After Milestone 1, Storia should be able to:

1. show a child/parent a clearer way to start a book from the library
2. show recent/ongoing reading progress in the library
3. let users resume a book from where they left off
4. distinguish **Play** entry from **Read** entry
5. persist reading progress to the backend
6. record reading sessions to the backend

---

## In Scope

## 1. Continue Reading UX in the library

### User-facing behavior
- If a child has an in-progress book, the library screen shows a `Continue Reading` surface.
- The surface includes:
  - cover
  - title
  - current page / progress indicator
  - `Resume` action
  - `Play` action if narration is available

### Why it matters
- immediate visible improvement
- improves return usage and completion
- reinforces continuity
- unlocks measurable resume behavior

### Recommended placement
A lightweight module near the top of `LibraryScreen`, above or near the map chrome without disrupting the map-first experience.

---

## 2. Upgraded book preview popup

### User-facing behavior
When tapping a book on the library map, the popup preview card should include:
- cover
- title
- author
- page count
- progress/status chip
- **Play** icon button
- **Read** button

### Required states
- new book
- in-progress book (`Continue · Page X`)
- completed book (`Completed`)

### Required interactions
- `Play` opens the reader with autoplay narration intent
- `Read` opens the standard reader

### Why it matters
This is the highest-leverage browse-to-read decision point in the app.

---

## 3. Reader entry intents

### Required intents
- `standard`
- `autoplayNarration`

### Behavior
- `Play` from preview or continue-reading card should open the reader in autoplay narration mode.
- `Read` should open the standard reader mode.

### Why it matters
This allows Storia to distinguish and measure:
- narration-led reading sessions
- standard reading sessions
- mode preference by user/child/content

---

## 4. Progress persistence

### Required behavior
During and after reading, Flutter should:
- maintain local progress resilience
- periodically save progress to the backend
- finalize latest progress on reader exit or completion

### Required fields
- child profile id
- book id
- current page
- total pages
- last session id
- completion state if completed

### Key moments to save
- page change debounce
- app backgrounding
- reader close
- end-of-book completion

---

## 5. Reading session logging

### Required behavior
When reader opens, Flutter starts a session draft.
When reader closes or completes, Flutter finalizes and uploads the session.

### Required session payload
- session id
- child profile id
- book id
- started at
- ended at
- duration
- start page
- end page
- entry intent
- whether narration was used
- whether practice mode was used
- whether the book was completed
- source = `mobile`

### Why it matters
This is the first canonical proof layer for:
- minutes read
- sessions per child
- completion rate
- autoplay vs standard entry analysis

---

## 6. Active child context

### Required behavior
The app must have an active child profile id available for progress and session writes.

### MVP assumption
Milestone 1 can support a single selected child profile, locally cached.

### UI expectation
No full child switcher is required if backend/UX is still early, but the app needs:
- a way to determine active child context
- a fallback strategy if no child is configured

---

## Explicitly Out of Scope

To keep Milestone 1 focused, the following are deferred:
- end-of-book comprehension checks
- question flow UI
- adult-facing progress dashboard
- classroom/clinic reporting UI
- ABA prompt-level capture
- caregiver carryover features
- badges/streaks/rewards system
- deep child profile management UI
- full organization/classroom support in Flutter UI

---

## Backend Dependencies

Milestone 1 depends on the backend exposing working contracts for:

1. child profile retrieval / active child resolution
2. child-aware reading progress fetch/save
3. reading session write endpoint
4. books endpoint with progress-aware data

If backend is not ready, Flutter can scaffold these flows behind repository interfaces first.

---

## Recommended Flutter Architecture for Milestone 1

## New domain models
- `ReaderEntryIntent`
- `BookProgress`
- `ReadingSessionDraft`
- `ReadingSessionPayload`
- `ChildProfile`

## New repositories/services
- `ProgressRepository`
- `ReadingSessionRepository`
- `ChildProfileRepository`
- `AnalyticsService`

## New providers
- `activeChildProvider`
- progress-related providers
- current continue-reading provider

---

## Suggested File Plan

## Existing files to update
- `lib/src/features/library/library_screen.dart`
- `lib/src/features/library/game/book_preview_overlay.dart`
- `lib/src/features/reader/reader_screen.dart`
- `lib/src/data/book_repository.dart`
- `lib/src/data/models.dart`
- `lib/src/data/providers.dart`
- `lib/src/routing/app_router.dart`

## New files likely needed
- `lib/src/features/child/domain/child_profile.dart`
- `lib/src/features/child/data/child_profile_repository.dart`
- `lib/src/features/child/providers/active_child_provider.dart`
- `lib/src/features/progress/domain/book_progress.dart`
- `lib/src/features/progress/data/progress_repository.dart`
- `lib/src/features/progress/providers/progress_providers.dart`
- `lib/src/features/reader/domain/reader_entry_intent.dart`
- `lib/src/features/reader/domain/reading_session_payload.dart`
- `lib/src/features/reader/data/reading_session_repository.dart`
- `lib/src/core/analytics/analytics_service.dart`
- `lib/src/features/library/widgets/continue_reading_card.dart`

---

## UX Specification

## A. Continue Reading card

### Content
- label: `Continue Reading`
- cover thumbnail
- title
- optional subtitle: `Page X of Y`
- progress bar or progress pill
- actions:
  - `Resume`
  - `Play` if narration exists

### Interaction
- `Resume` → opens reader at saved page with standard intent
- `Play` → opens reader at saved page with autoplay narration intent

### Empty state
If no in-progress book exists, do not show the card.

---

## B. Book preview popup

### Minimum card content
- reading band label or status chip
- title
- author
- page count
- progress chip if in progress/completed
- **Play** icon button
- `Read` button

### CTA recommendation
- `Play` should be a distinct icon-forward action
- `Read` should remain the textual primary action

### Progress chip examples
- `New`
- `Continue · Page 7`
- `Completed`

---

## C. Reader startup behavior

### Standard intent
- opens the reader
- restores saved page if resuming
- narration remains user-controlled unless current defaults say otherwise

### Autoplay intent
- opens the reader
- restores saved page if resuming
- automatically starts narration for the current page

### Important note
Autoplay should be implemented carefully to avoid race conditions with audio initialization.

---

## D. Reader exit behavior

On exit, the app should:
- finalize the reading session payload
- save latest progress
- mark completion if appropriate
- flush analytics events

---

## Business Logic Requirements

## 1. Session draft lifecycle

### On reader open
Create a session draft with:
- generated session id
- book id
- child id
- start page
- start timestamp
- entry intent

### During reading
Update draft memory with:
- latest page
- whether narration was used
- whether practice mode was used

### On exit/completion
Finalize payload with:
- end timestamp
- end page
- duration
- completed flag

Then upload.

---

## 2. Progress save strategy

### Recommended strategy
- local cache immediately
- backend save with debounce on page changes
- guaranteed final save on exit/completion

### Why
This balances resilience and network efficiency.

---

## 3. Continue-reading resolution

Library should determine the most recent in-progress book using backend-backed progress data.

### Fallback strategy
If backend data is unavailable, local cached progress may be used temporarily.

---

## 4. Narration usage detection

To support proof metrics, the session should record whether narration was used.

### Minimum requirement
If reader was launched in autoplay intent, mark narration-intended.

### Better requirement
Also detect if narration was actually toggled/played during the session.

---

## 5. Event taxonomy for Milestone 1

Recommended events:
- `library_viewed`
- `continue_reading_impression`
- `continue_reading_resume_tapped`
- `continue_reading_play_tapped`
- `book_preview_opened`
- `book_preview_read_tapped`
- `book_preview_play_tapped`
- `reader_opened`
- `reading_session_started`
- `reading_session_ended`
- `book_completed`

Recommended properties:
- child id
- session id
- book id
- entry intent
- source = mobile
- start page
- end page
- completed flag

---

## Acceptance Criteria

Milestone 1 is complete when:

### Library
- library can display a continue-reading card when progress exists
- book preview popup shows a **Play** action and a `Read` action
- popup can display progress/completion state

### Reader
- reader accepts and responds to entry intents
- reader can resume from saved progress
- autoplay narration works from `Play` entry

### Data
- progress writes reach backend successfully
- reading sessions are recorded successfully
- active child context is attached to writes

### Measurement
- Storia can distinguish `Play` vs `Read` entry at the event/session level
- Storia can compute at least:
  - sessions per child
  - minutes per child
  - books in progress
  - completed books

---

## Recommended Delivery Sequence

## Step 1
Implement repositories, models, and providers for:
- child context
- progress
- reading sessions

## Step 2
Implement continue-reading card in library

## Step 3
Upgrade book preview popup with:
- progress chip
- **Play** button
- `Read` button

## Step 4
Add reader entry intents and autoplay startup behavior

## Step 5
Wire progress/session writes and finalize analytics taxonomy

---

## Why this is the right Milestone 1

This slice is:
- visible to users immediately
- achievable without overbuilding
- tightly aligned with proof-of-worth goals
- foundational for later comprehension and reporting work

It creates a better user experience and a better measurement system at the same time.

---

## Summary

Milestone 1 should ship:
1. continue-reading card
2. upgraded book preview popup
3. **Play** icon button on the popup
4. reader entry intents
5. progress persistence
6. reading session logging
7. active child context

This is the smallest Flutter slice that materially improves the product while unlocking the first real proof-test data flows.
