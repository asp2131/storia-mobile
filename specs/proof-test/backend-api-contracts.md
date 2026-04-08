# Storia Kids — Proof-Test Backend API Contracts

Generated: 2026-04-06

## Goal

Define the backend API contracts required for the proof-test roadmap so the Flutter app can implement Milestone 1 cleanly and predictably.

This document focuses on the first set of mobile-critical contracts:
- active child context
- child-aware book progress
- reading session writes
- progress-aware books listing

It also includes forward-compatible placeholders for:
- comprehension questions
- comprehension submissions
- summary reporting

---

## Design Principles

1. **Child-centric, not just user-centric**
   - Writes and reads should attach to a `childProfileId`.
2. **Canonical source of truth lives on backend**
   - Flutter may cache locally, but backend owns reporting data.
3. **Simple contracts first**
   - Prefer flat, explicit payloads over overly abstract shapes.
4. **Mobile resilience**
   - Endpoints should support debounced progress saves and end-of-session finalization.
5. **Forward compatibility**
   - Contracts should leave room for organizations, classrooms, and ABA-specific fields later.

---

## Authentication Expectations

All proof-test endpoints assume an authenticated parent/staff session unless explicitly documented otherwise.

### Required auth behavior
- Backend resolves the authenticated user from Better Auth session.
- Backend validates that the authenticated user has access to the target `childProfileId`.
- Requests for unauthorized child profiles return `403`.

### Standard auth failure responses

