#!/usr/bin/env bash
# opencode-symphony.sh — OpenCode-native Linear orchestrator (Symphony-shaped, no Pi).
#
# Polls Linear for tickets in `Todo`, `Rework`, or stale `In Progress` (resume),
# dispatches `opencode run` in an isolated git worktree, runs ./bin/verify.sh,
# opens a PR, moves the ticket to `Human Review`.
#
# Per-state behavior:
#   Todo        → fresh worktree off origin/main, run opencode, open PR
#   Rework      → fetch existing PR feedback via gh, prepend to opencode prompt
#   In Progress → resume only if local worktree exists (i.e. we crashed mid-run);
#                 don't grab tickets a human is driving manually
#
# Usage:
#   ./bin/opencode-symphony.sh             # foreground loop
#   ./bin/opencode-symphony.sh --once      # process current Todo tickets, exit
#   ./bin/opencode-symphony.sh --dry-run   # show what would dispatch, don't act
#
# Required env:
#   LINEAR_API_KEY         personal API key (Linear → Settings → Security & Access)
#   OPENAI_API_KEY         or whichever key your opencode install needs
# Optional env:
#   PROJECT_SLUG           default: storia-web-b2f648c17c65 (from WORKFLOW.md)
#   WORKSPACES             default: ~/code/storia-mobile-symphony-workspaces
#   POLL_S                 default: 15
#   MAX_PARALLEL           default: 2
#   GIT_REMOTE             default: origin
#   GIT_BASE               default: main
#   OPENCODE_MODEL         default: opencode-go/kimi-k2.6
#   STATE_TODO             default: Todo
#   STATE_IN_PROGRESS      default: In Progress
#   STATE_REVIEW           default: In Review
#   STATE_REWORK           default: ""               (empty = disabled)

set -euo pipefail

# ---------- config ----------
: "${LINEAR_API_KEY:?Set LINEAR_API_KEY in ~/.zshrc (Linear → Settings → Security & Access).}"
PROJECT_SLUG="${PROJECT_SLUG:-storia-web-b2f648c17c65}"
WORKSPACES="${WORKSPACES:-$HOME/code/storia-mobile-symphony-workspaces}"
POLL_S="${POLL_S:-15}"
MAX_PARALLEL="${MAX_PARALLEL:-2}"
OPENCODE_MODEL="${OPENCODE_MODEL:-opencode-go/kimi-k2.6}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BASE="${GIT_BASE:-main}"
STATE_TODO="${STATE_TODO:-Todo}"
STATE_IN_PROGRESS="${STATE_IN_PROGRESS:-In Progress}"
STATE_REVIEW="${STATE_REVIEW:-In Review}"
STATE_REWORK="${STATE_REWORK:-}"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
locks_dir="$WORKSPACES/.locks"
log_dir="$WORKSPACES/.logs"
state_cache="$WORKSPACES/.state-ids.json"

DRY_RUN=0
ONCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --once)    ONCE=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# ---------- deps ----------
for bin in jq curl gh git opencode; do
  command -v "$bin" >/dev/null || { echo "[opencode-symphony] missing dep: $bin" >&2; exit 1; }
done

mkdir -p "$WORKSPACES" "$locks_dir" "$log_dir"

log() { printf '[%s] [opencode-symphony] %s\n' "$(date +%H:%M:%S)" "$*"; }

# ---------- linear ----------
linear_gql() {
  # $1 = query, $2 = variables JSON
  local query="$1" vars="${2:-{}}"
  local body resp
  body=$(jq -nc --arg q "$query" --argjson v "$vars" '{query:$q, variables:$v}')
  resp=$(curl -fsS https://api.linear.app/graphql \
    -H "Authorization: $LINEAR_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body")
  if echo "$resp" | jq -e 'has("errors") or has("error")' >/dev/null 2>&1; then
    log "Linear GQL error: $(echo "$resp" | jq -c '.errors // .error // .')" >&2
    log "  request: $(echo "$body" | jq -c '.variables')" >&2
  fi
  echo "$resp"
}

