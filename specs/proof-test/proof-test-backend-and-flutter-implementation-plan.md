# Storia Kids — Proof-Test Backend + Flutter Implementation Plan

Generated: 2026-04-06

## Goal

Document:
1. what needs to change in `../storia/` on the Next.js + Prisma + Supabase backend to support the proof-test roadmap
2. what UI/UX and business-logic changes are needed in Flutter once that backend is available
3. the recommended sequencing for implementation so Storia can quickly put its best foot forward with schools and ABA clinics

This plan builds on:
- `specs/proof-of-worth-gap-analysis.md`
- `specs/proof-test-feature-curation-and-tooling.md`

---

## Executive Summary

Storia already has a strong child-facing reading experience in Flutter:
- a playful map-based library
- an immersive vertical reader
- narration + soundscapes
- word-level highlighting
- tap/long-press word support
- read-aloud practice mode

What is missing is the product infrastructure required to turn those strengths into measurable, buyer-facing proof.

### Core implementation principle

The backend should evolve from a **user-centric progress model** into a **child-centric proof model**.

That means:
- progress should belong to a child/learner profile, not just a parent user
- reading behavior should be logged as sessions, not only as a current page
- comprehension and completion should be stored canonically
- the Flutter app should expose clearer UX for continuation, completion, and lightweight outcomes

---

# Part 1 — Backend Changes Needed in `../storia/`

## Current backend foundation already present

Useful pieces that already exist:
- Prisma schema in `../storia/prisma/schema.prisma`
- Better Auth user/session support in `../storia/src/lib/auth.ts`
- `user_reading_progress` model
- `src/app/api/reading-progress/route.ts`
- `src/app/api/books/route.ts`
- Supabase/Postgres-backed architecture already documented in `docs/database_architecture.md`

This means the backend is not starting from zero. It needs to be expanded and reoriented around proof generation.

---

## Backend objective

Support the curated proof-test feature stack:
1. persistent session/progress logging
2. analytics taxonomy/instrumentation
3. resume + completion history
4. comprehension checks + saved results
5. adult-facing progress reporting

---

## A. Data model changes in `prisma/schema.prisma`

The existing schema supports coarse reading progress, but not proof-grade learner analytics.

## Recommended new models

### 1. `child_profile`
Purpose:
- make progress and outcomes child-centric
- support one parent account with multiple children
- prepare for classroom/clinic reporting later

Suggested fields:
- `id`
- `ownerUserId`
- `displayName`
- `ageBand`
- `readingLevel` nullable
- `organizationId` nullable
- `classroomId` nullable
- `createdAt`
- `updatedAt`

### 2. `reading_session`
Purpose:
- canonical proof record for usage
- source of truth for minutes, sessions, completion, and practice usage

Suggested fields:
- `id`
- `userId`
- `childProfileId`
- `bookId`
- `startedAt`
- `endedAt`
- `durationSeconds`
- `startPage`
- `endPage`
- `completedBook`
- `usedPracticeMode`
- `source` (`mobile`, `web`)
- `metadata` JSON

### 3. `child_book_progress` (preferred) or extend `user_reading_progress`
Purpose:
- store latest progress/resume state per child + book
- support continue-reading and completion history

Suggested fields:
- `id`
- `childProfileId`
- `bookId`
- `currentPage`
- `totalPages`
- `progressPercent` optional derived or not stored
- `lastReadAt`
- `lastSessionId`
- `completedAt` nullable
- `completionCount`
- `updatedAt`

### 4. `book_question`
Purpose:
- define end-of-book comprehension content

Suggested fields:
- `id`
- `bookId`
- `questionText`
- `questionType` (`multiple_choice` first)
- `sortOrder`
- `correctAnswer`
- `metadata` JSON
- `createdAt`
- `updatedAt`

### 5. `book_question_option`
Purpose:
- support structured multiple-choice answers

Suggested fields:
- `id`
- `questionId`
- `optionKey`
- `optionText`
- `sortOrder`

### 6. `question_attempt`
Purpose:
- save comprehension performance

Suggested fields:
- `id`
- `userId`
- `childProfileId`
- `bookId`
- `questionId`
- `readingSessionId` nullable
- `selectedAnswer`
- `isCorrect`
- `answeredAt`

