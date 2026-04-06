# Model Rotation Protocol

Defines which models power each agent tier and how to handle failures.

## Default Assignment

| Tier | Role | Model | Reasoning |
|------|------|-------|-----------|
| 1 | Orchestrator | opus | Needs deep reasoning for decomposition |
| 2 | Team Leads | opus | Needs reasoning for planning + failover coding |
| 3 | Workers (builders) | sonnet | Fast execution, good code quality |
| 3 | Workers (validators) | haiku | Quick checks, cost-efficient |
| Meta | Self-improver | opus | Needs reasoning to analyze patterns |

## Rotation Rules

### On Worker Failure
```
Attempt 1: sonnet (default)
Attempt 2: sonnet (with refined prompt from lead)
Attempt 3: opus (escalate model)
Attempt 4: Lead takes over directly
```

### On Lead Failure
```
Attempt 1: opus (default)
Attempt 2: opus (with refined prompt from orchestrator)
Attempt 3: Orchestrator escalates to human
```

### On Validator Failure
```
Attempt 1: haiku (default)
Attempt 2: sonnet (escalate for complex validation)
```

## When to Rotate

- **No response** — Model returned empty or malformed output
- **Wrong domain** — Agent produced code outside its scope
- **Repeated errors** — Same compile error after 2 attempts
- **Context overflow** — Task too large for current model's effective window

## Logging

Every rotation is logged to `.pi/evolution/failures.jsonl`:
```json
{
  "timestamp": "2026-04-06T12:00:00Z",
  "agent": "view-generator",
  "task": "create BookQuiz widget",
  "original_model": "sonnet",
  "rotated_to": "opus",
  "reason": "compile error after 2 attempts",
  "outcome": "success"
}
```