# Resolve project ID + workflow state IDs once per run.
load_state_ids() {
  if [ -f "$state_cache" ] && [ "$(find "$state_cache" -newermt '-10 min' 2>/dev/null)" ]; then
    return
  fi
  log "fetching Linear project + state IDs (slug=$PROJECT_SLUG)"
  local q='query($slug: String!) {
    project(id: $slug) {
      id name slugId
      teams(first: 1) { nodes { id states(first: 50) { nodes { id name type } } } }
    }
  }'
  local resp
  resp=$(linear_gql "$q" "$(jq -nc --arg s "$PROJECT_SLUG" '{slug:$s}')")
  if [ "$(echo "$resp" | jq -r '.data.project // empty')" = "" ]; then
    echo "[opencode-symphony] could not resolve project $PROJECT_SLUG" >&2
    echo "$resp" | jq . >&2
    exit 1
  fi
  echo "$resp" | jq '{
    project_id: .data.project.id,
    project_name: .data.project.name,
    states: (.data.project.teams.nodes[0].states.nodes | map({(.name): .id}) | add)
  }' > "$state_cache"
  log "cached: $(jq -c . "$state_cache")"
}

state_id_for() {
  jq -r --arg n "$1" '.states[$n] // empty' "$state_cache"
}

project_id() {
  jq -r '.project_id' "$state_cache"
}

# Fetch issues that need attention. Returns NDJSON with state name included so the
# worker can branch on flow type (Todo = fresh, Rework = address PR feedback,
# In Progress = resume an interrupted run).
fetch_active_issues() {
  local pid; pid="$(project_id)"
  local states_json
  states_json="$(jq -nc \
    --arg t "$STATE_TODO" \
    --arg ip "$STATE_IN_PROGRESS" \
    --arg rw "$STATE_REWORK" \
    '[$t, $ip] + (if ($rw // "") == "" then [] else [$rw] end)')"
  local q='query($pid: ID!, $states: [String!]!) {
    issues(
      filter: { project: { id: { eq: $pid } }, state: { name: { in: $states } } },
      first: 50
    ) {
      nodes { id identifier title description url state { name } }
    }
  }'
  local resp
  resp="$(linear_gql "$q" "$(jq -nc --arg p "$pid" --argjson s "$states_json" '{pid:$p, states:$s}')")"
  log "fetch_active_issues raw response: $resp" >&2
  echo "$resp" | jq -c '.data.issues.nodes[]?'
}

move_state() {
  # $1 = issue id, $2 = state name
  local iid="$1" sname="$2" sid
  sid="$(state_id_for "$sname")"
  [ -n "$sid" ] || { log "state '$sname' not found in workflow"; return 1; }
  local q='mutation($id: String!, $sid: String!) {
    issueUpdate(id: $id, input: { stateId: $sid }) { success issue { state { name } } }
  }'
  linear_gql "$q" "$(jq -nc --arg id "$iid" --arg sid "$sid" '{id:$id, sid:$sid}')" >/dev/null
}

post_comment() {
  # $1 = issue id, $2 = body
  local iid="$1" body="$2"
  local q='mutation($iid: String!, $b: String!) {
    commentCreate(input: { issueId: $iid, body: $b }) { success comment { id } }
  }'
  linear_gql "$q" "$(jq -nc --arg iid "$iid" --arg b "$body" '{iid:$iid, b:$b}')" >/dev/null
}

