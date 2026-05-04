#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo_root/bin/pi-symphony.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
locks_dir="$tmpdir/.locks"
log_dir="$tmpdir/.logs"
WORKSPACES="$tmpdir/workspaces"
mkdir -p "$locks_dir" "$log_dir" "$WORKSPACES"

DRY_RUN=1
STATE_TODO="Todo"
STATE_IN_PROGRESS="In Progress"
STATE_REWORK=""
PI_CHAIN="storia-build-feature"
GIT_REMOTE="origin"
GIT_BASE="main"

log() { printf '[test] %s\n' "$*"; }

# Load only process_ticket so script startup side effects do not run.
eval "$(awk '
  /^process_ticket\(\)/ { in_fn=1 }
  in_fn { print }
  in_fn && /^}/ { exit }
' "$script")"

issue='{"id":"issue-1","identifier":"STO-6","title":"Dry run","description":"","url":"https://example.test","state":{"name":"Todo"}}'

set +e
( process_ticket "$issue" )
status=$?
set -e

log_file="$log_dir/STO-6.log"
if [ "$status" -ne 0 ]; then
  echo "dry-run process_ticket should exit 0; status=$status" >&2
  [ -f "$log_file" ] && cat "$log_file" >&2
  exit 1
fi

if grep -q 'unbound variable' "$log_file"; then
  echo "dry-run process_ticket should not trip set -u in EXIT trap" >&2
  cat "$log_file" >&2
  exit 1
fi

if [ -e "$locks_dir/STO-6.lock" ]; then
  echo "dry-run process_ticket should remove its lock on exit" >&2
  exit 1
fi
