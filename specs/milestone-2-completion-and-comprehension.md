# Plan: Milestone 2 — Completion Handoff & End-of-Book Comprehension

## Task Description
Implement the second proof-test milestone for Storia Kids: after a child finishes reading a book, present a completion handoff sheet with next-step options (play again, read again, quick questions, back to library), then flow into an end-of-book comprehension check UI. This milestone builds directly on the Milestone 1 foundation (active child context, session coordinator, progress persistence, reader entry intents) and adds the first measurable learning-outcome layer.

## Objective
When this plan is complete, Storia can:
- Show a polished completion handoff sheet after the final page celebration
- Offer "Play again", "Read again", "Quick questions", and "Back to library" actions
- Fetch comprehension questions from the backend for a given book
- Present a child-friendly, one-question-per-screen flow with large tap targets
- Submit answers and display a friendly score summary
- Track comprehension events through the analytics layer
- Store comprehension attempts via the backend API

## Problem Statement
Milestone 1 established reading session recording and progress persistence. However, Storia still cannot demonstrate *learning outcomes* — the single most persuasive metric for school and ABA clinic buyers. The reader's existing celebration animation plays, then the child simply exits. There is no handoff into comprehension, no outcome capture, and no completion summary. This milestone closes that gap with the minimum viable comprehension flow.

## Solution Approach
1. **Completion handoff sheet** — After the existing celebration confetti/GIF, surface a bottom sheet with next-step actions. One of those actions triggers the question flow if questions exist for the book.
2. **Comprehension feature module** — New `lib/src/features/comprehension/` with domain models, repository, providers, and UI (question screen + result summary).
3. **Backend integration** — Use the already-designed API contracts (`GET /api/books/:bookId/questions`, `POST /api/comprehension`) from `specs/proof-test/backend-api-contracts.md`.
4. **Analytics extension** — Add comprehension-specific events to `AnalyticsService`.
5. **Coordinator extension** — Extend `ReadingSessionCoordinator` to expose the session ID for comprehension linking.

## Relevant Files
Use these files to complete the task:

### Existing files to modify
- `lib/src/features/reader/reader_screen.dart` — Wire completion handoff sheet after celebration ends
- `lib/src/features/reader/runtime/reader_view_state.dart` — May need a `completionAcknowledged` flag to gate handoff timing
- `lib/src/features/reader/runtime/reader_session_impl.dart` — Ensure completion state transitions cleanly to handoff
- `lib/src/features/reader/application/reading_session_coordinator.dart` — Expose session ID + book ID for comprehension linking
- `lib/src/core/analytics/analytics_service.dart` — Add comprehension event methods
- `lib/src/routing/app_router.dart` — Add comprehension route
- `lib/src/data/providers.dart` — May need comprehension provider registration

### New Files
- `lib/src/features/comprehension/domain/book_question.dart` — BookQuestion + BookQuestionOption models
- `lib/src/features/comprehension/domain/comprehension_result.dart` — ComprehensionResult + QuestionAnswer models
- `lib/src/features/comprehension/data/comprehension_repository.dart` — Fetch questions, submit answers
- `lib/src/features/comprehension/providers/comprehension_providers.dart` — Riverpod providers for questions + submission
- `lib/src/features/comprehension/presentation/comprehension_screen.dart` — One-question-per-page flow
- `lib/src/features/comprehension/presentation/widgets/question_card.dart` — Single question + options widget
- `lib/src/features/comprehension/presentation/widgets/comprehension_result_card.dart` — Score summary at end
- `lib/src/features/reader/presentation/widgets/completion_handoff_sheet.dart` — Post-celebration action sheet

## Implementation Phases
### Phase 1: Foundation
- Domain models for questions and comprehension results
- Comprehension repository with backend integration
- Analytics service extension with comprehension events
- Riverpod providers for question fetching and answer submission

### Phase 2: Core Implementation
- Completion handoff sheet widget (UI Lead)
- Comprehension screen with question flow (UI Lead)
- Reader screen integration — surface handoff after celebration (Feature Lead)
- Route wiring for comprehension screen (Feature Lead)
- Session coordinator extension for comprehension linking (Feature Lead)

### Phase 3: Integration & Polish
- End-to-end flow testing: reader → celebration → handoff → questions → result → library
- Accessibility audit on question flow (large tap targets, semantics, contrast)
- Performance validation on question fetching (no jank during handoff transition)
- Widget and unit tests for repository, providers, and key widgets

## Team Orchestration