#### `401 Unauthorized`
```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

#### `403 Forbidden`
```json
{
  "error": {
    "code": "forbidden",
    "message": "You do not have access to this child profile"
  }
}
```

---

## Common Response Conventions

### Success envelope
For simple endpoints, plain JSON objects are fine. No global envelope is required.

### Error shape
All non-2xx responses should return:
```json
{
  "error": {
    "code": "invalid_request",
    "message": "childProfileId is required",
    "details": {
      "field": "childProfileId"
    }
  }
}
```

### Common error codes
- `unauthorized`
- `forbidden`
- `invalid_request`
- `not_found`
- `conflict`
- `internal_error`

---

# 1. Child Profile Contracts

## 1.1 Get active child profiles

### Endpoint
`GET /api/child-profiles`

### Purpose
Return child profiles accessible to the authenticated user.

### Response
```json
{
  "childProfiles": [
    {
      "id": "cp_123",
      "displayName": "Ava",
      "ageBand": "7-9",
      "readingLevel": null,
      "isDefault": true,
      "createdAt": "2026-04-06T10:00:00.000Z",
      "updatedAt": "2026-04-06T10:00:00.000Z"
    }
  ]
}
```

### Notes
- Milestone 1 can assume only 1 active child is selected client-side.
- `isDefault` is useful for startup resolution.

---

## 1.2 Create child profile

### Endpoint
`POST /api/child-profiles`

### Request
```json
{
  "displayName": "Ava",
  "ageBand": "7-9",
  "readingLevel": null,
  "isDefault": true
}
```

### Response
```json
{
  "childProfile": {
    "id": "cp_123",
    "displayName": "Ava",
    "ageBand": "7-9",
    "readingLevel": null,
    "isDefault": true,
    "createdAt": "2026-04-06T10:00:00.000Z",
    "updatedAt": "2026-04-06T10:00:00.000Z"
  }
}
```

### Validation rules
- `displayName` required, non-empty
- `ageBand` required for MVP
- `readingLevel` optional

---

# 2. Books Listing Contracts

## 2.1 Get books with child-aware progress

### Endpoint
`GET /api/books?childProfileId=cp_123&page=1&perPage=20`

### Purpose
Return published books enriched with progress state for the active child.

### Response
```json
{
  "books": [
    {
      "id": "101",
      "title": "The Little Prince",
      "author": "Antoine de Saint-Exupéry",
      "coverUrl": "https://...",
      "description": "...",
      "totalPages": 24,
      "metadata": {},
      "hasSoundscape": true,
      "hasNarration": true,
      "hasQuestions": true,
      "progress": {
        "currentPage": 7,
        "progressPercent": 29,
        "lastReadAt": "2026-04-06T11:15:00.000Z",
        "completedAt": null,
        "completionCount": 0,
        "status": "in_progress"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "perPage": 20,
    "total": 1,
    "totalPages": 1
  }
}
```

### `progress.status` values
- `new`
- `in_progress`
- `completed`

### Notes
- `hasNarration` is especially useful for deciding whether to show `Play` in Flutter preview surfaces.
- `hasQuestions` is a future-proof flag for end-of-book comprehension UX.

---

# 3. Reading Progress Contracts

## 3.1 Get progress for a child + book

### Endpoint
`GET /api/reading-progress?childProfileId=cp_123&bookId=101`

### Purpose
Return the latest saved progress for one child/book pair.

### Response when progress exists
```json
{
  "progress": {
    "childProfileId": "cp_123",
    "bookId": "101",
    "currentPage": 7,
    "totalPages": 24,
    "progressPercent": 29,
    "lastReadAt": "2026-04-06T11:15:00.000Z",
    "completedAt": null,
    "completionCount": 0,
    "lastSessionId": "rs_abc123",
    "status": "in_progress"
  }
}
```

### Response when no progress exists
```json
{
  "progress": null
}
```

### Notes
- Flutter should use this to restore reading state when opening a book directly.
- `status` should match the values described above.

---

## 3.2 Save/update progress for a child + book

### Endpoint
`POST /api/reading-progress`

### Purpose
Save the latest progress snapshot for the current child/book.

### Request
```json
{
  "childProfileId": "cp_123",
  "bookId": "101",
  "currentPage": 7,
  "totalPages": 24,
  "lastSessionId": "rs_abc123",
  "completed": false,
  "source": "mobile"
}
```

### Response
```json
{
  "progress": {
    "childProfileId": "cp_123",
    "bookId": "101",
    "currentPage": 7,
    "totalPages": 24,
    "progressPercent": 29,
    "lastReadAt": "2026-04-06T11:15:00.000Z",
    "completedAt": null,
    "completionCount": 0,
    "lastSessionId": "rs_abc123",
    "status": "in_progress"
  }
}
```

### Validation rules
- `childProfileId` required
- `bookId` required
- `currentPage` must be >= 1
- `totalPages` must be >= 1
- `currentPage` should not exceed `totalPages`
- `source` optional in MVP, default `mobile`

### Completion behavior
If `completed: true`:
- backend may set `completedAt` if not already set for the latest completion
- backend may increment `completionCount` when transitioning into completed state

### Mobile usage notes
This endpoint is intended for:
- debounced page-save writes
- final save on exit
- final save on book completion

It is **not** the canonical session log endpoint.

---

# 4. Reading Session Contracts

## 4.1 Create/finalize a reading session

### Endpoint
`POST /api/reading-sessions`

### Purpose
Persist one canonical completed or finalized reading session.

### Request
```json
{
  "sessionId": "rs_abc123",
  "childProfileId": "cp_123",
  "bookId": "101",
  "startedAt": "2026-04-06T11:00:00.000Z",
  "endedAt": "2026-04-06T11:15:00.000Z",
  "startPage": 1,
  "endPage": 7,
  "entryIntent": "autoplay_narration",
  "usedNarration": true,
  "usedPracticeMode": false,
  "completedBook": false,
  "source": "mobile",
  "metadata": {
    "appVersion": "3.1.1+2"
  }
}
```

### Response
```json
{
  "readingSession": {
    "sessionId": "rs_abc123",
    "childProfileId": "cp_123",
    "bookId": "101",
    "startedAt": "2026-04-06T11:00:00.000Z",
    "endedAt": "2026-04-06T11:15:00.000Z",
    "durationSeconds": 900,
    "startPage": 1,
    "endPage": 7,
    "entryIntent": "autoplay_narration",
    "usedNarration": true,
    "usedPracticeMode": false,
    "completedBook": false,
    "source": "mobile"
  }
}
```

### `entryIntent` values
- `standard`
- `autoplay_narration`

### Validation rules
- `sessionId` required and idempotent
- `childProfileId` required
- `bookId` required
- `startedAt` required
- `endedAt` required
- `endedAt >= startedAt`
- `startPage >= 1`
- `endPage >= 1`

### Idempotency behavior
If a session with the same `sessionId` already exists:
- backend should upsert or safely reject duplicate writes with deterministic behavior
- preferred MVP behavior: upsert by `sessionId`

### Mobile usage notes
Flutter should call this endpoint:
- on reader exit
- on completion
- on app background termination if safe to finalize

Not on every page change.

---

# 5. Continue Reading Resolution Contract

## 5.1 Get current continue-reading target

### Endpoint
`GET /api/continue-reading?childProfileId=cp_123`

### Purpose
Return the single best in-progress book to feature as `Continue Reading` in the library.

### Response when present
```json
{
  "continueReading": {
    "book": {
      "id": "101",
      "title": "The Little Prince",
      "author": "Antoine de Saint-Exupéry",
      "coverUrl": "https://...",
      "totalPages": 24,
      "hasNarration": true
    },
    "progress": {
      "currentPage": 7,
      "progressPercent": 29,
      "lastReadAt": "2026-04-06T11:15:00.000Z",
      "status": "in_progress"
    }
  }
}
```

### Response when absent
```json
{
  "continueReading": null
}
```

### Resolution rule
For MVP, choose the most recently updated `in_progress` book for the child.

### Notes
This endpoint is optional if the books endpoint already returns enough data, but it simplifies Flutter greatly.

---

# 6. Comprehension Contracts (Forward-Compatible)

These may ship after Flutter Milestone 1, but should be designed now.

## 6.1 Get book questions

### Endpoint
`GET /api/books/101/questions`

### Response
```json
{
  "questions": [
    {
      "id": "q_1",
      "bookId": "101",
      "questionText": "Why did the little prince leave his planet?",
      "questionType": "multiple_choice",
      "sortOrder": 1,
      "options": [
        { "id": "q_1_a", "optionKey": "A", "optionText": "To find new friends" },
        { "id": "q_1_b", "optionKey": "B", "optionText": "To buy a spaceship" },
        { "id": "q_1_c", "optionKey": "C", "optionText": "To go to school" }
      ]
    }
  ]
}
```

---

## 6.2 Submit comprehension answers

### Endpoint
`POST /api/comprehension`

### Request
```json
{
  "childProfileId": "cp_123",
  "bookId": "101",
  "readingSessionId": "rs_abc123",
  "answers": [
    {
      "questionId": "q_1",
      "selectedAnswer": "A"
    }
  ],
  "source": "mobile"
}
```

### Response
```json
{
  "result": {
    "bookId": "101",
    "childProfileId": "cp_123",
    "totalQuestions": 1,
    "correctCount": 1,
    "scorePercent": 100,
    "submittedAt": "2026-04-06T11:20:00.000Z"
  }
}
```

---

# 7. Summary Reporting Contract (Forward-Compatible)

## 7.1 Child summary

### Endpoint
`GET /api/reports/summary?childProfileId=cp_123&range=30d`

### Response
```json
{
  "summary": {
    "childProfileId": "cp_123",
    "range": "30d",
    "booksStarted": 5,
    "booksCompleted": 2,
    "totalSessions": 12,
    "totalReadingMinutes": 144,
    "averageSessionMinutes": 12,
    "comprehensionAttempts": 4,
    "averageComprehensionScore": 82
  }
}
```

### Notes
This is more web/reporting oriented, but documenting it now helps ensure canonical mobile writes can power later summaries.

---

# 8. Validation and Status Codes by Endpoint

## `GET /api/child-profiles`
- `200` success
- `401` unauthenticated

## `POST /api/child-profiles`
- `201` created
- `400` invalid payload
- `401` unauthenticated

## `GET /api/books`
- `200` success
- `400` invalid query params
- `401` if auth is required for child-aware mode
- `403` child access violation

## `GET /api/reading-progress`
- `200` success
- `400` missing `childProfileId` or `bookId`
- `401` unauthenticated
- `403` forbidden

## `POST /api/reading-progress`
- `200` success
- `400` invalid payload
- `401` unauthenticated
- `403` forbidden

## `POST /api/reading-sessions`
- `200` success
- `400` invalid payload
- `401` unauthenticated
- `403` forbidden

---

# 9. Flutter Integration Notes

## Progress saving rhythm
Flutter should use:
- local cache immediately
- debounced `POST /api/reading-progress` during reading
- final `POST /api/reading-progress` on exit/completion
- one `POST /api/reading-sessions` per finalized session

## Reader startup
Flutter should be able to pass:
- `bookId`
- `resumePage`
- `entryIntent`

## Library surfaces enabled by these contracts
These contracts support:
- continue-reading card
- progress-aware preview popup
- **Play** icon button on preview popup
- `Read` vs `Play` entry tracking
- in-progress and completed status chips

---

# 10. Recommended Backend Implementation Order

1. `GET/POST /api/child-profiles`
2. update `GET/POST /api/reading-progress`
3. update `GET /api/books` for child-aware progress
4. add `POST /api/reading-sessions`
5. optionally add `GET /api/continue-reading`
6. later add comprehension and summary endpoints

---

# Summary

These contracts give Flutter everything needed for Proof-Test Milestone 1:
- active child context
- progress-aware books listing
- progress read/write support
- canonical reading session logging
- a clean path for continue-reading UX
- a clean path for the upgraded library popup with **Play** and `Read`

They also preserve a straightforward growth path into:
- comprehension checks
- reporting
- school and clinic summaries
- richer institutional workflows