### 7. `book_completion` (optional but useful for easy reporting)
Purpose:
- support easy completion reporting and history

Suggested fields:
- `id`
- `userId`
- `childProfileId`
- `bookId`
- `readingSessionId`
- `completedAt`

---

## Minimum backend MVP schema

If scope must stay tight, the minimum schema changes should be:
- `child_profile`
- `reading_session`
- `child_book_progress`
- `book_question`
- `book_question_option`
- `question_attempt`

This is enough to support the MVP proof-test stack.

---

## B. Migration work

Files to update:
- `../storia/prisma/schema.prisma`
- new files under `../storia/prisma/migrations/...`

Recommended migration order:
1. add `child_profile`
2. add `reading_session`
3. add `child_book_progress`
4. add comprehension tables
5. add indexes needed for summary/report queries

Recommended indexes:
- `reading_session(childProfileId, startedAt)`
- `reading_session(bookId, startedAt)`
- `child_book_progress(childProfileId, bookId)` unique
- `question_attempt(childProfileId, bookId, answeredAt)`
- `book_question(bookId, sortOrder)`

---

## C. API routes to update or add

## 1. Update `src/app/api/reading-progress/route.ts`

### Current state
This route currently saves and returns only:
- `bookId`
- `currentPage`
- `totalPages`
- `lastReadAt`

### Needed evolution
It should become the lightweight resume-state endpoint.

### Updated responsibilities
- fetch latest progress for a child + book
- save latest progress for a child + book
- optionally mark completion
- optionally link to `lastSessionId`

### New expected request shape
- `childProfileId`
- `bookId`
- `currentPage`
- `totalPages`
- `lastSessionId` nullable
- `completed` nullable
- `source` (`mobile`)

### New response shape
- `currentPage`
- `totalPages`
- `progressPercent`
- `lastReadAt`
- `completedAt`
- `completionCount`

---

## 2. Add `src/app/api/reading-sessions/route.ts`

Purpose:
- store canonical reading session records

### MVP behavior
A single `POST` endpoint is enough initially.

Request fields:
- `childProfileId`
- `bookId`
- `startedAt`
- `endedAt`
- `startPage`
- `endPage`
- `usedPracticeMode`
- `completedBook`
- `source`

### Alternative later
Separate session lifecycle routes:
- `/start`
- `/heartbeat`
- `/end`

For MVP, a single finalized-session write is simpler.

---

## 3. Add `src/app/api/books/[bookId]/questions/route.ts`

Purpose:
- return comprehension questions for a book

Response should include:
- ordered questions
- options
- enough metadata for Flutter to render end-of-book checks

---

## 4. Add `src/app/api/comprehension/route.ts`

Purpose:
- save comprehension attempts/results

Request fields:
- `childProfileId`
- `bookId`
- `readingSessionId` nullable
- `answers[]`
  - `questionId`
  - `selectedAnswer`

Response fields:
- `totalQuestions`
- `correctCount`
- `scorePercent`
- optional saved attempt ids

---

## 5. Update `src/app/api/books/route.ts`

### Current state
Can already attach reading progress if `userId` is passed.

### Needed evolution
Make book listing child-aware rather than only user-aware.

Support:
- `childProfileId`

Optionally return per book:
- `currentPage`
- `progressPercent`
- `lastReadAt`
- `completedAt`
- `completionCount`
- `hasQuestions`

This helps the Flutter library screen show stronger continue-reading and completion affordances.

---

## 6. Add reporting endpoint(s)

Recommended MVP route:
- `src/app/api/reports/summary/route.ts`

This route can accept query params like:
- `childProfileId`
- `organizationId`
- date range

### MVP child summary response
- books started
- books completed
- total reading sessions
- total reading minutes
- avg session duration
- active streak or active days optional later
- comprehension attempts
- average comprehension score

### MVP org/classroom summary response
- active readers
- sessions/week
- average minutes
- completion rate
- comprehension completion rate
- average comprehension score

---

## D. Analytics integration

## Recommended approach
Use:
- **Supabase/Postgres** for canonical product data
- **PostHog** for analytics/event behavior layer

