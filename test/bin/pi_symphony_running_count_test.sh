#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo_root/bin/pi-symphony.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
locks_dir="$tmpdir/.locks"
mkdir -p "$locks_dir"

# Load only the function under test so the script's Linear/pi side effects do not run.
eval "$(awk '
  /^running_count\(\)/ { in_fn=1 }
  in_fn { print }
  in_fn && /^}/ { exit }
' "$script")"

set +e
count="$(running_count)"
status=$?
set -e

if [ "$status" -ne 0 ]; then
  echo "expected running_count to succeed when no *.lock files exist; status=$status output=$count" >&2
  exit 1
fi

if [ "$count" != "0" ]; then
  echo "expected empty lock directory to report 0 running locks, got: $count" >&2
  exit 1
fi
