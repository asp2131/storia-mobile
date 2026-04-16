# Plan: Milestone 2 — Close Remaining Gaps

## Task Description
Close 5 remaining gaps in the Milestone 2 (comprehension + completion handoff) feature set, in severity order:

1. **HIGH — Celebration only fires on practice mode**: Confetti/GIF celebration triggers only via speech recognition (`showCelebration` in `ReaderSessionImpl._startListening`), not on natural last-page arrival. Users who finish a book without practice mode see no celebration before the handoff sheet.
2. **MEDIUM — No backend admin API for question authoring**: Questions can only be managed via direct DB or seed. No POST/PATCH/DELETE endpoints exist for creating/editing `book_question` and `book_question_option` records.
3. **MEDIUM — `hasQuestions` flag missing from Flutter book listing**: Backend `GET /api/books` already returns `hasQuestions` (line 184 of `storia/src/app/api/books/route.ts`). Flutter `Book.fromLibraryJson` already parses it (line 270–272 of `models.dart`). **Re-investigation needed**: the backend IS returning it. The gap may be in the `ComprehensionRepository` using Supabase functions instead of `ApiClient` — questions endpoint not routed through the HTTP API client.
4. **MEDIUM — E2E test coverage thin**: Zero tests exist for comprehension flow, completion handoff, or question card widgets.
5. **LOW — No personalization in handoff**: `CompletionHandoffSheet` shows generic "Great job finishing the story!" without child name or session summary.

## Objective
When complete:
- Book completion celebration triggers for ALL reading modes (standard, narration, practice)
- Backend exposes CRUD endpoints for question authoring
- `ComprehensionRepository` uses `ApiClient` HTTP path (not just Supabase functions) for questions + submission
- Comprehensive test coverage for comprehension flow, question card, completion handoff, and flow notifier
- Handoff sheet shows personalized child name and session context

## Problem Statement
Milestone 2's core code (models, repos, providers, UI, routing, analytics) is ~85% complete. The remaining gaps prevent production readiness: users get no celebration on normal reading, questions can't be authored without DB access, the comprehension repo bypasses the API client, tests don't exist, and the handoff feels generic.

## Solution Approach
Fix in severity order. Each gap maps cleanly to a domain lead:
1. Celebration trigger → **Feature Lead** (reader runtime behavior change)
2. Backend admin API → **Infra Lead** (new API routes in `../storia/`)
3. API client wiring → **Infra Lead** (update `ComprehensionRepository` to use `ApiClient`)
4. Test coverage → **Quality Lead** (widget + unit tests)
5. Personalization → **UI Lead** (handoff sheet enhancement)

## Relevant Files

### Existing Files to Modify

- `lib/src/features/reader/reader_screen.dart` — Wire celebration trigger on last-page arrival (currently only reacts to `showCelebration` from runtime stream)
- `lib/src/features/reader/runtime/reader_session_impl.dart` — Add `ReaderBookCompleted` intent handler that sets `showCelebration: true`
- `lib/src/features/reader/runtime/reader_intent.dart` — Add `ReaderBookCompleted` intent
- `lib/src/features/reader/presentation/widgets/completion_handoff_sheet.dart` — Add `childName`, `pagesRead`, `readingDuration` params
- `lib/src/features/comprehension/data/comprehension_repository.dart` — Switch from Supabase functions to `ApiClient` HTTP
- `lib/src/features/comprehension/providers/comprehension_providers.dart` — Pass `ApiClient` to repository
- `../storia/src/app/api/books/[id]/questions/route.ts` — Add POST, PATCH, DELETE handlers

### New Files to Create

- `../storia/src/app/api/books/[id]/questions/[questionId]/route.ts` — Individual question CRUD
- `test/features/comprehension/presentation/comprehension_screen_test.dart`
- `test/features/comprehension/presentation/widgets/question_card_test.dart`
- `test/features/comprehension/presentation/widgets/comprehension_result_card_test.dart`
- `test/features/comprehension/providers/comprehension_flow_notifier_test.dart`
- `test/features/reader/presentation/widgets/completion_handoff_sheet_test.dart`

## Implementation Phases

### Phase 1: Foundation (Infra)
Backend admin API for questions + API client wiring for comprehension repo. These are data-layer concerns that other work depends on (tests need working repo, etc.).

### Phase 2: Core Implementation (Feature + UI, parallel)
- Feature Lead fixes celebration trigger in reader runtime
- UI Lead personalizes completion handoff sheet

### Phase 3: Validation (Quality)
Full test suite for comprehension flow, handoff sheet, flow notifier.

## Team Orchestration

