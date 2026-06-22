# Pi extensions

Small, project-local Pi UI/workflow extensions. Run them with:

```bash
pi -e extensions/minimal.ts
pi -e extensions/system-select.ts -e extensions/minimal.ts
```

## Useful defaults

- `minimal.ts` — compact model/context footer.
- `system-select.ts` — `/system` picker for local/global agent prompts.
- `tilldone.ts` — task gate for non-trivial work.
- `damage-control.ts` — filesystem/tool safety rules.
- `tool-counter.ts` — token/cost/tool footer.

## Check before editing

```bash
./bin/check-extensions.sh
```

The check uses `bun build` with Pi runtime packages externalized, so it catches
syntax/import mistakes without needing to launch Pi.

## Team/chain execution

`agent-team.ts`, `agent-chain.ts`, and `pi-pi.ts` spawn child `pi` processes.
Their old `opus`/`sonnet`/`haiku` tier labels are mapped through `piModels.ts`.
Default child model: `openai-codex/gpt-5.5`.

Override when needed:

```bash
PI_AGENT_MODEL=openai-codex/gpt-5.5 pi -e extensions/agent-team.ts
PI_AGENT_MODEL_SONNET=openai-codex/gpt-5.5 pi -e extensions/agent-chain.ts
```

Child processes inherit the project cwd and surface stderr on failure.

## Keep them boring

- One extension file per behavior.
- Shared theme/title behavior lives in `themeMap.ts`.
- Prefer tiny widgets over orchestration unless the extension already owns it.
