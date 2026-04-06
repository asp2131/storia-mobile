# Self-Improvement Protocol

This protocol defines how the storia-mobile agent harness evolves itself over time. Based on IndyDevDan's "agents that improve upon themselves" pattern.

## The Evolution Loop

```
┌─────────────────────────────────────────────┐
│              GOAL COMPLETED                  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         1. COLLECT RETROSPECTIVE            │
│  Each lead reports: worked / failed / learn  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         2. UPDATE EXPERTISE FILES           │
│  Add patterns, anti-patterns, conventions    │
│  Prune stale entries (keep under 7K tokens)  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         3. REFINE AGENT PROMPTS             │
│  Sharpen ambiguous instructions              │
│  Add missing conventions                     │
│  Remove obvious/unused instructions          │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         4. UPDATE HARNESS PROTOCOLS         │
│  Adjust model assignments                    │
│  Refine Till-Done patterns                   │
│  Add/modify pipeline chains                  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│         5. LOG EVOLUTION                    │
│  Append to changelog.md                      │
│  Update metrics.json                         │
│  Track before/after for reversibility        │
└─────────────────────────────────────────────┘
```

## What Gets Improved

### Expertise Files (`.pi/expertise/*.md`)
These are the agent "mental models" — hotloaded into system prompts. They contain:
- **Patterns**: "When building X, use Y because Z"
- **Anti-patterns**: "Never do X because Y happened"  
- **Conventions**: "In this codebase, always X"
- **Gotchas**: "Watch out for X when doing Y"

### Agent Definitions (`.pi/agents/storia-team/*.md`)
The system prompts themselves evolve:
- Clearer instructions based on observed confusion
- New rules based on repeated mistakes
- Removed rules that wasted context without adding value

### Pipeline Chains (`.pi/agents/agent-chain.yaml`)
Workflows get refined:
- New chains for recurring task patterns
- Adjusted step order based on dependency discovery
- Model assignments tuned per pipeline

## Evolution Rules

1. **One change at a time** — Mutate one thing per evolution cycle
2. **Evidence required** — Every change must cite the failure/success that triggered it
3. **Reversible** — Log the previous state so changes can be reverted
4. **Budget-aware** — Total expertise tokens per agent must stay under 7K
5. **No speculation** — Don't add rules for hypothetical scenarios
6. **Compound learning** — Patterns proven across 3+ tasks get promoted to agent definitions

## Metrics Tracked

```json
{
  "evolution_cycle": 1,
  "date": "2026-04-06",
  "tasks_completed": 0,
  "worker_failures": 0,
  "lead_takeovers": 0,
  "patterns_added": 0,
  "patterns_pruned": 0,
  "prompt_changes": 0,
  "expertise_tokens": {
    "ui-lead": 0,
    "feature-lead": 0,
    "infra-lead": 0,
    "quality-lead": 0,
    "view-generator": 0,
    "animation-specialist": 0,
    "state-architect": 0,
    "reader-engine": 0,
    "game-builder": 0,
    "route-wirer": 0,
    "theme-enforcer": 0,
    "test-writer": 0,
    "a11y-auditor": 0,
    "perf-validator": 0
  }
}
```

## When Self-Improvement Runs

| Trigger | Pipeline | Depth |
|---------|----------|-------|
| After every `build-feature` | Automatic | Full retrospective |
| After every `fix-bug` | Automatic | Focused on root cause |
| After every `rapid-build` | Automatic | Quick retrospective |
| Manual `/evolve` command | On-demand | Deep review of weakest agent |
| After 5 consecutive successes | Automatic | Promote patterns to definitions |
| After any lead takeover | Automatic | Investigate worker failure |