- The `storia-orchestrator` executes this plan by delegating to team leads.
- The orchestrator NEVER writes code directly — it uses `Task` and `Task*` tools to deploy team members.
- Leads manage their workers internally. The orchestrator communicates with leads, not workers.
- The orchestrator tracks progress via TaskList and verifies acceptance criteria before marking tasks complete.
- Each task below maps to a `TaskCreate` call. Dependencies map to `addBlockedBy`. Assignments map to `owner`.

### Delegation Flow
```
storia-orchestrator
├── infra-lead        → comprehension repository, API integration
├── feature-lead      → session coordinator extension, providers, routing, reader integration
│   ├── state-architect   (comprehension providers)
│   └── route-wirer       (comprehension route)
├── ui-lead           → completion handoff sheet, question flow UI, result card
│   ├── view-generator    (new screens/widgets)
│   └── animation-specialist (handoff transition, question card animations)
└── quality-lead      → tests, a11y, performance
    ├── test-writer       (unit/widget tests)
    ├── a11y-auditor      (question flow accessibility)
    └── perf-validator    (transition performance)
```

### Team Members

- Lead
  - Name: infra-lead-comprehension-api
  - Role: Comprehension repository, API client for questions and submissions
  - Agent Type: infra-lead
  - Resume: true

- Lead
  - Name: feature-lead-comprehension-logic
  - Role: Providers, reader integration, session coordinator extension, routing
  - Agent Type: feature-lead
  - Resume: true

- Lead
  - Name: ui-lead-comprehension-ux
  - Role: Completion handoff sheet, question flow screen, result summary, animations
  - Agent Type: ui-lead
  - Resume: true

- Lead
  - Name: quality-lead-comprehension-validation
  - Role: Tests, accessibility, performance for all milestone 2 deliverables
  - Agent Type: quality-lead
  - Resume: true

## Step by Step Tasks

### 1. Create comprehension domain models
- **Task ID**: create-comprehension-models
- **Depends On**: none
- **Assigned To**: infra-lead-comprehension-api
- **Agent Type**: infra-lead
- **Parallel**: true
- **Acceptance Criteria**: `BookQuestion`, `BookQuestionOption`, `ComprehensionResult`, and `QuestionAnswer` models exist with `fromJson`/`toJson` methods matching the API contract in `specs/proof-test/backend-api-contracts.md` sections 6.1 and 6.2
- Create `lib/src/features/comprehension/domain/book_question.dart` with `BookQuestion` (id, bookId, questionText, questionType, sortOrder, options list) and `BookQuestionOption` (id, optionKey, optionText, sortOrder)
- Create `lib/src/features/comprehension/domain/comprehension_result.dart` with `ComprehensionResult` (bookId, childProfileId, totalQuestions, correctCount, scorePercent, submittedAt) and `QuestionAnswer` (questionId, selectedAnswer, isCorrect)
- Follow existing patterns from `BookProgress.fromJson` for JSON parsing style (support both camelCase and snake_case keys)

### 2. Create comprehension repository
- **Task ID**: create-comprehension-repository
- **Depends On**: create-comprehension-models
- **Assigned To**: infra-lead-comprehension-api
- **Agent Type**: infra-lead
- **Parallel**: false
- **Acceptance Criteria**: Repository has `fetchBookQuestions(bookId)` returning `Future<List<BookQuestion>>` and `submitAnswers(...)` returning `Future<ComprehensionResult>`. Uses Supabase client or HTTP client consistent with existing repositories.
- Create `lib/src/features/comprehension/data/comprehension_repository.dart`
- `fetchBookQuestions(String bookId)` → `GET /api/books/{bookId}/questions`
- `submitAnswers({childProfileId, bookId, readingSessionId?, answers})` → `POST /api/comprehension`
- Follow existing `ProgressRepository` and `ReadingSessionRepository` patterns for error handling and client usage

### 3. Extend analytics service with comprehension events
- **Task ID**: extend-analytics-comprehension
- **Depends On**: none
- **Assigned To**: infra-lead-comprehension-api
- **Agent Type**: infra-lead
- **Parallel**: true
- **Acceptance Criteria**: `AnalyticsService` has `trackComprehensionStarted`, `trackComprehensionCompleted`, and `trackComprehensionQuestionAnswered` methods with child/book/session properties
- Add to `lib/src/core/analytics/analytics_service.dart`:
  - `trackComprehensionStarted({childId, bookId, sessionId, totalQuestions})`
  - `trackComprehensionQuestionAnswered({childId, bookId, questionId, isCorrect})`
  - `trackComprehensionCompleted({childId, bookId, sessionId, correctCount, totalQuestions, scorePercent})`