### Files to add/update
- `../storia/package.json` — add `posthog-node`
- `../storia/src/lib/analytics.ts`

### Suggested server-side events
- `reading_session_saved`
- `book_completed`
- `comprehension_completed`
- `child_profile_created`

### Environment variables
- `POSTHOG_API_KEY`
- `POSTHOG_HOST`
- optionally `NEXT_PUBLIC_POSTHOG_KEY`

---

## E. Seed data updates

File to update:
- `../storia/prisma/seed.ts`

Add support for:
- sample child profiles
- sample reading sessions
- sample comprehension questions
- sample question attempts

This is important so the new backend paths can be tested quickly in dev and staging.

---

## F. Documentation updates in `../storia/`

Recommended files to update:
- `../storia/README.md`
- `../storia/docs/database_architecture.md`

Recommended new docs:
- `../storia/docs/proof-test-data-model.md`
- `../storia/docs/analytics-setup.md`
- `../storia/docs/mobile-proof-test-api-contracts.md`

These should document:
- schema additions
- route contracts
- PostHog setup
- child-centric data ownership rules
- reporting query expectations

---

## Backend files most likely to change

### Existing files to update
- `../storia/prisma/schema.prisma`
- `../storia/prisma/seed.ts`
- `../storia/src/app/api/reading-progress/route.ts`
- `../storia/src/app/api/books/route.ts`
- `../storia/package.json`
- `../storia/src/lib/auth.ts` (possibly light linkage changes only)
- `../storia/docs/database_architecture.md`

### New files likely needed
- `../storia/src/app/api/reading-sessions/route.ts`
- `../storia/src/app/api/books/[bookId]/questions/route.ts`
- `../storia/src/app/api/comprehension/route.ts`
- `../storia/src/app/api/reports/summary/route.ts`
- `../storia/src/lib/analytics.ts`

---

## Backend implementation priority

### Phase 1 — Required for mobile proof-test foundation
1. schema additions
2. migration generation and application
3. child-aware reading progress endpoint
4. reading sessions endpoint
5. child-aware books endpoint

### Phase 2 — Required for school-facing outcome proof
6. comprehension questions endpoint
7. comprehension result endpoint
8. summary reporting endpoint
9. PostHog integration

### Phase 3 — Useful follow-up
10. CSV export endpoint
11. organization/classroom structures
12. richer analytics aggregation

---

# Part 2 — Flutter UI/UX Changes Needed Once Backend Is Ready

## Product objective for Flutter

Flutter should do more than expose content beautifully.
It should now also:
- capture measurable behavior reliably
- make progress visible
- reinforce continuity and completion
- create low-friction outcome moments
- prepare data for adult-facing proof

---

## A. Library screen changes

Relevant current files:
- `lib/src/features/library/library_screen.dart`
- `lib/src/features/library/game/book_preview_overlay.dart`
- `lib/src/features/library/game/library_game.dart`

## 1. Upgrade the book preview overlay

### Current state
The preview card currently shows:
- cover
- title
- author
- page count
- Read button

### Explicit requested enhancement
Add a **play icon button** on the book preview popup when a child taps a book from the library screen.

### Recommended interpretation
Use the preview card as a small action hub with 2 primary reading-entry choices:

#### Primary actions
- **Play** — start narrated read-aloud immediately
- **Read** — open standard reader

### Why this is valuable
This improves both UX and measurement:
- clearer mode choice
- better read-aloud engagement tracking
- easier entry for younger readers
- more intentional session categorization

### Suggested UI layout
Within `BookPreviewOverlay`:
- keep existing `Read` CTA
- add a circular or pill-shaped **Play** icon button beside it
- icon: `Icons.play_arrow_rounded` or a branded variant
- tooltip/label idea: `Listen` or `Play`

### Recommended CTA semantics
- `Play` = open reader with narration auto-start intent
- `Read` = open reader with normal mode intent

### Analytics benefit
Track distinct entry events:
- `book_preview_play_tapped`
- `book_preview_read_tapped`

---

## 2. Add progress-aware preview content

Once the backend provides child-aware progress, the preview card should show lightweight progress context.

