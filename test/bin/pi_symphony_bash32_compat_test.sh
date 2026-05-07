#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
scripts="
$repo_root/bin/pi-symphony.sh
$repo_root/bin/symphony-proof.sh
$repo_root/bin/symphony-capture-playwright-proof.sh
"

while IFS= read -r script; do
  [ -n "$script" ] || continue
  if grep -nE '\$\{[^}]+,,[^}]*\}' "$script"; then
    echo "Symphony shell scripts must run on macOS bash 3.2; avoid Bash 4 lowercase expansion in $script" >&2
    exit 1
  fi
done <<EOF_SCRIPTS
$scripts
EOF_SCRIPTS