### 4. Create comprehension Riverpod providers
- **Task ID**: create-comprehension-providers
- **Depends On**: create-comprehension-repository
- **Assigned To**: feature-lead-comprehension-logic
- **Agent Type**: feature-lead
- **Parallel**: false
- **Acceptance Criteria**: `bookQuestionsProvider(bookId)` returns `AsyncValue<List<BookQuestion>>`. `comprehensionSubmissionProvider` (or notifier) handles answer collection and submission. Providers follow existing Riverpod patterns in `lib/src/features/progress/providers/`.
- Create `lib/src/features/comprehension/providers/comprehension_providers.dart`
- `bookQuestionsProvider` — family provider keyed by bookId, fetches questions via repository
- `comprehensionFlowNotifier` or similar — tracks current question index, collected answers, submission state
- Wire repository via provider, consistent with existing data layer patterns

### 5. Extend session coordinator for comprehension linking
- **Task ID**: extend-coordinator-comprehension
- **Depends On**: none
- **Assigned To**: feature-lead-comprehension-logic
- **Agent Type**: feature-lead
- **Parallel**: true
- **Acceptance Criteria**: `ReadingSessionCoordinator` exposes a `completedSessionId` and `completedBookId` getter that returns the session/book ID after `onBookCompleted()` is called, before the draft is finalized. This data is needed to link comprehension attempts to reading sessions.
- Modify `lib/src/features/reader/application/reading_session_coordinator.dart`
- Add `String? get completedSessionId` and `String? get completedBookId` that return IDs from the current draft when `completedBook == true`
- Ensure `finalizeAndSave()` still works — comprehension flow may happen before or after finalization depending on timing

### 6. Build completion handoff sheet
- **Task ID**: build-completion-handoff
- **Depends On**: extend-coordinator-comprehension
- **Assigned To**: ui-lead-comprehension-ux
- **Agent Type**: ui-lead
- **Parallel**: true (can start alongside comprehension screen)
- **Acceptance Criteria**: Bottom sheet appears after celebration animation ends. Shows 4 actions: "Play again", "Read again", "Quick questions" (only if book has questions), "Back to library". Sheet is dismissible. Follows Storia visual language (warm colors, rounded shapes, child-friendly).
- Create `lib/src/features/reader/presentation/widgets/completion_handoff_sheet.dart`
- Actions:
  - "Play again" → re-enter reader with `autoplayNarration` intent from page 1
  - "Read again" → re-enter reader with `standard` intent from page 1
  - "Quick questions" → navigate to comprehension screen (only shown if `hasQuestions` is true)
  - "Back to library" → pop to library
- Large tap targets (minimum 48x48, prefer larger for children)
- Friendly copy: "Great job finishing the story!" header
- Use Storia color palette and typography

### 7. Build comprehension question screen
- **Task ID**: build-comprehension-screen
- **Depends On**: create-comprehension-providers
- **Assigned To**: ui-lead-comprehension-ux
- **Agent Type**: ui-lead
- **Parallel**: true (can start alongside handoff sheet)
- **Acceptance Criteria**: Screen shows one question at a time. Progress indicator ("1 of 3"). Large option buttons. Selecting an answer advances to next question automatically (with brief delay for feedback). After last question, shows result card. No school-test anxiety — affirming, warm, brief.
- Create `lib/src/features/comprehension/presentation/comprehension_screen.dart`
- Create `lib/src/features/comprehension/presentation/widgets/question_card.dart` — single question with options as large tappable cards
- Create `lib/src/features/comprehension/presentation/widgets/comprehension_result_card.dart` — friendly score summary ("You got 2 out of 3!")
- Design principles: brief, affirming, low-pressure, highly tappable, no school-test anxiety vibe
- Progress indicator at top: "1 of 3" or dots
- Option selection: highlight selected, brief positive feedback animation, advance after short delay
- Result card actions: "Back to library", optional "Read again"

### 8. Wire comprehension route
- **Task ID**: wire-comprehension-route
- **Depends On**: build-comprehension-screen
- **Assigned To**: feature-lead-comprehension-logic
- **Agent Type**: feature-lead
- **Parallel**: false
- **Acceptance Criteria**: `/comprehension/:bookId` route exists in `app_router.dart`. Route accepts `bookId` path param and `sessionId` + `childProfileId` as query params or extra. Navigation from handoff sheet reaches comprehension screen correctly.
- Add route to `lib/src/routing/app_router.dart`:
  ```dart
  GoRoute(
    path: '/comprehension/:bookId',
    builder: (context, state) {
      final bookId = state.pathParameters['bookId'] ?? '';
      return ComprehensionScreen(bookId: bookId);
    },
  ),
  ```
