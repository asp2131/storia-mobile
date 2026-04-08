# Storia Kids — Flutter Data Layer Plan for Proof-Test Milestone 1

Generated: 2026-04-06

## Goal

Define the Flutter data-layer architecture needed to support Proof-Test Milestone 1.

This plan focuses on the non-UI plumbing required to make the new library and reader UX reliable, measurable, and backend-connected.

It is designed to support:
- active child context
- continue-reading resolution
- progress-aware library surfaces
- `Play` vs `Read` reader entry intents
- backend-backed progress persistence
- canonical reading session logging

This document complements:
- `specs/proof-test/flutter-milestone-1-scope.md`
- `specs/proof-test/backend-api-contracts.md`
- `specs/proof-test/library-preview-and-continue-reading-ux.md`

---

## Guiding Principles

## 1. Keep UI thin
Widgets should not own API orchestration logic.

## 2. Prefer explicit domain models
Use strongly named models for progress, child context, and reading sessions.

## 3. Separate canonical writes from UX cache
Local state can support resilience, but backend remains the source of truth for proof data.

## 4. Make reader behavior observable without overloading runtime internals
The existing reader runtime should remain focused on reading behavior, audio, and interaction state.

## 5. Design for incremental adoption
Milestone 1 should not require a total architecture rewrite.

---

# Part 1 — Data Layer Responsibilities

The Flutter data layer for Milestone 1 should answer these questions:

1. Who is the active child?
2. What is the child’s continue-reading target?
3. What progress exists for each book?
4. How do we save updated progress safely?
5. How do we record a reading session canonically?
6. How do we distinguish `Play` vs `Read` entry?
7. How do we emit analytics consistently?

---

# Part 2 — Recommended Architecture Overview

## Layering

### Domain models
Pure app-level data shapes.

### Repositories
Translate backend/local persistence into domain objects.

### Providers / state coordinators
Expose resolved data and actions to the UI.

### Screen-level orchestration
Coordinates UX flow using providers/repositories.

---

## Proposed responsibility map

### Child layer
- active child profile
- child profile loading/caching

### Progress layer
- fetch/save per-book progress
- continue-reading resolution
- progress enrichment in library

### Reading session layer
- create session draft
- update session draft state
- finalize and upload reading session

### Analytics layer
- event wrapper functions
- shared event properties

---

# Part 3 — Domain Models

## 1. `ChildProfile`

Purpose:
- represent the current learner context for all proof-test writes

Suggested fields:
- `id`
- `displayName`
- `ageBand`
- `readingLevel` nullable
- `isDefault`

Suggested path:
- `lib/src/features/child/domain/child_profile.dart`

---

## 2. `BookProgress`

Purpose:
- represent latest backend-backed progress for a single child/book pair

Suggested fields:
- `childProfileId`
- `bookId`
- `currentPage`
- `totalPages`
- `progressPercent`
- `lastReadAt`
- `completedAt` nullable
- `completionCount`
- `lastSessionId` nullable
- `status`

Suggested status enum:
- `newBook`
- `inProgress`
- `completed`

Suggested path:
- `lib/src/features/progress/domain/book_progress.dart`

---

## 3. `ContinueReadingItem`

Purpose:
- represent the one featured continue-reading target for the library screen

Suggested fields:
- `book`
- `progress`
- `hasNarration`

Suggested path:
- `lib/src/features/progress/domain/continue_reading_item.dart`

---

## 4. `ReaderEntryIntent`

Purpose:
- encode how the user entered the reader

Suggested enum values:
- `standard`
- `autoplayNarration`

Suggested path:
- `lib/src/features/reader/domain/reader_entry_intent.dart`

---

## 5. `ReadingSessionDraft`

Purpose:
- hold in-memory session state while reading is happening

Suggested fields:
- `sessionId`
- `childProfileId`
- `bookId`
- `startedAt`
- `startPage`
- `latestPage`
- `entryIntent`
- `usedNarration`
- `usedPracticeMode`
- `completedBook`

Suggested methods:
- `markPage(int page)`
- `markNarrationUsed()`
- `markPracticeModeUsed()`
- `markCompleted()`
- `finalize(DateTime endedAt)` → `ReadingSessionPayload`

Suggested path:
- `lib/src/features/reader/domain/reading_session_draft.dart`

---

## 6. `ReadingSessionPayload`

Purpose:
- final backend-ready payload for canonical session write

Suggested fields:
- `sessionId`
- `childProfileId`
- `bookId`
- `startedAt`
- `endedAt`
- `startPage`
- `endPage`
- `entryIntent`
- `usedNarration`
- `usedPracticeMode`
- `completedBook`
- `source`
- optional `metadata`

Suggested path:
- `lib/src/features/reader/domain/reading_session_payload.dart`

---

# Part 4 — Repositories

## 1. `ChildProfileRepository`

Purpose:
- resolve accessible child profiles from backend
- support startup child selection/defaulting