- The `storia-orchestrator` executes this plan by delegating to team leads.
- The orchestrator NEVER writes code directly — it uses `Task` and `Task*` tools to deploy team members.
- Leads manage their workers internally. The orchestrator communicates with leads, not workers.
- The orchestrator tracks progress via TaskList and verifies acceptance criteria before marking tasks complete.
- Each task below maps to a `TaskCreate` call. Dependencies map to `addBlockedBy`. Assignments map to `owner`.

### Delegation Flow
```
storia-orchestrator
├── infra-lead        → backend question CRUD, API client wiring
├── feature-lead      → celebration trigger fix
│   └── reader-engine     (reader runtime changes)
├── ui-lead           → handoff personalization
│   └── view-generator    (widget updates)
└── quality-lead      → test coverage
    └── test-writer       (widget + unit tests)
```

### Team Members

- Lead
  - Name: infra-lead-api-wiring
  - Role: Backend question CRUD endpoints + ComprehensionRepository API client migration
  - Agent Type: infra-lead
  - Resume: true

- Lead
  - Name: feature-lead-celebration
  - Role: Fix book completion celebration trigger in reader runtime
  - Agent Type: feature-lead
  - Resume: true

- Lead
  - Name: ui-lead-handoff
  - Role: Personalize completion handoff sheet with child name and session context
  - Agent Type: ui-lead
  - Resume: true

- Lead
  - Name: quality-lead-m2-tests
  - Role: Comprehensive test suite for comprehension flow and completion handoff
  - Agent Type: quality-lead
  - Resume: true

## Step by Step Tasks

### 1. Fix Book Completion Celebration Trigger
- **Task ID**: fix-celebration-trigger
- **Depends On**: none
- **Assigned To**: feature-lead-celebration
- **Agent Type**: feature-lead
- **Parallel**: true (can run alongside tasks 2 and 3)
- **Acceptance Criteria**:
  - When user reaches the last page in standard or narration mode (no practice), confetti + GIF celebration plays for 3 seconds
  - When practice mode triggers celebration on final page, behavior unchanged (no double-fire)
  - `_showCompletionHandoff()` still called after celebration clears (same lifecycle as today)
  - No regressions in mid-book practice celebration behavior

**Implementation approach — two options, pick the simpler one:**

**Option A (recommended): Handle in `reader_screen.dart` directly.**
In `onPageChanged` callback (line 228–237), after marking completion, dispatch a new `ReaderBookCompleted` intent to the runtime. The runtime handler sets `showCelebration: true` and schedules the 3-second clear. This reuses the existing celebration→handoff pipeline.

Steps:
- Add `ReaderBookCompleted` to `reader_intent.dart` (new sealed class member)
- In `reader_session_impl.dart`, handle `ReaderBookCompleted` in `dispatch()`:
  ```dart
  if (intent is ReaderBookCompleted) {
    _emit(_state.copyWith(showCelebration: true));
    _scheduleCelebrationClear();
    return;
  }
  ```
- In `reader_screen.dart` `onPageChanged`, after `onBookCompleted()`, dispatch:
  ```dart
  if (index == book.pages.length - 1 && !_completionMarked) {
    _completionMarked = true;
    ref.read(readingSessionCoordinatorProvider).onBookCompleted();
    await _session.dispatch(const ReaderBookCompleted());
  }
  ```
- This ensures celebration plays → clears → `_onRuntimeStateChanged` detects `!isCelebrating && wasCelebrating` → calls `_showCompletionHandoff()`

**Option B: Trigger celebration directly in `reader_screen.dart`.**
Skip the runtime and directly play confetti + show GIF in the `onPageChanged` handler. Downside: duplicates celebration logic and doesn't flow through the existing state stream pipeline.

**Recommendation: Option A** — cleaner, reuses existing pipeline, single source of truth for celebration state.

### 2. Add Backend Admin API for Question Authoring
- **Task ID**: backend-question-crud
- **Depends On**: none
- **Assigned To**: infra-lead-api-wiring
- **Agent Type**: infra-lead
- **Parallel**: true (can run alongside tasks 1 and 3)
- **Acceptance Criteria**:
  - `POST /api/books/[id]/questions` creates a question with options, returns created question with id
  - `PATCH /api/books/[id]/questions/[questionId]` updates question text, type, sort order, correct answer
  - `DELETE /api/books/[id]/questions/[questionId]` removes question and its options (cascade)
  - All endpoints require auth (reuse existing auth pattern from `child-auth.ts` or similar)
  - `bookId` validation consistent with existing GET handler (positive BigInt)
  - Options can be created/updated inline with question body

**Implementation details:**

Update `../storia/src/app/api/books/[id]/questions/route.ts`:
- Add `POST` handler:
  - Request body: `{ questionText, questionType, sortOrder, correctAnswer, options: [{ optionKey, optionText, sortOrder }] }`
  - Create `book_question` with nested `options` create
  - Return created question with options (same shape as GET)

