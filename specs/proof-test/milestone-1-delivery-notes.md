# Proof-Test Milestone 1 — Delivery Notes

Updated: 2026-04-15

## What shipped

### Mobile (`storia-mobile`)
- Added backend API client wired to `API_BASE_URL` and authenticated with the Supabase bearer token.
- Switched child profile resolution to prefer backend child-profile APIs, with existing Supabase fallback kept in place.
- Added active-child selection/loading so progress, continue-reading, and reader entry all use the selected child context.
- Switched reading progress reads/writes to backend `/api/reading-progress` and `/api/continue-reading`, with fallback to the prior path if needed.
- Switched reading-session writes to backend `/api/reading-sessions`.
- Hardened the reader session coordinator so progress can flush explicitly and finalize on lifecycle changes.
- Upgraded library UX:
  - active child chip/dropdown scaffold
  - continue-reading card with impression tracking
  - preview CTA split into **Play** vs **Read**
- Reader entry now distinguishes `autoplayNarration` vs `standard`, including resume behavior.

### Backend (`storia`)
- Completed child-aware contracts for books, progress, continue-reading, reading sessions, and child profiles.
- Added validation hardening for reading progress/session writes.
- Enriched continue-reading and book payloads so mobile can use backend data directly.
- Added route tests for reading progress, continue-reading, and reading sessions.

## Contract changes to use

### New / updated backend behavior
- `GET /api/reading-progress?childProfileId=<id>`
  - returns `{ progressList: BookProgress[] }`
- `GET /api/reading-progress?childProfileId=<id>&bookId=<bookId>`
  - returns `{ progress: BookProgress | null }`
- `GET /api/continue-reading?childProfileId=<id>`
  - `progress` now includes mobile-ready fields:
    - `childProfileId`
    - `bookId`
    - `totalPages`
    - `completedAt`
    - `completionCount`
    - `lastSessionId`
    - `status`
- `GET /api/books?childProfileId=<id>`
  - progress objects are now closer to the mobile `BookProgress` shape.
- `POST /api/reading-sessions`
  - repeat/idempotent writes update more fields on existing sessions.
- `POST /api/child-profiles`
  - trims input, validates `readingLevel`, and auto-defaults the first child.

### Validation expectations
- `bookId` must be a positive integer where required.
- `startedAt` / `endedAt` must be valid datetimes.
- `currentPage <= totalPages`.
- 400 responses include field-specific detail keys via `details.field`.

### Behavior note
- Reopening a completed book with `completed: false` clears `completedAt` but preserves `completionCount`, so rereads move back to `in_progress`.

## Remaining gaps / follow-ups
- Child switching UI is scaffolded, not a polished full management flow yet.
- Backend-first flows still keep Supabase/function fallbacks; cleanup can happen once backend rollout is stable.
- Milestone 1 stops before comprehension, adult reporting, and classroom/clinic workflows.
- End-to-end manual verification should still be run against a real signed-in account plus seeded child/book data.

## How to exercise locally

### 1. Start backend
In `storia`:
```bash
npm install
npm run dev
```
Make sure the API is reachable from the Flutter app.

### 2. Point mobile at the backend
In `storia-mobile`, run Flutter with `API_BASE_URL` set:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```
Use an account that can obtain a valid Supabase access token, since mobile sends it as a bearer token.

### 3. Verify milestone-1 flows manually
1. Sign in and land in the library.
2. Confirm an active child is shown/selected.
3. Open a book preview from the map:
   - verify **Play** and **Read** are separate actions
   - verify progress chip/status appears for in-progress/completed books
4. Start with **Play**:
   - reader should enter autoplay narration mode
5. Exit and reopen with **Read**:
   - reader should enter standard mode
6. Turn pages, leave the reader, and reopen:
   - continue-reading card should appear in the library
   - resume should reopen at the saved page
   - play should reopen with narration intent
7. Finish a book, then reopen it:
   - verify progress/session data updates correctly
   - verify reread behavior returns the book to `in_progress` when applicable

### 4. Verification commands
In `storia-mobile`:
```bash
flutter analyze lib/src/data/providers.dart lib/src/features/child/data/child_profile_repository.dart lib/src/features/child/providers/active_child_provider.dart lib/src/features/library/game/book_preview_overlay.dart lib/src/features/library/library_screen.dart lib/src/features/progress/data/progress_repository.dart lib/src/features/progress/providers/progress_providers.dart lib/src/features/reader/application/reading_session_coordinator.dart lib/src/features/reader/data/reading_session_repository.dart lib/src/features/reader/providers/reading_session_coordinator_provider.dart lib/src/features/reader/reader_screen.dart lib/src/routing/app_router.dart test/features/library/game/book_preview_overlay_test.dart test/features/library/widgets/continue_reading_card_test.dart

flutter test test/features/library/game/book_preview_overlay_test.dart test/features/library/widgets/continue_reading_card_test.dart
```

In `storia`:
```bash
npx vitest run src/app/api/reading-progress/route.test.ts src/app/api/continue-reading/route.test.ts src/app/api/reading-sessions/route.test.ts
```
