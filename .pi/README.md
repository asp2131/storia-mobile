# Project pi layout

This project-local `.pi/` directory is the source of truth for the Storia pi harness.

## Authored configuration

- `agents/` — agent definitions and chain config
- `expertise/` — domain expertise used by the custom harness
- `harness/` — workflow and operating docs
- `skills/` — project-local skills
- `themes/` — project-local themes
- `settings.json` — project overrides for pi
- `damage-control-rules.yaml` — shell/path safety policy

## Runtime and history

- `agent-sessions/` — local extension-managed agent-chain session files
- `evolution/` — self-improvement history and metrics
- `refactor-backups/` — backups created during local pi refactors

## Loading policy

Project settings now load these resources explicitly:

- `prompts`: `../.claude/commands`
- `skills`: `.pi/skills`
- `themes`: `.pi/themes`

This keeps discovery intentional and makes it easier to reason about what pi is loading in this repo.