Create `../storia/src/app/api/books/[id]/questions/[questionId]/route.ts`:
- `PATCH` handler:
  - Partial update of question fields
  - If `options` array provided, delete existing and recreate (simplest for MVP)
- `DELETE` handler:
  - Delete question (Prisma cascade should handle options via relation)
  - Return `{ deleted: true }`

### 3. Migrate ComprehensionRepository to ApiClient
- **Task ID**: comprehension-api-client
- **Depends On**: none
- **Assigned To**: infra-lead-api-wiring
- **Agent Type**: infra-lead
- **Parallel**: true (part of same infra-lead work as task 2, sequential within that lead)
- **Acceptance Criteria**:
  - `ComprehensionRepository` constructor accepts `ApiClient` (in addition to or instead of `SupabaseClient`)
  - `fetchBookQuestions` calls `GET /api/books/{bookId}/questions` via `ApiClient`, falls back to Supabase functions
  - `submitAnswers` calls `POST /api/comprehension` via `ApiClient`, falls back to Supabase functions
  - `comprehensionRepositoryProvider` wires up `ApiClient` from `apiClientProvider`
  - Existing behavior preserved — if API client call fails, fallback to Supabase functions path

**Implementation:**

Update `comprehension_repository.dart`:
```dart
class ComprehensionRepository {
  const ComprehensionRepository(this._supabase, this._apiClient);

  final SupabaseClient _supabase;
  final ApiClient _apiClient;

  Future<List<BookQuestion>> fetchBookQuestions(String bookId) async {
    try {
      final data = await _apiClient.get('/api/books/$bookId/questions');
      // parse questions from data
    } catch (e) {
      debugPrint('[ComprehensionRepository] API failed, falling back: $e');
      // existing Supabase functions path as fallback
    }
  }
}
```

Update `comprehension_providers.dart`:
```dart
final comprehensionRepositoryProvider = Provider<ComprehensionRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ComprehensionRepository(supabase, apiClient);
});
```

### 4. Personalize Completion Handoff Sheet
- **Task ID**: personalize-handoff
- **Depends On**: none
- **Assigned To**: ui-lead-handoff
- **Agent Type**: ui-lead
- **Parallel**: true (can run alongside tasks 1–3)
- **Acceptance Criteria**:
  - Handoff sheet title reads "Great job, {childName}!" when child name is available
  - Falls back to "Great job finishing the story!" when name unavailable
  - Session summary line shows pages read and reading time (e.g., "You read 12 pages in 8 minutes")
  - Summary only appears if data is available (graceful degradation)
  - Visual design consistent with existing `_HandoffAction` card styling

**Implementation:**

Update `CompletionHandoffSheet` constructor to accept optional params:
```dart
const CompletionHandoffSheet({
  // ...existing params...
  this.childName,
  this.pagesRead,
  this.readingDurationMinutes,
});

final String? childName;
final int? pagesRead;
final int? readingDurationMinutes;
```

Update title text:
```dart
Text(
  childName != null
    ? 'Great job, $childName!'
    : 'Great job finishing the story!',
  // ...existing style...
)
```

Add summary line below book title:
```dart
if (pagesRead != null || readingDurationMinutes != null)
  Text(
    _buildSummary(pagesRead, readingDurationMinutes),
    style: GoogleFonts.quicksand(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: StoriaColors.inkMuted,
    ),
    textAlign: TextAlign.center,
  ),
```

Update caller in `reader_screen.dart` `_showCompletionHandoff()`:
```dart
final child = ref.read(activeChildProvider).valueOrNull;
final coordinator = ref.read(readingSessionCoordinatorProvider);
final draft = coordinator.currentDraft;

CompletionHandoffSheet(
  // ...existing params...
  childName: child?.displayName,
  pagesRead: draft != null ? (draft.latestPage - draft.startPage + 1) : null,
  readingDurationMinutes: draft != null
    ? DateTime.now().difference(draft.startedAt).inMinutes
    : null,
)
```

Note: `ReadingSessionDraft` already has `startPage`, `latestPage`, and `startedAt` fields — verify these getters exist. If `latestPage` doesn't exist, use the coordinator's tracked page state.

### 5. Write Comprehension and Handoff Tests
- **Task ID**: m2-test-suite
- **Depends On**: fix-celebration-trigger, comprehension-api-client, personalize-handoff
- **Assigned To**: quality-lead-m2-tests
- **Agent Type**: quality-lead
- **Parallel**: false (must wait for implementation tasks)
- **Acceptance Criteria**:
  - `ComprehensionFlowNotifier` unit test: start → answer → submit lifecycle, reset, empty questions edge case
  - `QuestionCard` widget test: renders question text, options, progress indicator ("1 of 3"); tapping option calls callback
  - `ComprehensionResultCard` widget test: renders score, shows "Amazing!" for perfect score, buttons work
  - `CompletionHandoffSheet` widget test: renders all 4 action buttons; hides "Quick questions" when `hasQuestions: false`; shows child name when provided; shows session summary when provided
  - `ComprehensionScreen` widget test: renders loading state, handles empty questions (redirects), shows question flow
  - All tests pass with `flutter test`
  - No new analyzer warnings