Suggested methods:
- `Future<List<ChildProfile>> fetchChildProfiles()`
- `Future<ChildProfile?> fetchDefaultChildProfile()`

Suggested path:
- `lib/src/features/child/data/child_profile_repository.dart`

Implementation notes:
- backend source of truth
- optionally cache last selected child id locally using `shared_preferences`

---

## 2. `ProgressRepository`

Purpose:
- fetch and save reading progress
- resolve continue-reading target

Suggested methods:
- `Future<BookProgress?> fetchBookProgress({required String childProfileId, required String bookId})`
- `Future<BookProgress> saveBookProgress({...})`
- `Future<ContinueReadingItem?> fetchContinueReading({required String childProfileId})`
- `Future<Map<String, BookProgress>> fetchBookProgressMap({required String childProfileId})` optional

Suggested path:
- `lib/src/features/progress/data/progress_repository.dart`

Implementation notes:
- backend is canonical
- local cache may be used as fallback only

---

## 3. `ReadingSessionRepository`

Purpose:
- persist finalized reading sessions

Suggested methods:
- `Future<void> saveReadingSession(ReadingSessionPayload payload)`

Optional later:
- queue/retry support
- session draft persistence for crash resilience

Suggested path:
- `lib/src/features/reader/data/reading_session_repository.dart`

---

## 4. `AnalyticsService`

Purpose:
- centralize event names and common properties
- keep widgets/screens free of hand-built analytics payloads

Suggested methods:
- `trackLibraryViewed(...)`
- `trackBookPreviewOpened(...)`
- `trackBookPreviewPlayTapped(...)`
- `trackBookPreviewReadTapped(...)`
- `trackContinueReadingResumeTapped(...)`
- `trackContinueReadingPlayTapped(...)`
- `trackReaderOpened(...)`
- `trackReadingSessionStarted(...)`
- `trackReadingSessionEnded(...)`
- `trackBookCompleted(...)`

Suggested path:
- `lib/src/core/analytics/analytics_service.dart`

Implementation note:
- MVP can log to backend endpoint or no-op wrapper initially if PostHog client integration is deferred
- important part is centralizing contract and call sites now

---

# Part 5 — Providers

Use Riverpod since the app already uses it.

## 1. `activeChildProvider`

Purpose:
- expose the currently selected child profile
- be the root dependency for progress/session operations

Suggested shape:
- `FutureProvider<ChildProfile?>` or `AsyncNotifier<ChildProfile?>`

Recommended responsibilities:
- fetch child profiles
- resolve selected child
- fallback to default child
- cache selected child id locally

Suggested path:
- `lib/src/features/child/providers/active_child_provider.dart`

---

## 2. `continueReadingProvider`

Purpose:
- provide the `Continue Reading` card data

Suggested shape:
- `FutureProvider<ContinueReadingItem?>`

Dependencies:
- active child provider
- progress repository

Suggested path:
- `lib/src/features/progress/providers/progress_providers.dart`

---

## 3. `bookProgressProvider`

Purpose:
- expose progress for a specific book

Suggested shape:
- `FutureProvider.family<BookProgress?, String>`

Dependencies:
- active child provider
- progress repository

Usage:
- book preview popup
- reader startup

---

## 4. `readingSessionCoordinatorProvider`

Purpose:
- provide an orchestration object that manages session draft lifecycle

Suggested implementation:
- plain `Provider<ReadingSessionCoordinator>`

The coordinator can:
- start draft
- update draft state
- finalize session
- call repositories + analytics

Suggested path:
- `lib/src/features/reader/providers/reading_session_coordinator_provider.dart`

---

# Part 6 — Coordinators / Orchestration Objects

This is the most important architectural recommendation in this plan.

## Why a coordinator is needed
The current `ReaderSessionImpl` manages:
- narration state
- soundscape state
- practice mode
- page transitions
- reading interaction state

It should not also become the main owner of:
- API writes
- analytics orchestration
- child identity resolution
- continue-reading mutation side effects

A separate coordinator keeps concerns cleaner.

---

## `ReadingSessionCoordinator`

Purpose:
- bridge reader UX and data-layer side effects

Suggested responsibilities:
- start a reading session draft on reader entry
- observe runtime/page changes
- mark narration used when relevant
- mark practice mode used when relevant
- debounce progress writes
- finalize reading session on exit/completion
- emit analytics events

Suggested methods:
- `startSession({...})`
- `onPageChanged(int page)`
- `onNarrationUsed()`
- `onPracticeModeUsed()`
- `onBookCompleted()`
- `finalizeAndSave()`

Suggested path:
- `lib/src/features/reader/application/reading_session_coordinator.dart`

---

# Part 7 — Local Persistence Strategy

## Keep it simple for Milestone 1

Recommended local persistence use:
- active child id cache
- last known progress cache for resilience
- optional pending-final-save support later

### Existing dependency
- `shared_preferences`