### Recommended additions
- `Continue from page X` if in progress
- `Completed` badge if finished before
- `Played before` / `Read before` optional later
- `Questions available` badge if a book has comprehension checks

### Suggested hierarchy
1. title/author
2. status chip
3. page count and/or completion chip
4. `Play` and `Read` actions

### Example status chips
- `Continue · Page 7`
- `Completed`
- `New`
- `3 quick questions at the end`

---

## 3. Add continue-reading rail/state in library screen

Current library is map-first. That can remain.

### Recommended UX addition
Add a lightweight top module or floating card above the map:
- `Continue Reading`
- most recent book
- page progress
- quick action: `Resume`
- quick action: `Play`

### Why this matters
This is one of the cheapest/highest-impact UX changes for:
- return usage
- completion
- continuity metrics

### Possible location
In `LibraryScreen` stack, above the map controls and below the top chrome.

---

## 4. Add completion-state representation on map nodes

Once completion is stored, library nodes should optionally reflect progress.

### Suggested visual states
- untouched book: default node
- in-progress book: subtle glow/ring/progress accent
- completed book: check/star/ribbon state

### Important constraint
Keep the map elegant and uncluttered.
Do not make it feel like a hard-gated progression system.

---

## B. Reader flow changes

Relevant current files:
- `lib/src/features/reader/reader_screen.dart`
- `lib/src/features/reader/runtime/reader_session_impl.dart`
- `lib/src/features/reader/runtime/providers/reader_session_provider.dart`

## 1. Introduce explicit session lifecycle management

### Current state
Reader runtime manages playback and page state locally, but does not appear to write canonical reading session records.

### Needed behavior
When reader opens:
- create local session context with session id
- record start timestamp
- record start page

When reader closes or completes:
- finalize session payload
- send to backend
- update progress endpoint

### Data to collect in Flutter
- session id
- book id
- child profile id
- started at
- ended at
- start page
- end page
- used narration?
- used practice mode?
- completed book?
- source = mobile

### Recommended client architecture
Add a dedicated service/repository layer for proof-test writes rather than embedding all network calls directly inside widget code.

---

## 2. Support reader entry intents

The reader should support at least 2 entry intents:
- standard reading
- play/read-aloud entry

### Suggested route/state behavior
When opening from `Play` in the preview overlay:
- navigate to reader with a startup intent, e.g. `autoPlayNarration = true`

When opening from `Read`:
- normal reader start

### Why this matters
This lets Storia measure mode preference and usage quality more accurately.

### Example events
- `reader_opened_standard`
- `reader_opened_autoplay`

---

## 3. Persist resume state during reading

### Needed behavior
During reading:
- periodically save current page locally for resilience
- debounce backend writes for progress
- flush final update on exit/completion

### Recommended rhythm
- local save often
- backend progress save on:
  - page change debounce
  - app backgrounding
  - reader exit
  - completion

This should not wait until the very end of the session.

---

## 4. Trigger completion experience with next-step options

### Current state
Reader already has celebration behavior.

### Recommended evolution
After final page completion:
- keep celebration
- then show a next-step sheet/card with:
  - `Play again`
  - `Read again`
  - `Quick questions`
  - `Back to library`

### Why this matters
This is the ideal handoff point into comprehension checks.

---

## C. Comprehension UX changes

## 1. End-of-book question flow

### MVP recommendation
After completion, if questions exist:
- show a gentle transition card:
  - `Want to answer 3 quick questions?`
- enter a simple question flow
- submit results at the end

### Design principles
- brief
- affirming
- low-pressure
- highly tappable
- no school-test anxiety vibe

### Suggested structure
- one question per screen/card
- large answer targets
- progress indicator: `1 of 3`
- friendly success summary at end

---

## 2. Store question results and summary locally before sync

Flutter should handle temporary offline/network issues gracefully.

### Needed behavior
- queue comprehension attempts locally until confirmed by backend
- show success UI immediately when possible
- retry failed submissions later if needed

MVP can keep this simple if backend reliability is high, but the architecture should anticipate transient failure.

---

## D. Child profile selection / learner context

## 1. Introduce active child context in the app

To support child-centric reporting, Flutter needs an active learner context.