**Test files to create:**

1. `test/features/comprehension/providers/comprehension_flow_notifier_test.dart`
   - Test `start()` sets status to answering, populates questions
   - Test `answerQuestion()` records answer, advances index
   - Test `answerQuestion()` on last question doesn't advance past end
   - Test `submit()` sets status to submitting then done
   - Test `reset()` clears all state

2. `test/features/comprehension/presentation/widgets/question_card_test.dart`
   - Renders question text
   - Renders all options with correct labels
   - Shows progress "1 of 3"
   - Tapping option calls `onAnswerSelected` with correct key
   - Semantic labels present for accessibility

3. `test/features/comprehension/presentation/widgets/comprehension_result_card_test.dart`
   - Renders score "You got 2 out of 3!"
   - Shows "Amazing!" for perfect score
   - Shows "Nice work!" for partial score
   - Both buttons ("Back to library", "Read another book") tap correctly

4. `test/features/reader/presentation/widgets/completion_handoff_sheet_test.dart`
   - Renders all 4 actions when `hasQuestions: true`
   - Hides "Quick questions" when `hasQuestions: false`
   - Shows personalized title "Great job, Luna!" when childName provided
   - Shows generic title when childName null
   - Shows session summary when pagesRead/readingDurationMinutes provided
   - Each action button calls its callback

5. `test/features/comprehension/presentation/comprehension_screen_test.dart`
   - Shows loading spinner while questions load
   - Handles error state with "Back to library" button
   - Redirects to library when questions list is empty

**Test patterns to follow:** Match existing test style from `test/features/library/widgets/continue_reading_card_test.dart` — plain `MaterialApp` wrapper, direct widget construction, callback verification via bool flags.

### 6. Final Validation
- **Task ID**: validate-all
- **Depends On**: fix-celebration-trigger, backend-question-crud, comprehension-api-client, personalize-handoff, m2-test-suite
- **Assigned To**: quality-lead-m2-tests
- **Agent Type**: quality-lead
- **Parallel**: false
- **Acceptance Criteria**: `flutter analyze` clean (no new warnings), all tests pass, acceptance criteria for all prior tasks verified
- Run all validation commands
- Verify acceptance criteria met
- Verify no regressions in existing tests

## Acceptance Criteria

1. **Celebration**: Confetti + GIF plays when user reaches last page in ANY mode (standard, narration, practice). No double-fire on practice mode final page.
2. **Backend CRUD**: POST/PATCH/DELETE endpoints for book questions work with auth. GET behavior unchanged.
3. **API Client**: `ComprehensionRepository` uses `ApiClient` HTTP first, Supabase fallback second. Provider wired correctly.
4. **Tests**: 5 new test files, all passing. Coverage for notifier lifecycle, widget rendering, action callbacks, edge cases.
5. **Personalization**: Handoff shows child name and session summary when available. Graceful fallback.
6. **No regressions**: `flutter analyze` clean, all existing tests pass.

## Validation Commands

Execute these commands to validate the task is complete:

```bash
# Flutter analysis — no new warnings
flutter analyze lib/src/features/reader/ lib/src/features/comprehension/ lib/src/features/reader/presentation/widgets/completion_handoff_sheet.dart

# All new tests pass
flutter test test/features/comprehension/ test/features/reader/presentation/widgets/completion_handoff_sheet_test.dart

# All existing tests still pass
flutter test

# Backend tests pass (from storia/)
cd ../storia && npx vitest run src/app/api/books/*/questions/ src/app/api/comprehension/
```

## Notes

- **No new Flutter packages needed.** All changes use existing dependencies.
- **Backend question CRUD** is MVP-scoped: inline option management (delete+recreate on update), no bulk operations, no versioning.
- **`ReadingSessionDraft` getters**: Before implementing task 4, verify that `startPage`, `latestPage`, and `startedAt` are accessible from `ReadingSessionCoordinator.currentDraft`. If `latestPage` doesn't exist as a getter, add it or use the coordinator's internal tracking.
- **Celebration guard**: The `_completionMarked` flag in `reader_screen.dart` already prevents double-fire. The `ReaderBookCompleted` intent should also be idempotent in the runtime (check `showCelebration` before re-triggering).
- **`hasQuestions` investigation**: The backend already includes `hasQuestions` in the books API response (line 184 of `books/route.ts`). The Flutter `Book.fromLibraryJson` already parses it. The real gap is that `ComprehensionRepository` calls Supabase functions instead of HTTP API — fixing task 3 should close this gap. Verify during implementation.