# ---------- worker ----------
process_ticket() {
  local issue_json="$1"
  local id ident title desc url state
  id="$(echo "$issue_json" | jq -r .id)"
  ident="$(echo "$issue_json" | jq -r .identifier)"
  title="$(echo "$issue_json" | jq -r .title)"
  desc="$(echo "$issue_json" | jq -r '.description // ""')"
  url="$(echo "$issue_json" | jq -r .url)"
  state="$(echo "$issue_json" | jq -r '.state.name')"

  local lock="$locks_dir/$ident.lock"
  if [ -e "$lock" ] && kill -0 "$(cat "$lock" 2>/dev/null)" 2>/dev/null; then
    return 0
  fi

  local branch
  branch="symphony/$(printf '%s' "$ident" | tr '[:upper:]' '[:lower:]')"
  local wt="$WORKSPACES/$ident"

  # Resume policy: only pick up "In Progress" tickets if we already have a worktree
  # for them (i.e. we started this run and were interrupted). Don't grab tickets a
  # human is actively driving.
  if [ "$state" = "$STATE_IN_PROGRESS" ] && [ ! -d "$wt" ]; then
    return 0
  fi

  echo $$ > "$lock"
  ticket_lock="$lock"
  trap 'rm -f -- "$ticket_lock"' EXIT

  local logf="$log_dir/$ident.log"
  exec >>"$logf" 2>&1
  log "=== $ident [$state] — $title ==="

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY RUN — would dispatch $ident → $wt branch=$branch (state=$state)"
    return 0
  fi

  if [ "$state" = "$STATE_TODO" ] || [ "$state" = "$STATE_REWORK" ]; then
    log "→ Linear: $ident → $STATE_IN_PROGRESS"
    move_state "$id" "$STATE_IN_PROGRESS" || { log "failed state move; aborting"; return 1; }
  else
    log "resuming $STATE_IN_PROGRESS ticket $ident with existing worktree"
  fi

  log "→ git worktree $wt off $GIT_REMOTE/$GIT_BASE"
  if [ ! -d "$wt" ]; then
    (cd "$repo_root" && git fetch "$GIT_REMOTE" "$GIT_BASE" --quiet)
    (cd "$repo_root" && git worktree add -B "$branch" "$wt" "$GIT_REMOTE/$GIT_BASE")
  fi

  (cd "$wt" && ./bin/bootstrap.sh) || { log "bootstrap failed"; finalize_blocker "$id" "$ident" "bootstrap.sh failed — see $logf"; return 1; }

  local hostname_short; hostname_short="$(hostname -s)"
  local short_sha; short_sha="$(cd "$wt" && git rev-parse --short HEAD)"

  # On Rework, fetch existing PR feedback so opencode can address it.
  local feedback_block=""
  if [ -n "$STATE_REWORK" ] && [ "$state" = "$STATE_REWORK" ]; then
    log "→ fetching PR feedback for Rework"
    local pr_json
    pr_json=$(cd "$wt" && gh pr view "$branch" --json comments,reviews,reviewThreads 2>/dev/null || echo "{}")
    local fb
    fb=$(echo "$pr_json" | jq -r '
      [
        (.reviews // [])[] | select(.body and .body != "") | "REVIEW (\(.state // "")): \(.body)",
        (.comments // [])[] | "COMMENT by \(.author.login // "?"): \(.body)",
        (.reviewThreads // [])[] | .comments[]? | "INLINE \(.path // "")\(if .line then ":\(.line)" else "" end): \(.body)"
      ] | .[]
    ' 2>/dev/null)
    if [ -n "$fb" ]; then
      feedback_block="

Prior PR review feedback to address (this ticket is in Rework):
$fb"
    else
      feedback_block="

This ticket is in Rework but no PR feedback was retrievable. Re-read the ticket comments for the rework reason."
    fi
  fi

  post_comment "$id" "## Symphony Workpad

\`\`\`text
${hostname_short}:${wt}@${short_sha}
\`\`\`

### Plan
- [ ] dispatched via \`opencode run\` (state on entry: $state)

### Notes
- $(date -Iseconds) opencode-symphony picked up ticket"

  local task_text
  task_text="$title

Linear ticket: $ident
URL: $url

$desc$feedback_block"

  log "→ opencode run (model: $OPENCODE_MODEL)"
  if (cd "$wt" && opencode run "$task_text" \
    --format json \
    --dangerously-skip-permissions \
    -m "$OPENCODE_MODEL" \
    --dir "$wt"); then
    log "opencode run done — running verify.sh"
  else
    log "opencode run non-zero exit"
    finalize_blocker "$id" "$ident" "opencode run exited non-zero. See $logf"
    return 1
  fi

  if (cd "$wt" && ./bin/verify.sh); then
    log "verify passed"
  else
    log "verify failed"
    finalize_blocker "$id" "$ident" "verify.sh failed (analyze/test). See $logf"
    return 1
  fi

  if [ -z "$(cd "$wt" && git status --porcelain)" ] && [ "$(cd "$wt" && git rev-list --count "$GIT_REMOTE/$GIT_BASE..HEAD")" = "0" ]; then
    log "no changes produced; closing as no-op"
    post_comment "$id" "opencode-symphony: agent produced no changes. Closing without PR."
    move_state "$id" "$STATE_REVIEW" || true
    return 0
  fi

  (cd "$wt" && git add -A && git diff --cached --quiet || git commit -m "feat($ident): $title

Linear: $url

Generated by opencode-symphony (model: $OPENCODE_MODEL).")

  log "→ push $branch + open PR"
  (cd "$wt" && git push -u "$GIT_REMOTE" "$branch")

  local pr_url
  pr_url=$(cd "$wt" && gh pr create \
    --base "$GIT_BASE" --head "$branch" \
    --title "[$ident] $title" \
    --body "Linear: $url

Generated by \`opencode run -m $OPENCODE_MODEL\` via opencode-symphony.

\`\`\`
$(./bin/verify.sh 2>&1 | tail -20)
\`\`\`" \
    --label symphony 2>&1 | tail -1)

  log "PR: $pr_url"
  post_comment "$id" "opencode-symphony: PR opened — $pr_url

verify.sh ✓ analyze + tests passed."
  move_state "$id" "$STATE_REVIEW" || true
  log "=== $ident → Human Review ==="
}

finalize_blocker() {
  local id="$1" ident="$2" msg="$3"
  post_comment "$id" "**[BLOCKED]** $msg" || true
  move_state "$id" "$STATE_REVIEW" || true
}

# ---------- loop ----------
running_count() {
  local f pid count=0
  for f in "$locks_dir"/*.lock; do
    [ -e "$f" ] || continue
    pid="$(cat "$f" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      count=$((count + 1))
    else
      rm -f "$f"
    fi
  done
  echo "$count"
}

cleanup_stale_locks() {
  for f in "$locks_dir"/*.lock; do
    [ -e "$f" ] || continue
    pid="$(cat "$f" 2>/dev/null)"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      log "stale lock removed: $(basename "$f")"
      rm -f "$f"
    fi
  done
}

tick() {
  load_state_ids
  cleanup_stale_locks
  while IFS= read -r issue; do
    [ -z "$issue" ] && continue
    local ident; ident="$(echo "$issue" | jq -r .identifier)"
    local cur; cur="$(running_count)"
    if [ "$cur" -ge "$MAX_PARALLEL" ]; then
      log "at parallel cap ($cur/$MAX_PARALLEL); $ident waits"
      continue
    fi
    log "dispatch $ident"
    ( process_ticket "$issue" ) &
  done < <(fetch_active_issues)
}

trap 'log "shutting down"; wait; exit 0' INT TERM

if [ "$ONCE" = "1" ] || [ "$DRY_RUN" = "1" ]; then
  tick
  wait
  exit 0
fi

log "starting loop — project=$PROJECT_SLUG poll=${POLL_S}s parallel=$MAX_PARALLEL model=$OPENCODE_MODEL"
while true; do
  tick
  sleep "$POLL_S"
done