### MVP assumptions
At minimum:
- one logged-in adult selects one child profile
- active child profile is cached locally
- all progress/session/comprehension writes attach that child profile id

### Recommended UI surfaces
- onboarding or profile creation flow
- child switcher in settings or library top chrome later

### Why this matters
Without active child context, backend child-centric analytics cannot be used consistently.

---

# Part 3 — Flutter Business Logic Changes

## Objective

Add a dedicated proof-test data layer rather than scattering analytics and persistence directly through screens.

---

## A. Add domain models

Suggested new models in Flutter:
- `ChildProfile`
- `BookProgress`
- `ReadingSessionDraft`
- `ReadingSessionPayload`
- `BookQuestion`
- `BookQuestionOption`
- `ComprehensionResult`
- `ReaderEntryIntent`

---

## B. Add repositories/services

Suggested new responsibilities:

### 1. `ProgressRepository`
Handles:
- get current child/book progress
- save/update progress
- fetch continue-reading data

### 2. `ReadingSessionRepository`
Handles:
- create session draft
- finalize/upload reading sessions
- retry failed session uploads if needed

### 3. `ComprehensionRepository`
Handles:
- fetch book questions
- submit answers
- return score/result summary

### 4. `AnalyticsService`
Handles:
- event taxonomy wrappers
- forwarding to PostHog or backend if needed

### 5. `ActiveChildProvider`
Handles:
- current learner context
- persistence of selected child profile id

---

## C. Update reader runtime integration

### Current state
`ReaderSessionImpl` manages reader interaction state, narration, soundscape, and practice mode.

### Recommended extension
Do not overload it with all networking.
Instead:
- let runtime own reading-state behavior
- let a higher-level orchestration layer translate runtime state into proof-test writes

### Recommended orchestration pattern
A controller/coordinator near `ReaderScreen` should:
- create a session draft on entry
- listen to runtime state changes
- record whether narration/practice were used
- update progress on page changes
- finalize session on close
- trigger completion + questions flow

---

## D. Add analytics/event taxonomy wrappers in Flutter

Suggested minimum events:
- `library_viewed`
- `book_preview_opened`
- `book_preview_play_tapped`
- `book_preview_read_tapped`
- `reader_opened`
- `reading_session_started`
- `page_turned`
- `reading_session_completed`
- `reading_session_ended`
- `comprehension_started`
- `comprehension_completed`

Common properties:
- child id
- session id
- book id
- source = mobile
- entry intent
- age band if available
- app version/platform later

---

# Part 4 — Recommended Flutter UI Roadmap

## Slice 1 — Foundational proof plumbing

Build:
- active child profile selection support
- progress repository
- reading session repository
- child-aware progress fetch/save
- continue-reading card/rail in library

### Visible UX outcome
- books remember progress
- library can show continue-reading
- sessions can be recorded canonically

---

## Slice 2 — Better library decision moment

Build:
- enhanced `BookPreviewOverlay`
- add explicit **Play** icon button
- progress/status chips
- questions-available chip if present

### Visible UX outcome
- preview card becomes a more intentional launch surface
- children/parents can quickly choose listen vs read
- Storia can capture stronger intent data

---

## Slice 3 — Reader completion and comprehension

Build:
- completion handoff card
- fetch book questions
- question flow UI
- result submission and summary UI

### Visible UX outcome
- Storia can capture lightweight outcome data
- reader completion has a stronger loop

---

## Slice 4 — Reporting surfaces later

Possible future Flutter surfaces:
- parent progress summary screen
- child progress screen
- mini stats card in settings/library

For institutional dashboards, the heavier reporting likely belongs in web first, but Flutter can still expose child-level summaries.

---

# Part 5 — Specific UI/UX Recommendations for the Book Preview Overlay

Since this was explicitly requested, here is the recommended next-step UX for the popup preview card.

## Current card
- cover
- title
- author
- pages
- Read button

## Recommended upgraded card

### Top content
- reading band / status label
- title
- author
- progress chip if in progress or complete

### Metadata row
- page count
- optional `Questions at the end` chip

### Action row
- **Play** icon button
- **Read** primary button

### Button behavior
- `Play`:
  - opens reader
  - starts narration automatically
  - tracks autoplay entry intent
