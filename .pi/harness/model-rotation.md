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

## OpenCode Go Model List

Refreshed with `opencode models opencode-go --refresh --verbose` on 2026-06-12.
`bin/opencode-symphony.sh --list-models` prints the same curated list.

| Use | Model | Notes |
|-----|-------|-------|
| Default fast/cheap | `opencode-go/qwen3.7-plus` | Latest low-cost default; 1M context, tools, reasoning |
| Cheap long-context worker | `opencode-go/minimax-m3` | Very low cost; 512K context, 131K output |
| Premium reasoning | `opencode-go/qwen3.7-max` | Stronger Qwen tier; use for escalations |
| Cheap DeepSeek reasoning | `opencode-go/deepseek-v4-flash` | 1M context, 384K output, low/medium/high/max variants |
| Premium DeepSeek reasoning | `opencode-go/deepseek-v4-pro` | Same limits as flash, higher quality/cost tier |
| Cheap fallback | `opencode-go/mimo-v2.5` | 1M context, 128K output, low/medium/high variants |
| Premium fallback | `opencode-go/mimo-v2.5-pro` | 1,048,576 context, 128K output |
| Stable fallback/current legacy | `opencode-go/kimi-k2.6` | Prior opencode-symphony default |
| GLM fallback | `opencode-go/glm-5.1` | Newer GLM tier |
| Older fallback | `opencode-go/qwen3.6-plus` | Keep for regression fallback |
| Older fallback | `opencode-go/minimax-m2.7` | Keep for regression fallback |
| Older fallback | `opencode-go/minimax-m2.5` | Keep for regression fallback |
| Older fallback | `opencode-go/glm-5` | Keep for regression fallback |
| Older fallback | `opencode-go/kimi-k2.5` | Keep for regression fallback |

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
