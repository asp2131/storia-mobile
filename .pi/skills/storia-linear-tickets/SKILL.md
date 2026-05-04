---
name: storia-linear-tickets
description: Use when creating, viewing, listing, or updating Linear tickets for the Storia Mobile project from this repository.
---

# Storia Linear Tickets

## Overview

Use this skill for direct Linear ticket operations for `storia-mobile`. It relies on `LINEAR_API_KEY` from the environment and defaults to the repo's Linear project slug from `WORKFLOW.md`: `storia-web-b2f648c17c65`.

Canonical helper:

```bash
.pi/skills/storia-linear-tickets/linear_ticket.py --help
```

The helper is dependency-free Python 3 and talks to `https://api.linear.app/graphql`.

## Before You Run Anything

1. Confirm the key exists; never print it:
   ```bash
   test -n "$LINEAR_API_KEY" || echo "LINEAR_API_KEY is missing"
   ```
2. Stay scoped to the Storia Mobile project unless the user explicitly asks otherwise.
3. Prefer adding a ticket over expanding the scope of an unrelated code change.
4. Use exact workflow state names from the project, for example `Backlog`, `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`, or `Duplicate`.

## Quick Commands

```bash
# List recent Storia Mobile tickets
.pi/skills/storia-linear-tickets/linear_ticket.py list

# Search tickets
.pi/skills/storia-linear-tickets/linear_ticket.py list --query "reader audio"

# View a ticket
.pi/skills/storia-linear-tickets/linear_ticket.py view STO-123

# Create a ticket
.pi/skills/storia-linear-tickets/linear_ticket.py create \
  --title "Fix reader audio resume after pause" \
  --description "Observed behavior, expected behavior, acceptance criteria." \
  --state "Backlog"

# Update title/state/description and add a comment
.pi/skills/storia-linear-tickets/linear_ticket.py update STO-123 \
  --state "In Progress" \
  --comment "Started investigation in local worktree."

# Get raw JSON for automation
.pi/skills/storia-linear-tickets/linear_ticket.py --json view STO-123
```

## Project Selection

Default project:

```text
storia-web-b2f648c17c65
```

Override only when needed:

```bash
LINEAR_PROJECT_SLUG=other-project-slug .pi/skills/storia-linear-tickets/linear_ticket.py list
# or
.pi/skills/storia-linear-tickets/linear_ticket.py --project other-project-slug list
```

## Ticket Creation Checklist

Include enough context for an autonomous Storia agent to start safely:

- Problem or desired outcome
- User-visible acceptance criteria
- Relevant files, feature area, or route if known
- Validation expectation (`flutter analyze`, targeted tests, `./bin/verify.sh`, visual proof)
- Out-of-scope notes or risks

Good description template:

```markdown
## Problem

## Acceptance Criteria
- [ ]

## Notes / Pointers

## Validation
- [ ]
```

## Update Guidelines

- Use `--state` for workflow transitions only when you are responsible for that transition.
- Use `--comment` for progress, blockers, validation evidence, or handoff notes.
- For Symphony-run tickets, prefer maintaining the existing `## Symphony Workpad` comment if one exists; do not spam separate comments unless requested.
- Do not put secrets, local `.env` values, tokens, or private customer data in Linear descriptions/comments.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `LINEAR_API_KEY is not set` | Export the key in the shell before running the helper. |
| `Could not resolve Linear project` | Check `WORKFLOW.md` and override with `--project` or `LINEAR_PROJECT_SLUG`. |
| `State '<name>' not found` | Run `list`/`view` or check Linear for the exact state name/casing. |
| GraphQL authorization error | Confirm the API key is valid and has access to the Storia workspace. |

## Implementation Notes

The helper intentionally avoids `jq`, Node packages, or Python dependencies so it can run in any bootstrapped repo shell. It sends the API key only in the `Authorization` header and never logs it.