- `Read`:
  - opens reader normally
  - tracks standard entry intent

### Optional later
- a tertiary bookmark/continue affordance if helpful

## Why this is important
This popup is one of the highest-leverage moments in the app:
- it sits at the point of choice
- it shapes perceived polish
- it can increase conversion from browse to read
- it helps segment how children use the product

---

# Part 6 — Suggested Implementation Notes by File in Flutter

## Existing files likely to change

### Library
- `lib/src/features/library/library_screen.dart`
- `lib/src/features/library/game/book_preview_overlay.dart`
- `lib/src/features/library/game/library_game.dart`

### Reader
- `lib/src/features/reader/reader_screen.dart`
- `lib/src/features/reader/runtime/reader_session_impl.dart`
- `lib/src/features/reader/runtime/providers/reader_session_provider.dart`

### Data layer
- `lib/src/data/book_repository.dart`
- `lib/src/data/models.dart`
- `lib/src/data/providers.dart`

### Routing
- `lib/src/routing/app_router.dart`

## New Flutter files likely needed

### Data / domain
- `lib/src/features/progress/data/progress_repository.dart`
- `lib/src/features/progress/domain/book_progress.dart`
- `lib/src/features/reader/data/reading_session_repository.dart`
- `lib/src/features/reader/domain/reading_session_payload.dart`
- `lib/src/features/comprehension/data/comprehension_repository.dart`
- `lib/src/features/comprehension/domain/book_question.dart`
- `lib/src/features/child/data/child_profile_repository.dart`
- `lib/src/features/child/domain/child_profile.dart`

### State/providers
- `lib/src/features/child/providers/active_child_provider.dart`
- `lib/src/features/progress/providers/progress_providers.dart`
- `lib/src/features/comprehension/providers/comprehension_providers.dart`

### UI
- `lib/src/features/library/widgets/continue_reading_card.dart`
- `lib/src/features/comprehension/comprehension_screen.dart`
- `lib/src/features/comprehension/widgets/question_card.dart`
- `lib/src/features/reader/widgets/completion_handoff_sheet.dart`

### Services
- `lib/src/core/analytics/analytics_service.dart`
- optional `lib/src/core/network/api_client.dart`

---

# Part 7 — Recommended Sequencing Across Backend and Flutter

## Order of operations

### Step 1 — Backend contracts first
Finalize:
- child profile model
- reading session contract
- progress contract
- question contract
- comprehension submission contract

### Step 2 — Flutter data layer second
Implement:
- repositories
- models
- providers
- local persistence strategy

### Step 3 — Library UX third
Implement:
- continue-reading
- progress chips
- **Play** icon button in preview card
- reader entry intents

### Step 4 — Reader completion + comprehension
Implement:
- session finalization
- completion handoff
- question flow

### Step 5 — Reporting surfaces later
Implement:
- parent/child summaries in Flutter if desired
- larger institutional views on web

---

# Part 8 — Business Outcome Framing

If implemented well, this backend + Flutter plan should let Storia tell a much stronger proof story.

### Instead of saying
“Kids enjoyed the library and reader.”

### Storia can say
“Children returned to read multiple times per week, resumed books reliably, completed stories, and answered lightweight comprehension questions after reading.”

And with the new preview card action split:
- Storia can distinguish browse-to-read behavior
- Storia can measure autoplay/listen preference for younger readers
- Storia can better understand how narration drives engagement and completion

---

# Summary

## Backend changes in `../storia/`
The backend should be extended with:
- child-centric identity (`child_profile`)
- canonical `reading_session` logging
- child-aware progress storage
- comprehension content and attempts
- summary reporting endpoints
- PostHog analytics integration

## Flutter changes
Flutter should evolve with:
- active child context
- progress + session repositories
- continue-reading UI
- richer book preview overlay
- a **Play icon button** on the popup preview card
- reader entry intents
- completion handoff flow
- end-of-book comprehension checks

## Highest-leverage UX change to start with
Upgrade the library book preview popup into a small action hub with:
- progress context
- optional question availability badge
- **Play** button
- **Read** button

That is a visible, user-facing improvement that also strengthens proof instrumentation.