- Pass `sessionId` and `childProfileId` via GoRouter extra or query params

### 9. Integrate handoff sheet into reader screen
- **Task ID**: integrate-handoff-reader
- **Depends On**: build-completion-handoff, wire-comprehension-route
- **Assigned To**: feature-lead-comprehension-logic
- **Agent Type**: feature-lead
- **Parallel**: false
- **Acceptance Criteria**: After celebration animation completes in `ReaderScreen`, the completion handoff sheet appears automatically. "Quick questions" navigates to comprehension screen with correct bookId/sessionId/childProfileId. "Back to library" pops to `/library`. "Play again" and "Read again" restart reader appropriately.
- Modify `lib/src/features/reader/reader_screen.dart`:
  - In `_onRuntimeStateChanged`, detect when celebration ends (transition from `showCelebration: true` to `false`, or after a timed delay)
  - Show `CompletionHandoffSheet` via `showModalBottomSheet`
  - Pass `hasQuestions` flag (from book data or a new provider), `bookId`, `sessionId`, `childProfileId`
  - Handle each action callback with appropriate navigation
- Timing: show handoff after celebration GIF completes (not immediately — let the celebration breathe)

### 10. Validate all — tests, a11y, performance
- **Task ID**: validate-all
- **Depends On**: integrate-handoff-reader
- **Assigned To**: quality-lead-comprehension-validation
- **Agent Type**: quality-lead
- **Parallel**: false
- **Acceptance Criteria**: `flutter analyze` clean (no new warnings), all tests pass, comprehension flow accessible (semantics labels, contrast, focus order), handoff transition under 16ms frame budget
- **Unit tests**:
  - `BookQuestion.fromJson` / `ComprehensionResult.fromJson` round-trip
  - `ComprehensionRepository` mock tests for fetch and submit
  - `ReadingSessionCoordinator.completedSessionId` returns correct value
- **Widget tests**:
  - `CompletionHandoffSheet` shows/hides "Quick questions" based on `hasQuestions`
  - `QuestionCard` renders question text and options, responds to tap
  - `ComprehensionResultCard` shows correct score
- **A11y audit**:
  - All interactive elements have semantic labels
  - Option buttons meet minimum 48x48 touch target
  - Contrast ratios pass WCAG AA
  - Focus order logical through question flow
- **Performance**:
  - Handoff sheet transition smooth (no dropped frames)
  - Question fetching does not block UI (async with loading state)
- Run `flutter analyze` and `flutter test`

## Acceptance Criteria

### Completion Handoff
- Handoff sheet appears after celebration animation ends
- Shows "Play again", "Read again", "Quick questions" (conditional), "Back to library"
- "Quick questions" only visible when book has questions
- Each action navigates correctly

### Comprehension Flow
- Questions fetched from backend for the given book
- One question shown per screen with progress indicator
- Large tappable option cards (child-friendly sizing)
- Selection feedback is affirming, not punitive
- After all questions, friendly result summary shown
- Results submitted to backend with childProfileId, bookId, sessionId

### Analytics
- `comprehension_started` fires when entering question flow
- `comprehension_question_answered` fires per question
- `comprehension_completed` fires with score summary
- All events include child ID, book ID, session ID

### Data Integrity
- Comprehension attempts link to the reading session that triggered them
- Results persist to backend via `POST /api/comprehension`
- Failed submissions handled gracefully (retry or queue)

## Validation Commands
Execute these commands to validate the task is complete:

- `flutter analyze` — No new warnings or errors
- `flutter test` — All tests pass
- `flutter test test/features/comprehension/` — Comprehension-specific tests pass
- Manual verification: complete a book → see handoff → tap "Quick questions" → answer questions → see result → return to library

## Notes
- Backend must have `GET /api/books/:bookId/questions` and `POST /api/comprehension` endpoints ready. If not, repository should return mock data behind a feature flag or environment check so UI development can proceed.
- The comprehension flow should feel like a game reward, not a test. Copy and visual design should reinforce this.
- Question data is expected to come from backend seeded by content team. MVP can use 2-3 hardcoded questions per book if backend isn't ready.
- No new packages expected — existing Flutter/Riverpod/GoRouter stack sufficient.
- `hasQuestions` flag per book: if not yet on the books API response, can derive from a local questions-fetch check, or hardcode `true` for seeded books in MVP.
