# Till-Done List Protocol

The Till-Done List is the core coordination pattern for the storia-mobile agent harness. It ensures tasks are **verified complete**, not just attempted.

## How It Works

### 1. Orchestrator Creates the List
```
TILL-DONE LIST: [Goal Name]
ID: TDL-001

[ ] TASK-1: Create BookQuiz widget | DOMAIN: ui | OWNER: view-generator
[ ] TASK-2: Add quizProvider | DOMAIN: feature | OWNER: state-architect  
[ ] TASK-3: Wire quiz route | DOMAIN: feature | OWNER: route-wirer
[ ] TASK-4: Write quiz tests | DOMAIN: quality | OWNER: test-writer
    DEPENDS_ON: TASK-1, TASK-2
```

### 2. Leads Delegate Items to Workers
- Each lead picks up tasks in their domain
- Parallel tasks (no dependencies) are delegated simultaneously
- Sequential tasks wait for dependencies

### 3. Workers Execute and Report
After each task, the worker reports:
```
TASK-1: DONE
  FILES_CHANGED: lib/src/features/reader/presentation/book_quiz.dart
  PROVIDERS_CONSUMED: quizProvider, bookProvider
  NOTES: Used existing SketchCard pattern for quiz cards
```

### 4. Leads Verify Completion
The lead checks each "DONE" item against acceptance criteria:
- Does the code compile?
- Does it meet the stated acceptance criteria?
- Does it follow domain conventions?

If verification fails → mark as `BLOCKED` with reason, reassign or take over.

### 5. Orchestrator Confirms All Done
Only when EVERY item is `[x]` does the orchestrator mark the goal complete.

```
TILL-DONE LIST: [Goal Name] ✓ COMPLETE
[x] TASK-1: Create BookQuiz widget — VERIFIED by ui-lead
[x] TASK-2: Add quizProvider — VERIFIED by feature-lead
[x] TASK-3: Wire quiz route — VERIFIED by feature-lead
[x] TASK-4: Write quiz tests — VERIFIED by quality-lead
```

### 6. Self-Improver Triggered
Orchestrator passes the completed list to self-improver for retrospective.

## States

| State | Symbol | Meaning |
|-------|--------|---------|
| Pending | `[ ]` | Not yet started |
| In Progress | `[~]` | Worker is executing |
| Done | `[x]` | Completed and verified by lead |
| Blocked | `[!]` | Failed — needs reassignment or lead takeover |
| Skipped | `[-]` | No longer needed (scope change) |

## Failure Recovery

1. Worker fails → Lead retries with clearer prompt
2. Worker fails again → Lead takes over directly
3. Lead fails → Orchestrator escalates to human
4. Every failure is logged to `.pi/evolution/failures.jsonl`