### What to store locally
- `active_child_profile_id`
- `book_progress_{childId}_{bookId}`

### What not to overbuild yet
- full offline queue engine
- local database for sessions

Those can come later if needed.

---

# Part 8 — API Client Boundaries

## Current state
The app uses repository/provider patterns in some areas but not yet a unified API layer.

## Recommendation
For Milestone 1, repositories may use direct `http`/Supabase-backed calls internally, but create a light abstraction boundary now.

### Suggested helper
- `lib/src/core/network/api_client.dart`

Responsibilities:
- base URL handling
- auth/session header support if needed
- standardized JSON decoding
- consistent error mapping

This does not need to become a heavy SDK right away.

---

# Part 9 — Integration by Screen

## Library screen

Dependencies needed:
- active child provider
- continue-reading provider
- progress-aware book metadata or per-book progress provider
- analytics service

Actions needed:
- render continue-reading card
- render upgraded preview popup state
- open reader with `ReaderEntryIntent`

---

## Reader screen

Dependencies needed:
- active child provider
- book progress provider or direct initial progress lookup
- reading session coordinator
- analytics service

Actions needed:
- resolve resume page
- start session draft
- respond to entry intent
- update progress on page changes
- finalize session on exit

---

# Part 10 — Event Ownership

## UI should trigger intent-level events
Examples:
- preview opened
- play tapped
- read tapped
- continue-reading tapped

## Coordinator should trigger session-level events
Examples:
- reader opened
- session started
- session ended
- book completed

This split prevents duplicate event logic across widgets.

---

# Part 11 — Error Handling Strategy

## Progress save failures
- do not block reading
- log error
- keep local cache updated
- retry on next meaningful save opportunity if possible

## Reading session save failures
- do not disrupt reader exit
- log error
- optionally hold last unsent payload in memory/local cache for later retry

## Child context failures
- prevent proof writes
- surface a recoverable fallback or require child selection

## Continue-reading fetch failures
- hide card gracefully
- do not block library usage

---

# Part 12 — Suggested File Layout

## New files
- `lib/src/features/child/domain/child_profile.dart`
- `lib/src/features/child/data/child_profile_repository.dart`
- `lib/src/features/child/providers/active_child_provider.dart`
- `lib/src/features/progress/domain/book_progress.dart`
- `lib/src/features/progress/domain/continue_reading_item.dart`
- `lib/src/features/progress/data/progress_repository.dart`
- `lib/src/features/progress/providers/progress_providers.dart`
- `lib/src/features/reader/domain/reader_entry_intent.dart`
- `lib/src/features/reader/domain/reading_session_draft.dart`
- `lib/src/features/reader/domain/reading_session_payload.dart`
- `lib/src/features/reader/data/reading_session_repository.dart`
- `lib/src/features/reader/application/reading_session_coordinator.dart`
- `lib/src/features/reader/providers/reading_session_coordinator_provider.dart`
- `lib/src/core/analytics/analytics_service.dart`
- optional `lib/src/core/network/api_client.dart`

## Existing files likely touched
- `lib/src/data/models.dart`
- `lib/src/data/providers.dart`
- `lib/src/data/book_repository.dart`
- `lib/src/features/library/library_screen.dart`
- `lib/src/features/library/game/book_preview_overlay.dart`
- `lib/src/features/reader/reader_screen.dart`
- `lib/src/features/reader/runtime/reader_session_impl.dart`

---

# Part 13 — Delivery Sequence

## Step 1 — Domain + repositories
Implement:
- child profile model/repo
- progress model/repo
- reading session model/repo
- analytics service interface

## Step 2 — Providers
Implement:
- active child provider
- continue reading provider
- book progress provider
- session coordinator provider

## Step 3 — Reader coordination
Implement:
- reading session coordinator
- entry intent support
- progress save hooks
- finalize session hooks

## Step 4 — Library integration
Implement:
- continue-reading card data flow
- preview popup progress state
- play/read action wiring

---

# Part 14 — Acceptance Criteria

The data layer plan is successfully implemented when:

1. Flutter can resolve an active child profile
2. Flutter can fetch a continue-reading target
3. Flutter can fetch/save child-aware book progress
4. Flutter can start and finalize a reading session cleanly
5. Flutter can distinguish `standard` vs `autoplay_narration` entry intent
6. UI code does not directly own most backend orchestration
7. analytics events are emitted through a centralized wrapper

---

# Summary

For Proof-Test Milestone 1, Flutter needs a focused data-layer expansion, not a full rewrite.

## Core additions
- child profile domain and provider
- progress repository and providers
- reading session draft/payload models
- reading session repository
- reading session coordinator
- analytics service

## Core architecture move
The single most important design choice is introducing a **ReadingSessionCoordinator** so the app can capture canonical proof data without overloading widget code or reader runtime internals.

This gives Storia a clean path to shipping:
- continue reading
- progress-aware library UX
- `Play` vs `Read` semantics
- backend-backed proof data
